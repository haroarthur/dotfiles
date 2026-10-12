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

  # Home Manager's docs leave the meta.maintainers declaration (nixpkgs' modules/generic/
  # meta-maintainers.nix, imported through nixos/modules/misc/meta.nix) as a bare nixpkgs store path
  # in the options.json behind `man home-configuration.nix`, which Nix warns about on every Mac
  # evaluation. Drop this once https://github.com/nix-community/home-manager/pull/9912 lands.
  nixpkgs.overlays = [
    (final: prev: {
      nixosOptionsDoc =
        args:
        prev.nixosOptionsDoc (
          args
          // {
            transformOptions =
              opt:
              let
                o = (args.transformOptions or lib.id) opt;
                nixpkgsPath = toString prev.path;
              in
              o
              // {
                declarations = map (
                  decl:
                  if lib.isString decl && lib.hasPrefix nixpkgsPath decl then
                    let
                      sub = lib.removePrefix "/" (lib.removePrefix nixpkgsPath decl);
                    in
                    {
                      name = "<nixpkgs/${sub}>";
                      url = "https://github.com/NixOS/nixpkgs/blob/master/${sub}";
                    }
                  else
                    decl
                ) o.declarations;
              };
          }
        );
    })
  ];

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

  # Homebrew is Mac-only: the apps as casks, Herdr as an upstream brew formula.
  homebrew = {
    enable = true;
    # Leave onActivation.upgrade at its false default: rebuilds must not upgrade installed brews.
    onActivation.cleanup = "uninstall"; # zap would also delete a cask's config dirs; Claude config must survive claude-code leaving the cask list
    onActivation.autoUpdate = false; # pin bumps are attended; do not phone home on every switch
    onActivation.extraFlags = [ "--force" ];
    # Listed so the bundle taps it and cleanup never untaps it. nix-homebrew leaves taps mutable, so
    # Homebrew clones it like any `brew tap` and it needs no pinned flake input.
    taps = [ "automic-vault/isotopes" ];
    brews = [ "herdr" ];
    casks = [
      "wezterm"
      "claude-code"
      # Chrome is an app bundle, never a PATH entry, and chrome-devtools-axi drives it.
      "google-chrome"
      "opensuperwhisper"
      "automic-vault/isotopes/automic-vault"
    ];
  };
}
