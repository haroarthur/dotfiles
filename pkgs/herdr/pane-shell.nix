{ pkgs }:

# Owns what herdr.service hands each pane as SHELL: a wrapper that puts the pane in its own bounded
# systemd scope, so one runaway pane cannot starve the server and its siblings.
#
# The cgroup guard is load-bearing: this is $SHELL, so anything a pane runs as a login shell
# re-enters it, and an unguarded second systemd-run would open a sibling scope with its own budget.
# systemd-run is the host's own client, for the reason ../systemd.nix gives.

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
