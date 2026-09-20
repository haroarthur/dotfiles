#!/usr/bin/env bash
# Owns every later change to the Mac, from the registered clone at ~/.dotfiles.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ "$(uname -s)" = Darwin ] || { echo "rebuild-mac.sh is for macOS only" >&2; exit 1; }
[ "$DIR" = "$HOME/.dotfiles" ] || { echo "rebuild-mac.sh expects the registered clone at ~/.dotfiles (got $DIR)" >&2; exit 1; }
# --inputs-from: the nix-darwin this flake locks, the same way bootstrap-mac.sh resolves it.
exec sudo "$(command -v nix)" run --no-update-lock-file --inputs-from "$HOME/.dotfiles" nix-darwin#darwin-rebuild -- \
  switch --flake "$HOME/.dotfiles#mac"
