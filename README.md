# dotfiles

A bootstrap for two machines: a Windows notebook running WSL Ubuntu, and a Mac. One clone at
`~/.dotfiles` brings either one up from nothing - Nix, Home Manager, the shell, the terminal, the
editor, the agent tooling - and stays the place they are changed from afterwards.

It is one flake, two host compositions and a handful of hand-run scripts. Nothing runs on a timer.

## What is in it

| Path | What it holds |
| --- | --- |
| `flake.nix` | The two configurations and the checks that gate a switch. Its one `user =` line names the account; every configuration name and home path derives from it |
| `hosts/` | One file per machine - `wsl-ubuntu.nix`, `mac.nix` + `darwin-mac.nix` - plus `common.nix` for what they share |
| `pkgs/` | What the hosts compose: the shared shell, and the WSL host's floor (Herdr, the host `systemctl`, the no-mistakes drop-in) |
| `home/` | Authored files the home takes: the agent rulebook, nvim and WezTerm as live links; Claude and Cursor policy merged into writable settings; Pi and Herdr seeds the programs then own |
| `bootstrap.sh` / `bootstrap-mac.sh` | A fresh machine, from nothing to a built home |
| `rebuild.sh` / `rebuild-mac.sh` | A later change to a machine already running this |
| `install-tools.sh` / `doctor.sh` | Install what Nix deliberately does not carry; check what a machine looks like |
| `tools.list` | The doctor's tool checks and the npm packages installed by `install-tools.sh`: four plain columns |
| `windows.ps1` | The Windows side: WSL Ubuntu, WezTerm, the Hack Nerd Font, `.wslconfig`, and the `.wezterm.lua` that loads this clone's config |

The rule the packing follows: **use official installers for tools that ship them and host packages
for plain packages. Keep custom Nix integration only where there is a concrete blocker, named in
the file that keeps it.**

## Start here

Log in first: the same account clones the private skills checkout later.

```sh
# 1. Determinate Nix - the same installer bootstrap.sh runs, and where a naked box gets `gh`
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 2. the login, and the clone it makes possible
nix-shell -p gh --run 'gh auth login && GH_PATH=gh gh auth setup-git'
nix-shell -p gh --run 'gh repo clone haroarthur/dotfiles ~/.dotfiles'

# 3. the machine, out of the clone
~/.dotfiles/bootstrap.sh     # ~/.dotfiles/bootstrap-mac.sh on a Mac
~/.dotfiles/doctor.sh        # read it to zero FAIL
```

Step 3 ends in [`install-tools.sh`](install-tools.sh), which, with the login already in place, also
clones the private `~/.agents` and installs the skills. `curl -fsSL .../bootstrap.sh | bash` works
too: with no clone beside it, it fetches one and asks for the login as it goes.

### The Windows side

One thing must happen before Ubuntu exists, and it is the only step that needs an administrator:

```powershell
wsl --install -d Ubuntu-24.04
```

Reboot, launch Ubuntu, create your account - any name works; step 3 above offers to rewrite
[flake.nix](flake.nix)'s `user = "haro";` line to match - and run **Start here** inside it. Then, from
an admin PowerShell, run the rest out of the clone:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& (wsl.exe -d Ubuntu-24.04 -e sh -c 'wslpath -w "$HOME/.dotfiles/windows.ps1"')
```

The first line is required: a script on the WSL share is refused under `RemoteSigned`, and
`-Scope Process` changes nothing beyond that window. `wsl.exe` resolves the path inside the named
distro, so the account name is never typed. Where Group Policy sets an execution policy
(`Get-ExecutionPolicy -List`), copy `windows.ps1` to a local disk and run it there. Not run here: an
elevated session and `wsl --install` itself.

It installs WezTerm by `winget` and the Hack Nerd Font, and writes `%USERPROFILE%\.wslconfig` and the
small `%USERPROFILE%\.wezterm.lua` that loads the real config out of the clone.

### A fresh machine, in order

Phase 1 is the machine and needs no login, which is what lets CI run these scripts
([bootstrap-check.yml](.github/workflows/bootstrap-check.yml)); phase 2 is the account and starts at
`gh auth login`. Logging in first only means phase 2 happens inside phase 1's last step.

1. **Windows only:** `wsl --install -d Ubuntu-24.04` in an admin PowerShell, then reboot and create your
   Ubuntu account.
2. **The login and the clone** - steps 1 and 2 of **Start here**.
3. **[`bootstrap.sh`](bootstrap.sh)** (or `bootstrap-mac.sh`): Nix, the account name, the
   `wsl-ubuntu-safe` guard, the first switch, then [`install-tools.sh`](install-tools.sh).
4. That last step brings Herdr, no-mistakes, the Google Cloud SDK, the Grok CLI, the
   [compact-adviser](#compact-adviser) plugin, Chrome and the private `~/.agents` skills. On WSL the
   Chrome `.deb` asks for your password; the Mac asks for it for the Nix installer and each
   `darwin-rebuild switch`, and needs no Xcode Command Line Tools.
5. **Windows only:** the two admin-PowerShell lines above, out of the clone.
6. `./doctor.sh`, and read it to zero FAIL.

### GitHub over SSH

The `gh` credential helper is the default; SSH also works, and [`doctor.sh`](doctor.sh) passes either.
These steps are for a Mac; on Linux or WSL, leave out `UseKeychain` and `--apple-use-keychain`.

1. Make a key with a passphrase: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`.
2. On macOS, put the passphrase in the Keychain: `/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519`.
3. Add a block to `~/.ssh/config`. `UseKeychain yes` is macOS only:

   ```sshconfig
   Host github.com
     IdentityFile ~/.ssh/id_ed25519
     IdentitiesOnly yes
     AddKeysToAgent yes
     UseKeychain yes
   ```

4. Pin GitHub's host keys from the API into `~/.ssh/known_hosts`:
   `gh api meta --jq '.ssh_keys[] | "github.com " + .' >> ~/.ssh/known_hosts`.
5. Register the key. The first command asks for a one-time approval in the browser:
   `gh auth refresh -h github.com -s admin:public_key`, then `gh ssh-key add ~/.ssh/id_ed25519.pub`.
6. Make `gh` and `git` use it: `gh config set git_protocol ssh` and
   `git config --global url."git@github.com:".insteadOf https://github.com/`.
7. Remove the `gh auth git-credential` helper entries from `~/.gitconfig`.
8. Check with `ssh -T git@github.com`, which answers "successfully authenticated", and `./doctor.sh`.

## Daily use

```sh
./doctor.sh          # what does this machine look like? read-only, changes nothing
./install-tools.sh   # run every installer the packing deliberately does not carry
./rebuild.sh         # apply a change to this host   (./rebuild-mac.sh on a Mac)
nix flake check      # prove a change without switching to it
```

**[`doctor.sh`](doctor.sh)** checks the end state, one line per check, with its tool list from
[`tools.list`](tools.list). It never opens the Herdr socket, so it is safe under a live fleet. Exit 0
means no phase-1 FAIL; `phase 2` and `skip` lines are not failures. It gates nothing.

**[`install-tools.sh`](install-tools.sh)** runs every installer the packing does not carry. Every step
is idempotent, so re-running it is the repair, and a failure names the step to retry.

**`rebuild.sh`** builds the `wsl-ubuntu-safe` guard ([flake.nix](flake.nix)) before
`home-manager switch`: a profile without Herdr's units or the pane shell would stop every agent
pane. Nothing overrides it; a hand-run `home-manager switch` goes around it.

**`nix flake check`** builds the WSL generation, runs that guard and evaluates the Mac; CI runs it on
every pull request and push to `main`. The full bootstrap on clean runners
([bootstrap-check.yml](.github/workflows/bootstrap-check.yml)) is opt-in. Run `nix fmt` before
committing, and `git add` new files - Nix cannot see them otherwise.

### Agent attribution

Attribution is switched off in each harness's local settings, which activation merges into the live
writable JSON without touching other preferences:

- **Claude Code:** `attribution.commit` and `attribution.pr` are empty in
  [`home/.claude/settings.json`](home/.claude/settings.json).
- **Cursor Agent CLI:** both `attribution` booleans are false in
  [`home/.cursor/cli-config.json`](home/.cursor/cli-config.json).

Codex, Pi, Grok and OpenCode have no local attribution setting; for them the rulebook line in
[home/AGENTS.md](home/AGENTS.md) is the only guard.

### The shell, WezTerm and Herdr

Both hosts share [pkgs/shell.nix](pkgs/shell.nix): zsh, starship, the aliases and `EDITOR=nvim`. `cc`
is `claude --dangerously-skip-permissions`, which is how an agent pane starts.
[pkgs/shell-wsl.nix](pkgs/shell-wsl.nix) adds, on WSL only, **bash** as the login shell and the
**OSC 7 hook**, without which every new pane opens in `/mnt/c/Users/<user>`.

WezTerm is one file for both hosts, [home/.config/wezterm/wezterm.lua](home/.config/wezterm/wezterm.lua),
with a Windows branch that the `windows.ps1` stub loads through `wsl.exe`. Herdr comes from its own
installer on WSL and from Homebrew on the Mac; [pkgs/herdr/module.nix](pkgs/herdr/module.nix) owns
`herdr.service`, `herdr-panes.slice` and the pane shell. Its `config.toml` is a **seed**, copied once,
because Herdr keeps sockets, logs and sessions beside it.

### Mac apps

Three casks on the Mac are apps, not tools, and each needs a person after the rebuild:

- **OpenSuperWhisper** is local Whisper dictation. Grant it the microphone and accessibility
  permissions by hand in System Settings.
- **Automic Vault** hardens the credentials command-line tools read. Installing it hardens nothing.
  Start with the read-only `av scan`, then harden tools one at a time, `gh` and `gcloud` last,
  because unattended jobs use them.
- **Tailscale** (`tailscale-app`) reaches this Mac from a phone. Nothing signs in for you; see
  [Reaching the Mac from a phone](#reaching-the-mac-from-a-phone).

### Reaching the Mac from a phone

1. After the rebuild, sign in to Tailscale on the Mac, approving the network extension if asked.
2. Turn on Remote Login in System Settings, limited to your own user.
3. Install Tailscale on the Android phone and sign in with the same account.
4. In Termius add a host: the Mac's Tailscale name, user haro, port 22.
5. Connect and run herdr.
6. For a Lavish board, add a Local port forward, phone 4387 to 127.0.0.1:4387, then open the board
   link in the phone browser.

### Skills and Firstmate

Skills live in **[haroarthur/agents](https://github.com/haroarthur/agents)**, checked out at
`~/.agents`; this repository only links `~/.claude/skills` to `~/.agents/skills`, which Codex reads
natively. The `no-mistakes` skill ships with its own installer.

Firstmate ([kunchenguid/firstmate](https://github.com/kunchenguid/firstmate)) is a fresh clone and one
harness on a **new** machine - never an `npx skills` install, never vendored, never cloned over a
live home.

```sh
git clone https://github.com/kunchenguid/firstmate && cd firstmate
claude          # or: grok --trust   or: pi   or: FM_PI_HARNESS=pi-signed pi-signed
```

### Records for a fresh Firstmate home

A home's `data/` (backlog, standing notes, task briefs and reports) is gitignored by the distro and
lives in the private **haroarthur/fleet-records**, one branch per home: `home/main` for the primary,
`home/analytics` and `home/agent-env` for the second mates. Restore it before the home's first
launch, into a `data/` that does not exist yet:

```sh
git clone --branch home/main --single-branch \
  https://github.com/haroarthur/fleet-records.git ~/firstmate/data
git -C ~/firstmate/data remote -v && git -C ~/firstmate/data branch --show-current
```

Git refuses to clone into a non-empty path, so this cannot overwrite a home's records; add no flag
around it. If `data/` already has records, move them aside and merge by hand. The branch carries
memory only - root markdown, `config/`, and each live task's brief and report. A second mate uses
its own branch the same way (untested).

### compact-adviser

[compact-adviser](https://github.com/kunchenguid/compact-adviser) tells a Claude Code or Pi session
when it is safe to `/compact`.

- **Claude Code:** `install-tools.sh` installs the plugin. It loads only while
  `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1`, which [hosts/common.nix](hosts/common.nix) exports.
- **Pi:** `npm:compact-adviser@0.1.6` is in the `settings.json` seed. A host whose settings predate
  it runs `pi install npm:compact-adviser@0.1.6` once.

**The key** is a TypeSafe API key, never in this repository: put `TYPESAFE_API_KEY=...` in a private
`~/.secrets.env` outside any clone, which every login shell exports, or save it through
`/compact-adviser` in each harness.

## Make it yours

1. **The account name.** [flake.nix](flake.nix) names it once, in `user = "haro";`; the bootstrap
   scripts offer to rewrite it.
2. **The rulebook.** `home/AGENTS.md` is linked into Claude, Codex, OpenCode, Grok and Pi. Write your
   own.
3. **Your own configs.** WezTerm and nvim link into `home/`, so an edit is live with no rebuild. Pi's
   `settings.json` is a seed; Claude's and Cursor's get only their attribution policy re-merged.
4. **Packages and tools.** Base packages are plain names in `hosts/wsl-ubuntu.nix` or
   `hosts/mac.nix`. An installer-brought tool is one line in [tools.list](tools.list) and a re-run of
   `install-tools.sh` - never a rebuild.
5. **Secrets.** None are here: a `.env` in the home that needs one, or `~/.secrets.env` for a key
   every shell should carry.

Host-specific sizes to check first: the Herdr memory ceilings in
[pkgs/herdr/module.nix](pkgs/herdr/module.nix) and the `.wslconfig` in [windows.ps1](windows.ps1).
