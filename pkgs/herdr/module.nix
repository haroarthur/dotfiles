{
  config,
  lib,
  pkgs,
  ...
}:

# Owns Herdr on the WSL host: herdr.service, the herdr-panes slice and the pane shell. The binary is
# install-tools.sh's, so the unit execs ~/.local/bin/herdr.

let
  herdr = "${config.home.homeDirectory}/.local/bin/herdr";
in
{
  options.herdr.wslg.enable = lib.mkEnableOption "WSLg display addresses in the Herdr service environment";

  config.home.packages = [
    (import ./pane-shell.nix { inherit pkgs; })
  ];

  # Bounds the whole fleet, sized for this host; the pane shell bounds one pane. The server stays outside.
  config.systemd.user.slices.herdr-panes = {
    # sd-switch restarts an active unit whose file changed, and stopping a slice stops every scope in
    # it, so without this an edit below would tear down every live pane on the next switch. The
    # reload still applies changed cgroup properties to the running slice.
    Unit.X-RestartIfChanged = false;
    Slice = {
      MemoryHigh = "10G";
      MemoryMax = "12G";
      # Each pane may swap 512 MiB; keep this strictly below the host's 4 GiB WSL swap.
      MemorySwapMax = "1G";
    };
  };

  config.systemd.user.services.herdr = {
    Unit = {
      Description = "Herdr terminal workspace manager (headless server)";
      Documentation = "https://herdr.dev";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
      # A first switch writes this unit before the binary exists; without this the failed start fails
      # the activation. install-tools.sh starts the service later.
      ConditionPathExists = herdr;
      # The never-kill-in-flight property: a rebuild loads a changed unit but leaves the running
      # server, and every pane scope bound to it, alone. Adopt by hand, only when quiescent.
      X-SwitchMethod = "keep-old";
    };

    Service = {
      Type = "simple";
      ExitType = "cgroup";
      NotifyAccess = "all";
      ExecStart = "${herdr} server";
      # systemd runs ExecStop even when the server already exited on its own; "-" keeps that
      # redundant failure from marking the unit failed and leaving the fleet down at an adopt.
      ExecStop = "-${herdr} server stop";
      Environment = [
        # The only PATH a pane and its workers see: the pane shell execs bash, not a login shell, so
        # hm-session-vars never runs. ~/bin trails ~/.local/bin so a real binary beats an older shim.
        "PATH=${config.home.profileDirectory}/bin:${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        # The stable profile path, so new panes adopt a changed pane shell while keep-old leaves the
        # server itself untouched.
        "SHELL=${config.home.profileDirectory}/bin/herdr-pane-shell"
      ]
      ++ lib.optionals config.herdr.wslg.enable [
        "DISPLAY=:0"
        "WAYLAND_DISPLAY=wayland-0"
      ];
      TimeoutStopSec = 20;
      # A pane scope handles its own OOM; a stray kill here must not become a fleet-wide restart.
      OOMPolicy = "continue";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
