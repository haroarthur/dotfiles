{ ... }:

# Owns which systemctl the activation talks to - the host's own: Home Manager's pinned client is
# newer than Ubuntu's user manager under WSL2 and cannot talk to it, so units would be written but
# never loaded.

{
  systemd.user.systemctlPath = "/usr/bin/systemctl";
}
