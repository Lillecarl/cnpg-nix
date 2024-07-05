{ fetchFromGitHub
, buildPgrxExtension
, postgresql
, cargo-pgrx_0_11_3
}:
(buildPgrxExtension.override {
  cargo-pgrx = cargo-pgrx_0_11_3;
}) rec {
  inherit postgresql;

  pname = "plprql";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "kaspermarstal";
    repo = "plprql";
    rev = "v${version}";
    hash = "sha256-WXX1q85OudROntc4qj3kPkXQpSa4Ysx/eI/mVy5Is08=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  buildAndTestSubdir = "plprql";

  # skip tests
  doCheck = false;

  meta = {
    platforms = postgresql.meta.platforms;
  };
}
