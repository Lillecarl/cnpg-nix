{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        # nixpkgs instance
        pkgs = import inputs.nixpkgs {
          inherit system;
          # nixpkgs cache doesn't cache unfree packages. Timescale Toolkit is unfree and really slow to build.
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              # Update Barman and disable tests.
              # We're using release versions of Barman and the tests failing
              # are relateed to some datetime functions within the tests.
              barman = prev.barman.overrideAttrs (pattrs: rec {
                name = "${pattrs.pname}-${version}";
                version = "3.12.1";
                src = pkgs.fetchFromGitHub {
                  owner = "EnterpriseDB";
                  repo = "barman";
                  rev = "refs/tags/release/${version}";
                  sha256 = "sha256-uYyRLAFvuStyiKba1Js4kYjYLoLEgESnUaGMpsVYpZI=";
                };
                doCheck = false;
                doInstallCheck = false;
              });
              pllua = prev.callPackage ./pllua.nix {
                lua = prev.lua5_4.override {
                  version = "5.4.7";
                  hash = "sha256-n79eKO+GxphY9tPTTszDLpEcGii0Eg/z6EqqcM+/HjA=";
                };
              };
              plprql = prev.callPackage ./plprql.nix { };
              pg_graphql = prev.callPackage ./pg_graphql.nix { };
              pg_jsonschema = prev.callPackage ./pg_jsonschema.nix { };
              pg_analytics = prev.callPackage ./pg_analytics.nix { };
            })
          ];
        };
        dockerUtils = import ./dockerUtils.nix pkgs;
        # shorthand for lib since we don't get it from NixOS modules
        lib = pkgs.lib;
        # postgres version
        pg = pkgs.postgresql_17;
        # clean Python3, postgres will depend on this
        cleanPy = pkgs.python3;
        # python3 with packages installed, we just make them available with PYTHONPATH
        packagePy = cleanPy.withPackages (
          ps: with ps; [
            numpy
            psycopg2
          ]
        );

        # Override to enable Python support
        pgPy =
          (pg.override {
            pythonSupport = true;
            python3 = cleanPy; # Give postgres a clean python3
          }).overrideAttrs
            (pattrs: {
              nativeBuildInputs = pattrs.nativeBuildInputs ++ [ cleanPy ];
            });
        # Our "custom" postgresql with plugins
        ourPg = pg.withPackages (
          ps: with ps; [
            # nixpkgs extensions are already following the correct PG version since we get through pg.withPackages
            # Our own extensions are not, so we need to override postgresql with our version here
            (pg_analytics.override { postgresql = pg; })
            (pg_graphql.override { postgresql = pg; })
            (pg_jsonschema.override { postgresql = pg; })
            (pllua.override { postgresql = pg; })
            (plprql.override { postgresql = pg; })
            hypopg
            pg_cron
            pg_partman
            pg_safeupdate
            pg_similarity
            pg_squeeze
            pgaudit
            pgmq
            pgrouting
            pgvector
            plpgsql_check
            plpgsql_check
            plv8
            postgis
            system_stats
            timescaledb
            timescaledb_toolkit
          ]
        );

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
              "PYTHONPATH=${lib.concatStringsSep ":" pythonPath}"
            ];
        };
        inherit (dockerUtils) nonRootShadowSetup;
      in
      {
        packages = {
          default = pkgs.dockerTools.buildLayeredImage {
            name = "cnpg-nix";

            contents =
              [
                debugPkgs
                ourPkgs
                pkgs.dockerTools.binSh # links /bin/sh
                pkgs.dockerTools.caCertificates # links /etc/ssl/certs
                pkgs.dockerTools.usrBinEnv # links /usr/bin/env
              ]
              ++
              # links /etc/passwd, /etc/group, /etc/gshadow, /etc/nsswitch.conf
              nonRootShadowSetup {
                user = "postgres"; # standard
                uid = 26; # defined by RHEL to be standard
              };

            # nixpkgs config
            inherit config;
          };

          inherit pgPy ourPg;
        };

        # Export nixpkgs, lib and inputs for troubleshooting with nix repl
        inherit inputs;
        inherit (pkgs) lib;
        legacyPackages = pkgs;
      }
    );
}
