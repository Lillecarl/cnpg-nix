# Overlays are a way to override what's in your nixpkgs instance.
# You can add new packages, or override existing ones.

lastModified: _: prev: {
  # This barman override can be removed once the following commit lands:
  # https://github.com/NixOS/nixpkgs/commit/f5e9b584938d5e7645f5ee5cef8d9275f05a80b3
  # It looks worse than it is because we're doing the date comparison here too.
  barman =
    if lastModified <= 1722813957 then # This is just to get a notice to remove the overlay
      (prev.barman.overrideAttrs
        (oldAttrs: {
          propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [
            prev.python3Packages.distutils
          ];
        })
      )
    else
      (prev.lib.warn
        ''
          nixpkgs has been updated, we should no longer need the barman override
        ''
        prev.barman
      );
}


