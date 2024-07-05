{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, ... }@inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;

      pg = pkgs.postgresql_16;
      py = pkgs.python3;

      ourPg = (
        pg.override {
          pythonSupport = true;
          python3 = py.withPackages (ps: with ps; [
            numpy
            psycopg2
          ]);
        }).withPackages (ps: with ps; [
        self.packages.x86_64-linux.pgmq
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

      ourPkgs = with pkgs; [
        # debug
        htop
        binutils
        strace
        lsd
        ripgrep
        fd
        # Always supply a really shitty bash experience
        bash
        # Locales
        glibcLocales
        # Barman used by CNPG
        barman
        # CLI utils
        fish
        coreutils
        moreutils
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
      nonRootShadowSetup = { user, uid, gid ? uid }: with pkgs; [
        (
          writeTextDir "etc/shadow" ''
            root:!x:::::::
            ${user}:!:::::::
          ''
        )
        (
          writeTextDir "etc/passwd" ''
            root:x:0:0::/root:${runtimeShell}
            ${user}:x:${toString uid}:${toString gid}::/home/${user}:
          ''
        )
        (
          writeTextDir "etc/group" ''
            root:x:0:
            ${user}:x:${toString gid}:
          ''
        )
        (
          writeTextDir "etc/gshadow" ''
            root:x::
            ${user}:x::
          ''
        )
        (
          writeTextDir "etc/nsswitch.conf" ''
            hosts: files dns
          ''
        )
      ];
    in
    {
      packages.x86_64-linux = {
        default = pkgs.dockerTools.buildLayeredImage {
          name = "cnpg-nix";

          contents = [
            ourPkgs
            pkgs.dockerTools.binSh
            pkgs.dockerTools.caCertificates
            pkgs.dockerTools.usrBinEnv
          ] ++ nonRootShadowSetup { user = "postgres"; uid = 26; };

          inherit config;
        };
        pgmq = pkgs.callPackage ./pgmq.nix { };
        plprql = pkgs.callPackage ./plprql.nix { };
      };
    };
}
