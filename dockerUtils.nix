# Create a minimal set of files in /etc to allow postgres to start
# The same could be achieved with useradd/groupadd in an impure system
pkgs: # Argument when importing the file (or later with Currying)
{
  # This renders what normal people would do with useradd/groupadd
  # usermod/groupmod etc. Since we're building a deterministic container
  # we just render the files directly and call it a day.
  nonRootShadowSetup =
    { user
    , uid
    , gid ? uid
    }:
    [
      (
        # man "shadow(5)"
        pkgs.writeTextDir "etc/shadow" ''
          root:!x:::::::
          ${user}:!:::::::
        ''
      )
      (
        # man "passwd(5)"
        pkgs.writeTextDir "etc/passwd" ''
          root:x:0:0::/root:${pkgs.runtimeShell}
          ${user}:x:${toString uid}:${toString gid}::/home/${user}:
        ''
      )
      (
        # man "group(5)"
        pkgs.writeTextDir "etc/group" ''
          root:x:0:
          ${user}:x:${toString gid}:
        ''
      )
      (
        # man "gshadow(5)"
        pkgs.writeTextDir "etc/gshadow" ''
          root:x::
          ${user}:x::
        ''
      )
      (
        # man "nsswitch.conf(5)"
        pkgs.writeTextDir "etc/nsswitch.conf" ''
          hosts: files dns
        ''
      )
    ];
}
