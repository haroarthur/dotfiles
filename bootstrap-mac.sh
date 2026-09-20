#!/usr/bin/env bash
# Owns phase 1 on a NEW Mac: the machine, from nothing to a switched nix-darwin + Homebrew home, on
# public inputs with no login - a Mac already running this changes through ./rebuild-mac.sh instead.
set -euo pipefail
[ "$(uname -s)" = Darwin ] || { echo "bootstrap-mac.sh is for macOS only: never apply a darwin configuration from the WSL host." >&2; exit 1; }

install_nix() {
  command -v nix >/dev/null 2>&1 && return
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

# Piped off the web there is no BASH_SOURCE, and `set -u` makes reading it fatal, so fall back to $0.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"

# Step 0, only when piped (`curl ... | bash`): the same self-clone bootstrap.sh does, for the same reasons.
if [ ! -f "$DIR/flake.nix" ]; then
  echo "==> Step 0: no clone here, so fetching one to ~/.dotfiles"
  [ ! -e "$HOME/.dotfiles" ] || { echo "    ~/.dotfiles already exists: run ~/.dotfiles/bootstrap-mac.sh instead." >&2; exit 1; }
  [ -e /dev/tty ] || { echo "    No terminal for 'gh auth login': clone haroarthur/dotfiles to ~/.dotfiles by hand, then run ./bootstrap-mac.sh." >&2; exit 1; }
  install_nix # git and gh come out of it: a box this fresh has neither
  nix-shell -p gh git --run 'gh auth status >/dev/null 2>&1 || gh auth login; gh auth setup-git' < /dev/tty
  nix-shell -p gh git --run "git clone https://github.com/haroarthur/dotfiles.git '$HOME/.dotfiles'"
  exec "$HOME/.dotfiles/bootstrap-mac.sh" < /dev/tty
fi

echo "==> Step 1: Determinate Nix"
install_nix

echo "==> Step 2: register this clone as ~/.dotfiles"
[ "$DIR" = "$HOME/.dotfiles" ] || ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 3: the account this home is configured for"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
[ -n "$FLAKE_USER" ] || { echo "    Could not find the single \"user = \" line in flake.nix." >&2; exit 1; }
if [ "$FLAKE_USER" != "$REAL_USER" ]; then
  REPLY=y # with no terminal to ask at (a CI runner) rewriting is the only answer that lets the run continue
  [ ! -t 0 ] || read -r -p "    flake.nix is for \"$FLAKE_USER\" but you are \"$REAL_USER\". Rewrite its user line? [y/N] " REPLY
  case "$REPLY" in y | Y) ;; *) echo "    Declined: edit flake.nix's user line yourself, then run this again." >&2; exit 1 ;; esac
  sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
  echo "    Rewrote it for \"$REAL_USER\". Review: git diff flake.nix"
fi

echo "==> Step 4: first darwin-rebuild switch (nix-darwin + the Homebrew WezTerm, Herdr and Claude)"
# --inputs-from resolves `nix-darwin` to the revision this flake locks; a bare github: ref re-resolves
# the branch through api.github.com every run, whose unauthenticated limit 403s on a busy CI runner.
sudo "$(command -v nix)" run --no-update-lock-file --inputs-from "$HOME/.dotfiles" nix-darwin#darwin-rebuild -- \
  switch --flake "$HOME/.dotfiles#mac"

echo "==> Step 5: installer-managed tools"
# The same installer set as WSL; the cask-backed steps see their tool present and skip. Prints phase 2.
# Optional installer failures stay advisory, but a missing or incomplete npm toolchain must fail CI.
# useUserPackages puts home.packages (nodejs) in /etc/profiles/per-user/$USER/bin, which /etc/zshrc adds
# but this non-login shell never sourced; put it on PATH so install-tools.sh finds npm.
export PATH="/etc/profiles/per-user/$REAL_USER/bin:$PATH"
install_tools_status=0
"$DIR/install-tools.sh" || install_tools_status=$?
if [ "$install_tools_status" -eq 2 ]; then
  echo "    install-tools.sh could not install the required npm tools." >&2
  exit 2
elif [ "$install_tools_status" -ne 0 ]; then
  echo "    install-tools.sh reported optional failures above - re-run it; the switch itself held." >&2
fi

echo "==> Phase 1 done, and nothing in it needed a login. What is left of phase 2 - nothing, if you"
echo "    logged in first - is printed above and ordered in README.md#a-fresh-machine-in-order."
echo "    Check: ./doctor.sh. Later changes: ./rebuild-mac.sh"
