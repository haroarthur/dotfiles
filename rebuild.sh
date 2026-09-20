#!/usr/bin/env bash
# Owns every later change to the WSL host: the wsl-ubuntu-safe guard, then the switch - no flag and
# no environment variable overrides it.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ "$DIR" = "$HOME/.dotfiles" ] || { echo "rebuild.sh expects the registered clone at ~/.dotfiles (got $DIR)" >&2; exit 1; }

# A green build cannot tell a full profile from one without Herdr, and switching to that one stops
# every agent pane, the one running this included. A hand-run `home-manager switch` skips this.
echo "==> Building the wsl-ubuntu-safe guard"
nix build --no-update-lock-file --no-link "$HOME/.dotfiles#checks.x86_64-linux.wsl-ubuntu-safe" \
  || { echo "refusing the live switch: the built profile failed flake.nix's wsl-ubuntu-safe guard." >&2; exit 1; }

exec home-manager switch --flake "$HOME/.dotfiles#$(whoami)@wsl-ubuntu" -b backup
