{ lib, stdenv, postgresql }:

stdenv.mkDerivation rec {
  pname = "pgmq";
  version = "1.3.3";

  buildInputs = [ postgresql ];

  src = builtins.fetchGit {
    url = "https://github.com/tembo-io/pgmq.git";
    rev = "9066da119807eb7272c82bc6ee0ecf3ae1674777";
    exportIgnore = false;
    submodules = true;
  };

  makeFlags = [
    "USE_PGXS=1"
    "PG_CONFIG=${postgresql}/bin/pg_config"
  ];

  installFlags = [
    # PGXS only supports installing to postgresql prefix so we need to redirect this
    "DESTDIR=${placeholder "out"}"
  ];

  postInstall = ''
    # Move the redirected to proper directory.
    # There appear to be no references to the install directories
    # so changing them does not cause issues.
    mv "$out/nix/store"/*/* "$out"
    rmdir "$out/nix/store"/* "$out/nix/store" "$out/nix"
  '';

  meta = {
    platforms = postgresql.meta.platforms;
  };
}
