#!/usr/bin/env bash
# Owns phase 1 on a NEW WSL Ubuntu box: the machine, from nothing to a switched home, on public
# inputs with no login - a box already running this changes through ./rebuild.sh instead.
set -euo pipefail
[ "$(uname -s)" != Darwin ] || { echo "On macOS use ./bootstrap-mac.sh." >&2; exit 1; }

install_nix() {
  command -v nix >/dev/null 2>&1 && return
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

# Piped off the web there is no BASH_SOURCE, and `set -u` makes reading it fatal, so fall back to $0.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"

# Step 0, only when piped (`curl ... | bash`): there is no flake.nix beside this file, so become a
# clone and hand over to its copy. The repository is private, which makes this the one login phase 1
# can need; stdin belongs to the pipe, so the prompts are answered at /dev/tty.
if [ ! -f "$DIR/flake.nix" ]; then
  echo "==> Step 0: no clone here, so fetching one to ~/.dotfiles"
  [ ! -e "$HOME/.dotfiles" ] || { echo "    ~/.dotfiles already exists: run ~/.dotfiles/bootstrap.sh instead." >&2; exit 1; }
  [ -e /dev/tty ] || { echo "    No terminal for 'gh auth login': clone haroarthur/dotfiles to ~/.dotfiles by hand, then run ./bootstrap.sh." >&2; exit 1; }
  install_nix # git and gh come out of it: a box this fresh has neither
  nix-shell -p gh git --run 'gh auth status >/dev/null 2>&1 || gh auth login; gh auth setup-git' < /dev/tty
  nix-shell -p gh git --run "git clone https://github.com/haroarthur/dotfiles.git '$HOME/.dotfiles'"
  exec "$HOME/.dotfiles/bootstrap.sh" < /dev/tty
fi

echo "==> Step 1: Determinate Nix"
install_nix

echo "==> Step 2: the account this home is configured for"
# flake.nix names the account once, and a fresh box is often called something else: settle it before
# anything is built, because what would be built is a home for the wrong account.
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
[ -n "$FLAKE_USER" ] || { echo "    Could not find the single \"user = \" line in flake.nix." >&2; exit 1; }
if [ "$FLAKE_USER" != "$REAL_USER" ]; then
  REPLY=y # with no terminal to ask at (a CI runner) rewriting is the only answer that lets the run continue
  [ ! -t 0 ] || read -r -p "    flake.nix is for \"$FLAKE_USER\" but you are \"$REAL_USER\". Rewrite its user line? [y/N] " REPLY
  case "$REPLY" in y | Y) ;; *) echo "    Declined: edit flake.nix's user line yourself, then run this again." >&2; exit 1 ;; esac
  sed -i -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
  echo "    Rewrote it for \"$REAL_USER\". Review: git diff flake.nix"
fi

echo "==> Step 3: the wsl-ubuntu-safe guard"
nix build --no-update-lock-file --no-link "$DIR#checks.x86_64-linux.wsl-ubuntu-safe" \
  || { echo "refusing the switch: the built profile failed flake.nix's wsl-ubuntu-safe guard, and nothing overrides it." >&2; exit 1; }

echo "==> Step 4: register this clone as ~/.dotfiles"
[ "$DIR" = "$HOME/.dotfiles" ] || ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 5: first home-manager switch for ${REAL_USER}@wsl-ubuntu"
# --inputs-from resolves `home-manager` to the revision this flake locks rather than the registry's.
nix run --no-update-lock-file --inputs-from "$HOME/.dotfiles" home-manager -- \
  switch --flake "$HOME/.dotfiles#${REAL_USER}@wsl-ubuntu" -b backup

echo "==> Step 6: installer-managed tools"
# After the switch, because only then is ~/.local/bin on PATH; it is idempotent and prints phase 2.
"$DIR/install-tools.sh" || echo "    install-tools.sh reported failures above - re-run it; the switch itself held." >&2

echo "==> Phase 1 done, and nothing in it needed a login. What is left of phase 2 - nothing, if you"
echo "    logged in first - is printed above and ordered in README.md#a-fresh-machine-in-order."
echo "    Check: ./doctor.sh. Later changes: ./rebuild.sh"
