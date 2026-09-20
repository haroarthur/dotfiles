{ lib, user, ... }:

# Owns the Mac's system layer: nix-darwin defaults and the Homebrew casks Nix does not carry.

{
  nix.enable = false; # Determinate already manages the daemon

  # Homebrew installs into /opt/homebrew/bin, and nix-darwin's /etc/zshenv REPLACES PATH with
  # environment.systemPath, so without this the brews and casks below are unreachable from every shell
  # this home configures - login, non-login and a Herdr pane alike. Ordered after the Nix profiles
  # (1000) and before /usr/bin (1200); `homebrew.enableZshIntegration` would only reach /etc/zshrc,
  # which a non-interactive login shell never reads.
  environment.systemPath = lib.mkOrder 1100 [ "/opt/homebrew/bin" ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      _HIHideMenuBar = true;
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";
    finder.CreateDesktop = false;
    trackpad.Clicking = true;
  };

  nix-homebrew = {
    enable = true;
    inherit user;

    # A day-one Mac, and every hosted macOS runner, usually has Homebrew at /opt/homebrew already;
    # without this nix-homebrew refuses that prefix and aborts the switch instead of taking it over.
    autoMigrate = true;
  };

  # Homebrew is Mac-only: WezTerm and Claude as casks, Herdr as an upstream brew formula.
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = false; # pin bumps are attended; do not phone home on every switch
    onActivation.extraFlags = [ "--force" ];
    brews = [ "herdr" ];
    casks = [
      "wezterm"
      "claude-code"
      # Chrome is an app bundle, never a PATH entry, and chrome-devtools-axi drives it.
      "google-chrome"
    ];
  };
}
