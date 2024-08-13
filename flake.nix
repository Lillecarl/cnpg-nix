{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    let
      # nixpkgs instance
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        # nixpkgs cache doesn't cache unfree packages. Timescale Toolkit is unfree and really slow to build.
        config.allowUnfree = true;
        overlays = [
          (import ./overlays/barman.nix inputs.nixpkgs.lastModified)
        ];
      };
      # shorthand for lib since we don't get it from NixOS modules
      lib = pkgs.lib;

      # postgres version
      pg = pkgs.postgresql_16;
      # clean Python3, postgres will depend on this
      cleanPy = pkgs.python3;
      # python3 with packages installed, we just make them available with PYTHONPATH
      packagePy = pkgs.python3.withPackages (ps: with ps; [
        numpy
        psycopg2
      ]);

      # pgmq packaged
      pgmq = pkgs.callPackage ./pkgs/pgmq.nix { };
      # pllua packaged
      pllua = pkgs.callPackage ./pkgs/pllua.nix { };

      ourPg = (
        pg.override {
          pythonSupport = true;
          python3 = cleanPy;
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
        ourPg # Postgres with plugins and stuff
        bash # Always supply a really shitty bash experience
        less # Required by psql
        glibcLocales # Locales required to start PG
        barman # Barman used by CNPG
      ];
      config = {
        Env =
          let
            # Locations for installed Python packages.
            pythonPath = [
              "${packagePy}/lib/${packagePy.libPrefix}"
              "${packagePy}/lib/${packagePy.libPrefix}/site-packages"
            ];
          in
          [
            # Set locale
            "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
            # Set user
            "USER=postgres"
            # Set PATH (CNPG somehow relies on PATH)
            "PATH=${lib.makeBinPath ourPkgs}:/controller"
            # Set PYTHONPATH for pl/python
            "PYTHONPATH=${lib.concatStringsSep ":" pythonPath }"
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

      inherit pkgs inputs;
      inherit (pkgs) lib;
    };
}
