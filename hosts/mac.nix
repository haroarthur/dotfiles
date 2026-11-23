{
  config,
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

  # 180 days instead of Claude's 30, so the self-learning loop has its transcripts.
  home.activation.claudeTranscriptRetention = lib.hm.dag.entryAfter [ "manageProgramSettings" ] ''
    claude_settings="${config.home.homeDirectory}/.claude/settings.json"
    claude_tmp="$(${pkgs.coreutils}/bin/mktemp "$claude_settings.XXXXXX")"
    if ! ${pkgs.jq}/bin/jq '.cleanupPeriodDays = 180' "$claude_settings" > "$claude_tmp"; then
      ${pkgs.coreutils}/bin/rm -f -- "$claude_tmp"
      echo "Cannot set cleanupPeriodDays in $claude_settings" >&2
      exit 1
    fi
    if ! ${pkgs.diffutils}/bin/cmp -s -- "$claude_settings" "$claude_tmp"; then
      run ${pkgs.coreutils}/bin/chmod 0644 "$claude_tmp"
      run ${pkgs.coreutils}/bin/mv -f -- "$claude_tmp" "$claude_settings"
    else
      ${pkgs.coreutils}/bin/rm -f -- "$claude_tmp"
    fi
  '';
}
