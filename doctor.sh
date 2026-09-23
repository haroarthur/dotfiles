#!/usr/bin/env bash
# Owns the read-only, advisory check of what this machine must look like to run an agent fleet: exit 0
# means no phase-1 FAIL - what a login or another OS owns is counted apart - and it reads the live
# Herdr server from /proc rather than opening its socket.
set -uo pipefail

pass=0 warn=0 fail=0 later=0
# check|advise|phase2 LABEL HINT CMD... - CMD's first stdout line is the detail and its exit status the
# verdict; a failure prints HINT as FAIL, as warn, or - for what phase 2 owns, which starts at a login -
# as "phase 2" until this box has logged in, after which it is a FAIL like any other.
check() { verdict FAIL "$@"; }
advise() { verdict warn "$@"; }
phase2() { verdict later "$@"; }
# What this OS cannot have, or what one absent tool already accounts for: said once, counted nowhere.
skip() { printf '  \033[90mskip\033[0m  %-22s %s\n' "$1" "$2"; }
verdict() {
  local level="$1" label="$2" hint="$3" out rc; shift 3
  out="$("$@" 2>/dev/null)"; rc=$?; out="${out%%$'\n'*}"
  [ "$level" != later ] || [ "$logged_in" = no ] || level=FAIL
  if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); printf '  \033[32mok\033[0m    %-22s %s\n' "$label" "$out"
  elif [ "$level" = warn ]; then warn=$((warn + 1)); printf '  \033[33mwarn\033[0m  %-22s %s\n' "$label" "${out:+$out - }$hint"
  elif [ "$level" = later ]; then later=$((later + 1)); printf '  \033[36mphase 2\033[0m %-21s %s\n' "$label" "${out:+$out - }$hint"
  else fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m  %-22s %s\n' "$label" "${out:+$out - }$hint"; fi
}
section() { printf '\n%s\n' "$1"; }
# linux LEVEL ... - only the WSL host can answer these; the Mac has no systemd and no Herdr service.
linux() { local l="$1"; shift; [ "$darwin" = no ] && { "$l" "$@"; return; }; skip "$1" "$wsl_only"; }
# The drop-in checks need the unit no-mistakes' own installer brings up, so one absent tool costs one line, not six.
nmcheck() { [ -n "$nm" ] && { check "$@"; return; }; skip "$1" "$nm_why"; }

has() { case ":$1:" in *":$2:"*) ;; *) return 1 ;; esac; }
real_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }
rev() { [ -e "$1" ] && { git -C "$1" rev-parse --short HEAD 2>/dev/null || echo present; }; }
unit_has() { has "$(systemctl --user show "$1" -p Environment --value | tr ' ' '\n' | sed -n 's/^PATH=//p' | tail -1)" "$2"; }
# Determinate registers its own launchd label; an older or upstream install keeps org.nixos'.
nix_daemon() {
  [ "$darwin" = yes ] || { systemctl is-active nix-daemon.service || systemctl is-active nix-daemon.socket; return; }
  launchctl print system/systems.determinate.nix-daemon >/dev/null 2>&1 && { echo determinate; return; }
  launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1 && echo org.nixos
}
# ~/.agents must be the haroarthur/agents checkout: `npx skills add -g` installs there and cannot move.
agents_checkout() { [ -x "$HOME/.agents/install.sh" ] && [ -r "$lock" ] && rev "$HOME/.agents"; }
# bash prints `alias cc='...'`, zsh prints `cc='...'`; strip either shape down to the value.
cc_alias() {
  local got; got="$("$pane_shell" -i -c 'alias cc' 2>/dev/null | tail -1 | sed -e "s/^alias //" -e "s/^cc=//" -e "s/^'//" -e "s/'$//")"
  echo "${got:-unset}"; [ "$got" = 'claude --dangerously-skip-permissions' ]
}
server_pid() { local p; p="$(systemctl --user show -p MainPID --value herdr.service)"; [ "${p:-0}" != 0 ] && echo "$p"; }
server_exe() { readlink "/proc/$(server_pid)/exe"; }
same_binary() { [ "$(readlink -f "$(command -v herdr)")" = "$(server_exe)" ]; }
# A slice is active only while a unit runs inside it, so loaded - not active - is the floor a pane needs.
slice_loaded() { local s; s="$(systemctl --user show herdr-panes.slice -p LoadState --value)"; echo "$s"; [ "$s" = loaded ]; }
# Panes inherit the RUNNING server's environment - not a login shell, not the unit file - so resolve under its PATH.
# A tool that is not installed at all is already one FAIL on its own row, so this line is only about
# the other failure: installed, and still unreachable from inside a pane.
pane_tools() {
  local path t miss=; path="$(tr '\0' '\n' < "/proc/$(server_pid)/environ" | sed -n 's/^PATH=//p' | tail -1)" || return 1
  for t in $tools_pane; do
    command -v "$t" >/dev/null 2>&1 || continue
    env -i PATH="$path" sh -c "command -v $t" >/dev/null 2>&1 || miss="$miss $t"
  done
  echo "${miss:+unresolved:$miss}"; [ -z "$miss" ]
}
nm_active() { systemctl --user is-active -q "$nm" && echo "$nm"; }
nm_root() { systemctl --user show "$nm" -p ExecStart --value | grep -q -e "--root $HOME/.no-mistakes"; }
nm_umask() { local u; u="$(systemctl --user show "$nm" -p UMask --value)"; echo "$u"; [ "$u" = 0022 ]; }
# On macOS Chrome is the cask hosts/darwin-mac.nix carries, an app bundle and never a PATH entry; on
# WSL it is the .deb chrome-devtools-axi drives.
browser() {
  [ "$darwin" = no ] || { ls -d "/Applications/Google Chrome.app"; return; }
  command -v google-chrome || command -v chromium
}
gh_auth() { gh auth status 2>&1 | sed -n 's/.*Logged in to \([^ ]*\) account \([^ ]*\).*/\1 as \2/p'; gh auth status >/dev/null 2>&1; }
git_helper() {
  local h; h="$(git config --get credential.https://github.com.helper || git config --get --global credential.helper)"
  echo "${h:-unset}"; [ "$h" = '!gh auth git-credential' ]
}
# `readlink -f` disagrees with itself across BSD and GNU on a dangling link, so walk the chain instead.
skills_link() { local p="$HOME/.claude/skills"; while [ -L "$p" ]; do p="$(readlink "$p")"; done; echo "$p"; [ "$p" = "$skills" ]; }
skills_dir() { [ -d "$skills" ] && echo "$(find "$skills" -mindepth 1 -maxdepth 1 | wc -l) entries"; }
# The lock is the one list of expected skills; a second copy in this file would drift away from it.
locked_skills() {
  local s miss=; [ -r "$lock" ] || return 1
  while read -r s; do [ -e "$skills/$s" ] || miss="$miss $s"; done < <(jq -r '.skills | keys[]' "$lock")
  echo "${miss:+missing:$miss}"; [ -z "$miss" ]
}

case "$(uname -s)" in Darwin) darwin=yes pane_shell=zsh ;; *) darwin=no pane_shell=bash ;; esac # the shell a pane comes up in
# tools.list owns these checks: `check` says how a tool is proven and `pane` which tools a pane must
# resolve. It also supplies install-tools.sh's npm packages; Nix packages live in the host modules.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
[ -r "$DIR/tools.list" ] || { echo "no tools.list beside $0 - this clone is incomplete" >&2; exit 2; }
tools_run='' tools_path='' tools_pane=''
while read -r tool _npm check pane; do
  case "$tool" in '' | \#*) continue ;; esac
  case "$check" in run) tools_run="$tools_run $tool" ;; path) tools_path="$tools_path $tool" ;; esac
  [ "$pane" != pane ] || tools_pane="$tools_pane $tool"
done < "$DIR/tools.list"
# Home Manager's generation gcroot: the one path both hosts write. The Mac runs Home Manager as a
# nix-darwin module, whose driver version 1 creates no `home-manager` Nix profile at all.
gen="$(readlink -f "$HOME/.local/state/home-manager/gcroots/current-home" 2>/dev/null)"
wsl_only="WSL host only - no systemd here"
nm_bin=; command -v no-mistakes >/dev/null 2>&1 && nm_bin=no-mistakes
nm=; nm_why="$wsl_only"
if [ "$darwin" = no ]; then
  nm="$(systemctl --user list-units --all --type=service 2>/dev/null | awk '/no-mistakes-daemon-/{print $1; exit}')"
  [ -n "$nm_bin" ] && nm_why="no no-mistakes-daemon unit - inspect the user service" \
    || nm_why="no-mistakes absent - install it with ./install-tools.sh"
fi
logged_in=no; gh auth status >/dev/null 2>&1 && logged_in=yes
skills="$HOME/.agents/skills" lock="$HOME/.agents/.skill-lock.json"
echo "host doctor - $(hostname) - $(date -u +%Y-%m-%dT%H:%MZ)"

section "nix"
check nix "not on PATH - run ./bootstrap.sh (Determinate installer, step 1)" nix --version
check nix-daemon "no multi-user daemon" nix_daemon
section "home"
check generation "this host activates no Home Manager generation" test -n "$gen"
[ -z "$gen" ] || advise packing "the generation packages claude - agent harnesses belong to their installers" test ! -e "$gen/home-path/bin/claude"
check .dotfiles "absent - this is the lived-in home" rev "$HOME/.dotfiles"
for s in bootstrap.sh bootstrap-mac.sh; do check "$s" "missing or not executable (chmod +x)" test -x "$HOME/.dotfiles/$s"; done
check windows.ps1 "missing from ~/.dotfiles" test -f "$HOME/.dotfiles/windows.ps1"
phase2 .agents "clone haroarthur/agents to ~/.agents - it is private, so it waits for the login" agents_checkout
section "shell floor"
check zsh "not on PATH" command -v zsh
linux check herdr-pane-shell "not on PATH" command -v herdr-pane-shell
check 'PATH ~/.local/bin' "absent - installer-managed tools are unreachable" has "$PATH" "$HOME/.local/bin"
check "cc in $pane_shell" "want: claude --dangerously-skip-permissions" cc_alias
section "herdr"
check client "herdr not on PATH" herdr --version # argv only; opens no socket
linux check herdr.service "not active" systemctl --user is-active herdr.service
linux check herdr-panes.slice "not loaded - panes would have no slice to start in" slice_loaded
linux check "server binary" "herdr.service has no running main process" server_exe
linux advise client/server "skew: restart the server in a quiet window to adopt the new client" same_binary
linux check "pane resolves tools" "in the live pane env (restart herdr.service after the switch)" pane_tools
for d in .local/bin bin; do linux check "unit PATH" "herdr.service lacks ~/$d - panes cannot resolve installer-managed tools" unit_has herdr.service "$HOME/$d"; done
check .config/herdr "missing, or a symlink (runtime state would land in the git tree)" real_dir "$HOME/.config/herdr"
section "agent tools"
# tools.list's `run` rows are RUN, not just resolved: a stale shim of the right name sits on PATH and
# then fails to exec, which `command -v` reads as green. Each is offline and sub-second.
for t in $tools_run; do check "$t" "absent, or on PATH but cannot run" "$t" --version; done
for t in $tools_path; do check "$t" "not on PATH" command -v "$t"; done
# pkgs/no-mistakes.nix's drop-in can stop applying silently, so these three assert its EFFECT, not the file.
nmcheck "nm daemon" "no active no-mistakes-daemon unit" nm_active
nmcheck "nm root" "the unit does not serve ~/.no-mistakes, so the drop-in is misaddressed" nm_root
nmcheck "nm umask" "want 0022, else pipeline fixtures go group-writable" nm_umask
nmcheck "nm PATH" "no ~/.local/bin - the daemon cannot find the tools a pipeline shells out to" unit_has "$nm" "$HOME/.local/bin"
section "browser"
check browser "no chrome/chromium for chrome-devtools-axi" browser
section "auth"
phase2 "gh auth" "not logged in (run: gh auth login)" gh_auth
phase2 "git helper" "want '!gh auth git-credential' (run: gh auth setup-git)" git_helper
section "skills"
check .claude/skills "not a symlink to ~/.agents/skills - Claude is not reading it" skills_link
phase2 .agents/skills "missing - clone haroarthur/agents to ~/.agents" skills_dir
phase2 "installed skills" "run ~/.agents/install.sh" locked_skills
phase2 "no-mistakes skill" "comes with no-mistakes' own installer, so it waits for the private skills checkout" test -e "$skills/no-mistakes"

printf '\n\n%d ok, %d warn, %d FAIL, %d phase 2\n' "$pass" "$warn" "$fail" "$later"
[ "$fail" -eq 0 ]
