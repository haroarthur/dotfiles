{ pkgs }:

# Owns the SHELL herdr.service hands each pane: a wrapper that puts the pane in its own bounded scope.
# The cgroup guard is load-bearing: a login shell inside a pane re-enters $SHELL, and a second
# systemd-run would open a sibling scope with its own budget. /usr/bin: see ../systemd.nix.

pkgs.writeShellScriptBin "herdr-pane-shell" ''
  umask 0022
  read -r pane_cgroup < /proc/self/cgroup || pane_cgroup=
  case "$pane_cgroup" in
    */herdr-panes.slice/*)
      exec ${pkgs.bashInteractive}/bin/bash "$@"
      ;;
  esac

  exec /usr/bin/systemd-run \
    --user \
    --scope \
    --collect \
    --quiet \
    --slice=herdr-panes.slice \
    --property=BindsTo=herdr.service \
    --property=After=herdr.service \
    --property=MemoryHigh=8G \
    --property=MemoryMax=8G \
    --property=MemorySwapMax=512M \
    --property=TimeoutStopSec=20 \
    --property=OOMPolicy=kill \
    -- \
    ${pkgs.bashInteractive}/bin/bash "$@"
''
