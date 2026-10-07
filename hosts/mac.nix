{
  pkgs,
  lib,
  user,
  ...
}:

# Owns the Mac's Home Manager user: the shared shell and host packages.

{
  imports = [
    ./common.nix
    ../pkgs
    # Never ../pkgs/shell-wsl.nix: bash as a login shell and the OSC 7 hook are the WSL host's alone.
    ../pkgs/shell.nix
  ];

  home.username = lib.mkDefault user;
  home.homeDirectory = lib.mkDefault "/Users/${user}";
  home.stateVersion = "26.05";

  # The font belongs here only: on WSL, WezTerm renders on the Windows side, which reads no profile.
  fonts.fontconfig.enable = true;
  # gh is the Mac's own: hosts/wsl-ubuntu.nix keeps a wrapped one for a /proc-path blocker that only
  # exists there, and phase 2 starts at `gh auth login`, so the Mac cannot be without it either.
  # GH_PATH below does the same job here.
  home.packages = [
    pkgs.nerd-fonts.hack
    pkgs.gh
    # Until the Xcode Command Line Tools are installed, macOS's /usr/bin/git and /usr/bin/python3 are
    # stubs that only open an install dialog, and that python3 is 3.9 even after. The profile precedes
    # /usr/bin, so these are what the ~/.agents clone and the Google Cloud SDK (3.10+, found as
    # `python3` on PATH) run on a fresh Mac.
    pkgs.git
    pkgs.python3
    # What the quality gate and the authored skills reach for.
    pkgs.sqlfluff
  ];

  # nixpkgs wraps gh, so a bare `gh auth setup-git` records the hidden store path of `.gh-wrapped`,
  # which a gh bump and the next garbage collection delete. This makes it record plain `gh`.
  home.sessionVariables.GH_PATH = "gh";
}
