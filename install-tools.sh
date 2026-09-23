#!/usr/bin/env bash
# Owns running the official installer of every tool the packing does not carry: every step is
# idempotent so re-running it is the repair. `gh auth login` is the one thing a person must type.
# Everything else is done here - including the one apt package, which asks for this machine's
# password, and the private skills checkout once the login exists.
set -uo pipefail

# One installer failing must not hide the others, nor leave the operator guessing which to re-run.
failed=
required_failed=0
step() { printf '\n==> %s\n' "$1"; current="$1"; }
note_failure() { failed="${failed}
  - ${current}: $1"; echo "    FAILED: $1" >&2; }

# tools.list supplies npm packages below and doctor.sh's tool checks. Other rows may name tools
# supplied by their own installer or by a host's Nix packages.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
[ -r "$DIR/tools.list" ] || { echo "no tools.list beside $0 - this clone is incomplete" >&2; exit 2; }
npm_pkgs=() npm_soft=() npm_bins=()
while read -r tool npm check _pane; do
  case "$tool" in '' | \#*) continue ;; esac
  [ "$npm" != - ] || continue
  # An unasserted row is installed but never checked, so it must not fail the batch beside it.
  if [ "$check" = - ]; then npm_soft+=("$npm"); else npm_pkgs+=("$npm") npm_bins+=("$tool"); fi
done < "$DIR/tools.list"

# `curl ... | bash` hides a failed fetch: curl exits non-zero, bash reads an empty script and
# succeeds. Behind a captive portal that is a half-installed host, so fetch first, then run it.
run_installer() {
  local url="$1" tmp; shift
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' RETURN
  curl -fsSL "$url" -o "$tmp"
  [ -s "$tmp" ] || { echo "empty installer from $url" >&2; return 1; }
  "$@" bash "$tmp"
}

step "Claude Code"
if command -v claude >/dev/null 2>&1; then echo "    present: $(command -v claude)"
else
  # A shell exporting either variable makes this installer install nothing, so clear them for it.
  run_installer https://claude.ai/install.sh env -u DISABLE_AUTOUPDATER -u DISABLE_UPDATES \
    || note_failure "claude.ai/install.sh"
fi

step "compact-adviser plugin for Claude Code"
# A plugin, not a tool, so not in tools.list. It loads only while CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1,
# which hosts/common.nix exports; the key is a one-time step by hand (README.md#compact-adviser).
# The Claude installer lands in ~/.local/bin, which a first Mac run does not have on PATH yet.
claude_path="$HOME/.local/bin:$PATH"
if ! PATH="$claude_path" command -v claude >/dev/null 2>&1; then echo "    no claude - the step above says why"
elif grep -qF '"compact-adviser@compact-adviser"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
  echo "    present: compact-adviser@compact-adviser"
else
  { PATH="$claude_path" claude plugin marketplace add kunchenguid/compact-adviser \
    && PATH="$claude_path" claude plugin install compact-adviser@compact-adviser; } \
    || note_failure "claude plugin install compact-adviser@compact-adviser"
fi

# Every installer below writes into ~/.local/bin. Create it ours first: treehouse sudo-creates a
# missing target dir, and a root-owned ~/.local/bin then blocks npm's own symlinks with EACCES.
mkdir -p "$HOME/.local/bin"

step "Treehouse"
if command -v treehouse >/dev/null 2>&1; then echo "    present: $(command -v treehouse)"
else
  # It targets ~/.local/bin only when that is already on PATH, else it asks for sudo. It resolves its
  # version through an unauthenticated api.github.com call, which fails whenever this IP's 60/hour
  # quota is spent - routine under an agent fleet: `curl -sS https://api.github.com/rate_limit`.
  run_installer https://raw.githubusercontent.com/kunchenguid/treehouse/main/docs/install.sh \
    env "PATH=$HOME/.local/bin:$PATH" \
    || note_failure "treehouse install.sh (often the unauthenticated github api quota - re-run later)"
fi

step "npm tools: the AXI CLIs, the harness CLIs and backpass - every npm row of tools.list"
# Node's own prefix is a read-only store path; ~/.local/bin is on the PATH every pane inherits.
# A package name is not its binary's name, which is why tools.list carries both columns.
if ! command -v npm >/dev/null 2>&1; then
  note_failure "npm is required for the AXI and harness tools"
  required_failed=1
else
  npm config set prefix "$HOME/.local" >/dev/null \
    || { note_failure "npm config set prefix"; required_failed=1; }
  [ "${#npm_soft[@]}" -eq 0 ] || npm install -g "${npm_soft[@]}" || note_failure "npm install -g ${npm_soft[*]}"
  if npm install -g "${npm_pkgs[@]}"; then
    for t in "${npm_bins[@]}"; do
      if [ ! -x "$HOME/.local/bin/$t" ]; then
        note_failure "required npm tool missing: $t"
        required_failed=1
      fi
    done
  else
    note_failure "npm install -g ${npm_pkgs[*]}"
    required_failed=1
  fi
fi

step "Cursor CLI"
if command -v cursor-agent >/dev/null 2>&1; then echo "    present: $(command -v cursor-agent)"
else
  # No npm package ships this one; its own installer is unattended and targets ~/.local/bin.
  run_installer https://cursor.com/install || note_failure "cursor.com/install"
fi

step "Herdr"
# The fleet's terminal server, installed by its own installer into ~/.local/bin - the exact path
# pkgs/herdr/module.nix's unit execs. On the Mac it is the brew hosts/darwin-mac.nix carries.
if [ "$(uname -s)" = Darwin ]; then echo "    Mac: the herdr brew comes with the switch"
elif command -v herdr >/dev/null 2>&1; then echo "    present: $(command -v herdr)"
else
  run_installer https://herdr.dev/install.sh || note_failure "herdr.dev/install.sh"
fi
# A first switch writes the unit before this installs the binary, so the service skipped its start.
# Start it - never restart it: every live pane, and this shell, is inside the running one.
if [ "$(uname -s)" != Darwin ] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-active --quiet herdr.service || systemctl --user start herdr.service || true
fi

step "no-mistakes"
if command -v no-mistakes >/dev/null 2>&1; then echo "    present: $(command -v no-mistakes)"
else
  run_installer https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh \
    env "PATH=$HOME/.local/bin:$PATH" \
    || note_failure "no-mistakes install.sh"
fi

step "Google Cloud SDK (gcloud, bq)"
# The analytics work runs on these two. The env vars are the documented way to run the installer
# unattended, and with prompts off it edits no rc file. Each tool resolves its own SDK root through
# the link it was called by, so a link from ~/.local/bin - already on every pane's PATH - is enough.
if [ -x "$HOME/google-cloud-sdk/bin/gcloud" ]; then echo "    present: $HOME/google-cloud-sdk/bin/gcloud"
else
  run_installer https://sdk.cloud.google.com \
    env CLOUDSDK_CORE_DISABLE_PROMPTS=1 CLOUDSDK_INSTALL_DIR="$HOME" \
    || note_failure "sdk.cloud.google.com"
fi
for t in gcloud bq gsutil; do
  if [ -x "$HOME/google-cloud-sdk/bin/$t" ]; then ln -sfn "$HOME/google-cloud-sdk/bin/$t" "$HOME/.local/bin/$t"; fi
done

step "Grok CLI"
# The installer can return non-zero after the executable is in place, so judge the result by the
# executable contract the doctor uses rather than reporting a false failure.
grok_installed() { [ -x "$HOME/.grok/bin/grok" ] && "$HOME/.grok/bin/grok" --version >/dev/null 2>&1; }
if grok_installed; then echo "    present: $HOME/.grok/bin/grok"
else
  # Unset SHELL on purpose: named one, this installer appends a PATH block to that shell's rc file,
  # which Home Manager owns and keeps in the read-only store. With none it only does the part that
  # works here - the binary, and a link from a PATH directory, which is why PATH is passed in.
  if run_installer https://x.ai/cli/install.sh env -u SHELL "PATH=$HOME/.local/bin:$PATH"; then
    if grok_installed; then
      echo "    installed: $HOME/.grok/bin/grok"
    else
      note_failure "x.ai/cli/install.sh did not leave a runnable Grok binary"
    fi
  elif grok_installed; then
    echo "    installed: $HOME/.grok/bin/grok (installer completed with a non-zero status)"
  else
    note_failure "x.ai/cli/install.sh"
  fi
fi

step "Google Chrome"
# chrome-devtools-axi drives it. The Mac takes the cask hosts/darwin-mac.nix carries; on WSL it is a
# .deb, and the one step here that asks for this machine's password - a user path cannot install one.
if [ "$(uname -s)" = Darwin ]; then echo "    Mac: the google-chrome cask comes with the switch"
elif command -v google-chrome >/dev/null 2>&1; then echo "    present: $(command -v google-chrome)"
else
  chrome_deb="$(mktemp --suffix=.deb)"
  if curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$chrome_deb"; then
    echo "    sudo apt-get install: this asks for your password"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$chrome_deb" \
      || note_failure "apt-get install google-chrome-stable"
  else
    note_failure "downloading google-chrome-stable_current_amd64.deb"
  fi
  rm -f "$chrome_deb"
fi

step "Capability skills"
# ~/.agents (haroarthur/agents) owns the skill list, and its install.sh re-runs every `npx skills
# add`. The repository is private, so the clone is the first thing phase 2 can do, and it happens
# here rather than by hand. Before the login there is nothing to clone: that box is still in phase 1.
if [ ! -e "$HOME/.agents" ]; then
  if gh auth status >/dev/null 2>&1; then
    git clone https://github.com/haroarthur/agents.git "$HOME/.agents" || note_failure "git clone haroarthur/agents"
  else
    echo "    no login yet - run this again after gh auth login and it clones ~/.agents"
  fi
fi
if [ -x "$HOME/.agents/install.sh" ]; then
  "$HOME/.agents/install.sh" || note_failure "$HOME/.agents/install.sh (re-run it; each add is idempotent)"
fi

# Logged in before the bootstrap - the order README.md#start-here documents - the step above already
# took ~/.agents, and there is no second run to ask for. Without a login there still is.
if [ -e "$HOME/.agents" ]; then
  cat <<'EOF'

==> Nothing is left to type: the login was already in place, so this pass took ~/.agents with it.
Check the machine:  ./doctor.sh
EOF
else
  cat <<'EOF'

==> PHASE 2 - one login, and this script again (README.md#a-fresh-machine-in-order has the detail)
  1. gh auth login && gh auth setup-git && ~/.dotfiles/install-tools.sh
     The second run clones the private ~/.agents and installs the skills; nothing else is by hand.
Then check the machine:  ./doctor.sh
EOF
fi

if [ -n "$failed" ]; then
  printf '\nSome steps did not complete:%s\n\nRe-run ./install-tools.sh to retry them.\n' "$failed" >&2
  [ "$required_failed" -eq 0 ] || exit 2
  exit 1
fi
