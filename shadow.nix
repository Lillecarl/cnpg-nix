# Create a minimal set of files in /etc to allow postgres to start
# The same could be achieved with useradd/groupadd in an impure system
pkgs:
{ user, uid, gid ? uid }: with pkgs; [
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
]
