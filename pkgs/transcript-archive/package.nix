{ pkgs }:

# Owns the claude-transcript-archive command, built from archive.sh with the GNU tools it assumes.

pkgs.writeShellApplication {
  name = "claude-transcript-archive";
  runtimeInputs = with pkgs; [
    coreutils
    findutils
    gnused
    gnutar
    zstd
  ];
  text = builtins.readFile ./archive.sh;
}
