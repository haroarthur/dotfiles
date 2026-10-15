{ ... }:

# Owns which systemctl activation uses: the host's own, because Home Manager's is newer than the WSL2
# Ubuntu user manager and cannot load units into it.

{
  systemd.user.systemctlPath = "/usr/bin/systemctl";
}
