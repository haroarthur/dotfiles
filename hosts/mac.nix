{
  pkgs,
  lib,
  user,
  ...
}:

# Owns the Mac's Home Manager user: the shared shell and the font.

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
  home.packages = [
    pkgs.nerd-fonts.hack
    pkgs.gh
    # What the quality gate and the authored skills reach for.
    pkgs.sqlfluff
  ];
}
