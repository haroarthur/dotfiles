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
  home.packages = [
    pkgs.nerd-fonts.hack
    pkgs.gh
    # Without the Xcode CLT, /usr/bin/git and python3 are install-dialog stubs (and python3 is 3.9
    # after); these serve the ~/.agents clone and gcloud (3.10+) on a fresh Mac.
    pkgs.git
    pkgs.python3
    # What the quality gate and the authored skills reach for.
    pkgs.sqlfluff
    pkgs.shellcheck
  ];

  # nixpkgs wraps gh, so a bare `gh auth setup-git` records the hidden store path of `.gh-wrapped`,
  # which a gh bump and the next garbage collection delete. This makes it record plain `gh`.
  home.sessionVariables.GH_PATH = "gh";
}
