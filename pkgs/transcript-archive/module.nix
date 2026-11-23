{ config, pkgs, ... }:

# Owns the Mac's monthly transcript archive: the launchd agent, its OneDrive destination, and the
# warning every new zsh prints while the archive is failing or has not run.

let
  archive = import ./package.nix { inherit pkgs; };
  dest = "${config.home.homeDirectory}/Library/CloudStorage/OneDrive-Personal/Private/Archive/claude-transcripts";
in
{
  home.packages = [
    archive
    pkgs.age
    pkgs.zstd
  ];

  launchd.agents.claude-transcript-archive = {
    enable = true;
    config = {
      # /bin/bash, not a store path: launchd makes this job its own TCC identity, keyed on the
      # executable's path, so a store path would lose the OneDrive grant on every bump.
      ProgramArguments = [
        "/bin/bash"
        "${archive}/bin/claude-transcript-archive"
        "run"
        dest
      ];
      EnvironmentVariables.HOME = config.home.homeDirectory;
      # Daily although only finished months are archived: a missed or failed month retries next day.
      StartCalendarInterval = [
        {
          Hour = 12;
          Minute = 0;
        }
      ];
      ProcessType = "Background";
    };
  };

  programs.zsh.initContent = ''
    () {
      local s
      s="$(${archive}/bin/claude-transcript-archive status)" || print -u2 -- $'\e[31m'"claude-transcript-archive: $s"$'\e[0m'
    }
  '';
}
