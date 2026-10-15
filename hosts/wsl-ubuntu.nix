{
  config,
  pkgs,
  user,
  ...
}:

# Owns the WSL Ubuntu host: its packing and its package list.

let
  # nixpkgs' gh is a hidden `.gh-wrapped` outside ~/.nix-profile, and `gh auth setup-git` records its
  # own /proc path as the helper; GH_PATH makes it record one the profile can run.
  gh = pkgs.writeShellApplication {
    name = "gh";
    text = ''
      export GH_PATH=${config.home.homeDirectory}/.nix-profile/bin/gh
      exec ${pkgs.gh}/bin/gh "$@"
    '';
  };
in
{
  imports = [
    ./common.nix
    ../pkgs
    # The floor flake.nix's `wsl-ubuntu-safe` check guards.
    ../pkgs/no-mistakes.nix
    ../pkgs/systemd.nix
    ../pkgs/shell.nix
    ../pkgs/shell-wsl.nix
    ../pkgs/herdr/module.nix
  ];

  # WSLg: the Herdr service needs DISPLAY and WAYLAND_DISPLAY to reach the Windows compositor.
  herdr.wslg.enable = true;

  home.packages = [
    gh
  ]
  ++ (with pkgs; [
    git
    bashInteractive
    coreutils
    curl
    jq
    # ~/.nix-profile/bin precedes the multi-user installer's profile, so this is the Nix the host runs.
    nix
    pnpm
    procps
    ripgrep
    sqlite
    strace
    gnutar
    util-linux
    unzip
    which
    zstd
    # What the quality gate and the authored skills reach for.
    shellcheck
    actionlint
    yt-dlp
    gcc
    gnumake
    sqlfluff
  ]);

  home.username = user;
  home.homeDirectory = "/home/${user}";
  home.stateVersion = "26.05";
}
