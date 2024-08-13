{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;

      pg = pkgs.postgresql_16;
      py = pkgs.python3;

      # pgmq packaged
      pgmq = pkgs.callPackage ./pkgs/pgmq.nix { };
      # pllua packaged
      pllua = pkgs.callPackage ./pkgs/pllua.nix { };

      ourPg = (
        pg.override {
          pythonSupport = true;
          python3 = py.withPackages (ps: with ps; [
            numpy
            psycopg2
          ]);
        }).withPackages (ps: with ps; [
        # nixpkgs extensions are already following the correct PG version since we get through pg.withPackages
        # Our own extensions are not, so we need to override postgresql with our version here
        (pgmq.override { postgresql = pg; })
        (pllua.override { postgresql = pg; })
        pg_cron
        pg_safeupdate
        pg_similarity
        pg_squeeze
        pgaudit
        pgrouting
        plpgsql_check
        plv8
        postgis
        timescaledb
        timescaledb_toolkit
      ]);

      debugPkgs = with pkgs; [
        # debug CLI utils
        htop
        binutils
        strace
        lsd
        ripgrep
        fd
        fish
        coreutils
        moreutils
      ];

      ourPkgs = with pkgs; [
        # Always supply a really shitty bash experience
        bash
        # Required by psql
        less
        # Locales required to start PG
        glibcLocales
        # Barman used by CNPG
        barman
        # Postgres with plugins and stuff
        ourPg
      ];
      config = {
        Env = [
          # Set locale
          "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
          # Set user
          "USER=postgres"
          # Set PATH (CNPG somehow relies on PATH)
          "PATH=${lib.makeBinPath ourPkgs}:/controller"
        ];
      };
      nonRootShadowSetup = import ./shadow.nix pkgs;
    in
    {
      packages.x86_64-linux = {
        default = pkgs.dockerTools.buildLayeredImage {
          name = "cnpg-nix";

          contents = [
            debugPkgs
            ourPkgs
            pkgs.dockerTools.binSh
            pkgs.dockerTools.caCertificates
            pkgs.dockerTools.usrBinEnv
          ] ++ nonRootShadowSetup { user = "postgres"; uid = 26; };

          inherit config;
        };

        inherit
          pgmq
          ;
      };
    };
}
