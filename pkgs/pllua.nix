{ stdenv
, fetchFromGitHub
, autoPatchelfHook
, postgresql
, lua5_4 ? throw "lua is required"
}:
let
  name = "pllua";
  version = "REL_2_0_12";

  ourLua = lua5_4.override {
    version = "5.4.7";
    hash = "sha256-n79eKO+GxphY9tPTTszDLpEcGii0Eg/z6EqqcM+/HjA=";
  };
in
stdenv.mkDerivation {
  inherit name;

  src = fetchFromGitHub {
    owner = name;
    repo = name;
    rev = version;
    sha256 = "sha256-6GDTnS0aj23irITDrR4ykMpR5ATTbe7YCc8f/KzLagI=";
  };

  makeFlags = [
    # Use PGXS
    "USE_PGXS=1"
    # PGXS only supports installing to postgresql prefix so we need to redirect this
    "DESTDIR=${placeholder "out"}"
    # Lua paths
    "LUA_INCDIR=${ourLua}/include"
    "LUALIB=-L${ourLua}/lib" # Set where Lua is installed
    "LUAC=${ourLua}/bin/luac"
    "LUA=${ourLua}/bin/lua"
  ];

  # Workaround for stupid pllua Makefile
  NIX_LDFLAGS = [ "-llua" ];

  postInstall = ''
    # Move the redirected to proper directory.
    # There appear to be no references to the install directories
    # so changing them does not cause issues.
    mv "$out/nix/store"/*/* "$out"
    rmdir "$out/nix/store"/* "$out/nix/store" "$out/nix"
  '';

  passthru = {
    shared_preload_library = "pllua";
  };

  propagatedBuildInputs = [
    ourLua
    postgresql
  ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];
}
