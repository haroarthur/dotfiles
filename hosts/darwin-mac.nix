{ lib, user, ... }:

# Owns the Mac's system layer: nix-darwin defaults and the Homebrew casks Nix does not carry.

{
  nix.enable = false; # Determinate already manages the daemon

  # nix-darwin's /etc/zshenv REPLACES PATH with environment.systemPath, so without this the brews are
  # unreachable from every shell, Herdr panes included. 1100 sits between the Nix profiles and /usr/bin;
  # enableZshIntegration only reaches /etc/zshrc, which a non-interactive login shell skips.
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

  homebrew = {
    enable = true;
    # Leave onActivation.upgrade at its false default: rebuilds must not upgrade installed brews.
    onActivation.cleanup = "uninstall"; # not zap: zap deletes a cask's config dirs, Claude's included
    onActivation.autoUpdate = false; # bumps are attended
    onActivation.extraFlags = [ "--force" ];
    # Listed so cleanup never untaps it; nix-homebrew leaves taps mutable, so it needs no flake input.
    taps = [ "automic-vault/isotopes" ];
    brews = [ "herdr" ];
    casks = [
      "wezterm"
      "claude-code"
      # Driven by chrome-devtools-axi.
      "google-chrome"
      "opensuperwhisper"
      "tailscale-app"
      "automic-vault/isotopes/automic-vault"
    ];
  };
}
