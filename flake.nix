{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { ... }@inputs:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;

      pg = pkgs.postgresql_16;
      py = pkgs.python3;

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
        # Postgres used by CNPG
        # With Python support and lots of nice plugins
        (
          (pg.override {
            pythonSupport = true;
            python3 = py.withPackages (ps: with ps; [
              numpy
              psycopg2
            ]);
          }).withPackages (ps: with ps; [
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
          ])
        )
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

      # This provides the ca bundle in common locations
      imageBaseArgs = {
        name = "cnpg-nix-single";
        runAsRoot = /* bash */ ''
          # Nix "workarounds"

          # /usr/bin/env
          mkdir -p /usr/bin
          ln -s ${pkgs.coreutils}/bin/env /usr/bin/env
          # /bin/sh
          mkdir -p /bin
          ln -s ${pkgs.bashInteractive}/bin/bash /bin/sh
          # ca certificates
          mkdir -p /etc/ssl/certs /etc/pki/tls/certs
          # Old NixOS compatibility.
          ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt
          # NixOS canonical location + Debian/Ubuntu/Arch/Gentoo compatibility.
          ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
          # CentOS/Fedora compatibility.
          ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt

          ${pkgs.dockerTools.shadowSetup}

          ${pkgs.shadow}/bin/useradd -u 26 postgres
          mkdir -p /controller/{log,certificates,run}
          chown -R postgres /controller
        '';
        inherit config;
      };
    in
    {
      packages.x86_64-linux = {
        single = pkgs.dockerTools.buildImage imageBaseArgs // {
          name = "cnpg-nix-single";

          copyToRoot = with pkgs; [
            (buildEnv {
              name = "cnpg-nix-root";
              paths = ourPkgs;
              pathsToLink = [ "/bin" ];
            })
            # Nix "workarounds"
            dockerTools.binSh
            dockerTools.caCertificates
            dockerTools.fakeNss
            dockerTools.usrBinEnv
          ];

          layered = pkgs.dockerTools.buildLayeredImage
            imageBaseArgs // {
            name = "cnpg-nix-layered";
            contents = ourPkgs;
            enableFakechroot = true;
          };
        };
        pgmq = pkgs.callPackage ./pgmq.nix { };
      };
    };
}
