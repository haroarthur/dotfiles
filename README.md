# dotfiles

A bootstrap for two machines: a Windows notebook running WSL Ubuntu, and a Mac. One clone at
`~/.dotfiles` brings either one up from nothing - Nix, Home Manager, the shell, the terminal, the
editor, the agent tooling - and stays the place they are changed from afterwards.

It is one flake, two host compositions and a handful of hand-run scripts. Nothing runs on a timer
and nothing converges behind your back.

## What is in it

| Path | What it holds |
| --- | --- |
| `flake.nix` | The two configurations and the checks that gate a switch. Its one `user =` line names the account; every configuration name and home path derives from it |
| `hosts/` | One file per machine - `wsl-ubuntu.nix`, `mac.nix` + `darwin-mac.nix` - plus `common.nix` for what they share |
| `pkgs/` | What the hosts compose: the shared shell, and the WSL host's floor (Herdr, the host `systemctl`, the no-mistakes drop-in) |
| `home/` | Authored files the home takes: the agent rulebook, nvim and WezTerm as live links; the Claude, Pi and Herdr configs as seeds the programs then own |
| `bootstrap.sh` / `bootstrap-mac.sh` | A fresh machine, from nothing to a built home |
| `rebuild.sh` / `rebuild-mac.sh` | A later change to a machine already running this |
| `install-tools.sh` / `doctor.sh` | Install what Nix deliberately does not carry; check what a machine looks like |
| `tools.list` | The one list of installer-managed tools both of those read: four plain columns, no rebuild |
| `windows.ps1` | The Windows side: WSL Ubuntu, WezTerm, the Hack Nerd Font, `.wslconfig`, and the `.wezterm.lua` that loads this clone's config |

The rule the packing follows: **if a tool ships an official installer, or is a plain package, use
it. Keep Nix only where there is a concrete blocker, named in the file that keeps it.** Nothing is
hand-pinned any more; what Nix still owns for Herdr is its service and pane isolation, not its
binary.

## Start here

The login comes first, because the account you log in with is the same one the private skills
checkout needs afterwards, and `gh` is the clean way to clone. One login, at the top, and nothing
below it is typed by hand.

```sh
# 1. Determinate Nix - the same installer bootstrap.sh runs, and where a naked box gets `gh`
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 2. the login, and the clone it makes possible
nix-shell -p gh --run 'gh auth login && gh auth setup-git'
nix-shell -p gh --run 'gh repo clone haroarthur/dotfiles ~/.dotfiles'

# 3. the machine, out of the clone
~/.dotfiles/bootstrap.sh     # ~/.dotfiles/bootstrap-mac.sh on a Mac
~/.dotfiles/doctor.sh        # read it to zero FAIL
```

There is no second command to remember afterwards. Step 3 ends in
[`install-tools.sh`](install-tools.sh), and because the login already exists by then, that first pass
is also the one that clones the private `~/.agents` and installs the skills. On Ubuntu or WSL,
`sudo apt-get install -y gh` is a shorter step 1 if you prefer; Nix arrives with `bootstrap.sh`
either way.

Piping the bootstrap off the web also works now that this repository is public - `curl -fsSL
.../bootstrap.sh | bash` notices it has no clone beside it and fetches one, asking for the login the
private skills still need as it goes - but the login-first order above is the tidier one. This public
repository is a **fresh root**: it carries the finished shape without the working history, which
stays private.

### The Windows side

One thing must happen before Ubuntu exists, and it is the only step that needs an administrator:

```powershell
wsl --install -d Ubuntu-24.04
```

Reboot, launch Ubuntu, create your account - any name works; step 3 above compares
[flake.nix](flake.nix)'s one `user = "haro";` line against `whoami` and offers to rewrite it - and run
**Start here** inside it. Everything else on the Windows side then runs out of the clone. From an
admin PowerShell, two lines:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& (wsl.exe -d Ubuntu-24.04 -e sh -c 'wslpath -w "$HOME/.dotfiles/windows.ps1"')
```

**The first line is the snag, not a precaution.** A script in the clone is a file on the WSL network
share, and PowerShell refuses to load one under any policy stricter than `Bypass`: under the
`RemoteSigned` this notebook carries, `\\wsl.localhost\<distro>\home\<user>\.dotfiles\windows.ps1`
comes back refused as not digitally signed (`FullyQualifiedErrorId : UnauthorizedAccess`). `-Scope
Process` lasts for that one window, changes nothing on the machine and needs no administrator of its
own. The second line is the trick `.wezterm.lua` already uses: `wsl.exe` resolves the path inside
the explicitly selected Ubuntu 24.04 distro, so the account name is never typed and another default
distro cannot redirect the setup.

**What was proven here, and what was not.** The refusal, the `-Scope Process Bypass` that clears it,
the `wsl.exe`-resolved path, and [`windows.ps1`](windows.ps1) parsing over that path were all
executed on this notebook, from a PowerShell reached out of WSL. What was **not** executed: this host
has no Windows administrator access, so neither an elevated session nor `wsl --install` itself was
run - the form above is proven for everything except the elevation, which `-Scope Process` does not
need anyway. Two edges it does not cover. Where Group Policy sets an execution policy -
`Get-ExecutionPolicy -List` shows `MachinePolicy` or `UserPolicy` as anything but `Undefined` -
`-Scope Process` is refused and nothing in-session helps: copy `windows.ps1` to a local disk path and
run it there. And a one-shot equivalent, proven the same way, is
`powershell -NoProfile -ExecutionPolicy Bypass -File \\wsl.localhost\<distro>\home\<user>\.dotfiles\windows.ps1`,
which works but types both names.

That run does five things - `wsl --install` again, which sees the distro already there and says so,
WezTerm by `winget`, the Hack Nerd Font, `%USERPROFILE%\.wslconfig`, and the small
`%USERPROFILE%\.wezterm.lua` that loads the real config out of the clone. There is no Linux WezTerm:
the Windows app is the terminal and talks to the WSL domain, which is why its config is a Windows file.

### A fresh machine, in order

The **scripts** still come up in two phases, and that split is load-bearing even though a person at a
keyboard logs in before either of them: phase 1 is the machine and needs no login, phase 2 is the
account and starts at `gh auth login`. Phase 1 uses public inputs only, which is what lets CI run
these same scripts with no credential at all
([bootstrap-check.yml](.github/workflows/bootstrap-check.yml)). Logging in first does not change that
contract - it only means phase 2's work happens inside phase 1's last step.

1. **Windows only:** `wsl --install -d Ubuntu-24.04` in an admin PowerShell, then reboot and create your
   Ubuntu account. Skip this on a Mac.
2. **The login and the clone** - steps 1 and 2 of **Start here**.
3. **[`bootstrap.sh`](bootstrap.sh)** (or `bootstrap-mac.sh`) from `~/.dotfiles`. It installs Nix,
   settles the account name against `whoami`, builds the `wsl-ubuntu-safe` guard, links the clone to
   `~/.dotfiles`, runs the first switch, and finishes in [`install-tools.sh`](install-tools.sh).
4. Everything else comes with that last step: Herdr, no-mistakes, the Google Cloud SDK, the Grok CLI,
   Claude Code's compact-adviser plugin ([below](#compact-adviser)), the Chrome `.deb` that
   `chrome-devtools-axi` drives, and - the login being already in place - the
   private `~/.agents` checkout and its skills. `~/.claude/skills` already links to `~/.agents/skills`.
   The Chrome step runs `sudo apt-get`, so it asks for your password as it goes; the Mac takes brews
   and casks instead.
5. **Windows only:** the two admin-PowerShell lines above, out of the clone.
6. `./doctor.sh`, and read it to zero FAIL.

## Daily use

```sh
./doctor.sh          # what does this machine look like? read-only, changes nothing
./install-tools.sh   # run every installer the packing deliberately does not carry
./rebuild.sh         # apply a change to this host   (./rebuild-mac.sh on a Mac)
nix flake check      # prove a change without switching to it
```

**[`doctor.sh`](doctor.sh)** checks the end state rather than who provided it, one check per line, and
takes the tools it asks about from [`tools.list`](tools.list) - a `run` row is executed rather than
resolved, because a stale shim of the right name passes `command -v` and then fails to exec.
It never opens the Herdr socket - the running server is read from `/proc/<MainPID>` - so it is safe
with a live fleet under it. Exit 0 means no phase-1 FAIL: what a login owns is counted apart as
`phase 2` and what this OS cannot have as `skip`, so neither reds a healthy box. It is advisory and
deliberately gates nothing.

**[`install-tools.sh`](install-tools.sh)** runs every installer the packing does not carry, and the
names are not restated here: [`tools.list`](tools.list) is the list, four plain columns, read by this
script and by `doctor.sh` alike. A tool that npm provides is installed straight off that file, so
adding or swapping one is a one-line edit and a re-run, with no rebuild - none of this is in the Nix
packing. A tool with its own installer keeps a step here too, because a step is a paragraph of
reasons rather than a name. The one thing this script will not do is `gh auth login`. Every step is
idempotent, so re-running it is how a machine is repaired, and a failure names which step to retry
instead of hiding the others.

**`rebuild.sh`** is how this host changes. In front of `home-manager switch` stands one guard, about
content rather than authorization: it and `bootstrap.sh` build `checks.x86_64-linux.wsl-ubuntu-safe`
([flake.nix](flake.nix)), which asserts the built generation has `herdr`, `zsh`, `herdr-pane-shell`,
`herdr.service` and `herdr-panes.slice`. A green build cannot tell a full profile from one without
Herdr, and activating that one stops every agent pane. No flag or variable overrides it; a hand-run
`home-manager switch` goes around it, at your own risk.

**`nix flake check`** builds the WSL generation, runs that guard, and evaluates the Mac on Linux, so
a broken `hosts/mac.nix` goes red here rather than on the Mac's first day. CI runs it on every pull
request and push to `main`. The full bootstrap on clean macOS and Linux runners
([bootstrap-check.yml](.github/workflows/bootstrap-check.yml)) is opt-in: it runs only when a pull
request changes `bootstrap*.sh`, `install-tools.sh`, `windows.ps1`, or the `tools.list` input, or when
it carries the `bootstrap` label. It is never a required check. Run `nix fmt` before committing, and
`git add` new files - Nix cannot see them otherwise.

### The shell, WezTerm and Herdr

Both hosts come up in the same shell, and [pkgs/shell.nix](pkgs/shell.nix) is all of it: zsh,
starship, seven aliases, six commands and `EDITOR=nvim`. `cc` is
`claude --dangerously-skip-permissions`, which is how an agent pane starts.
[pkgs/shell-wsl.nix](pkgs/shell-wsl.nix) is the WSL host's alone: **bash** as the login shell, and
the **OSC 7 working-directory hook**, without which every new pane opens in `/mnt/c/Users/<user>`.

WezTerm is one file for both hosts, [home/.config/wezterm/wezterm.lua](home/.config/wezterm/wezterm.lua),
with a Windows branch. There is no second Windows copy: `windows.ps1` writes a small
`%USERPROFILE%\.wezterm.lua` that resolves this clone through `wsl.exe` and loads that file, falling
back to a plain terminal while WSL is still coming up. It is also where the distro name comes from -
it reads it off the resolved path and hands it to the branch, so the domain is never typed anywhere.
Herdr comes from its own installer on WSL and from Homebrew on the Mac; what the packing owns is the
part a package cannot bring - `herdr.service`, `herdr-panes.slice` and the pane shell
([pkgs/herdr/module.nix](pkgs/herdr/module.nix)), with the unit execing `~/.local/bin/herdr`. Its
`config.toml` is a **seed**, not a link: copied once when absent, because Herdr keeps its sockets,
logs and sessions beside it and those must not land in the git tree.

### Skills and Firstmate

Skills do not live here. They live in **[haroarthur/agents](https://github.com/haroarthur/agents)**,
checked out at `~/.agents`: the personal ones tracked there, third-party ones re-added by its
`./install.sh`. This repository declares one thing about that: on both machines `~/.claude/skills`
is a symlink to `~/.agents/skills`, which Codex reads natively. The `no-mistakes` skill ships with
its own installer.

Firstmate is an agent distro ([kunchenguid/firstmate](https://github.com/kunchenguid/firstmate)),
never an `npx skills` install, and its skills must never be vendored. Day one on a **new** machine
is a fresh clone and one harness; `AGENTS.md` takes over from there. Never clone it over a live home.

```sh
git clone https://github.com/kunchenguid/firstmate && cd firstmate
claude          # or: grok --trust   or: pi   or: FM_PI_HARNESS=pi-signed pi-signed
```

### Records for a fresh Firstmate home

A Firstmate home keeps its durable memory in `data/` - the backlog, the captain's standing notes,
each live task's brief and report - and the distro gitignores that directory and ships nothing in it.
It lives instead in the private **haroarthur/fleet-records**, one branch per home: `home/main` for
the primary, `home/analytics` and `home/agent-env` for the second mates. Restoring a home is one
clone of its branch into the `data/` that home does not have yet:

```sh
git clone --branch home/main --single-branch \
  https://github.com/haroarthur/fleet-records.git ~/firstmate/data
git -C ~/firstmate/data remote -v && git -C ~/firstmate/data branch --show-current
```

**The refusal is the point, and it is git's own.** A clone into a path that already holds anything
stops with `destination path already exists and is not an empty directory`, so this cannot write over
a home that already has records - there is no flag here to reach for and none should be added. Do it
before that home's first launch, while `data/` does not exist yet. If it does exist and is not empty,
that home has records: move them aside and merge by hand.

What comes back is memory, not evidence. The branch carries its own `.gitignore`, which tracks the
root markdown, `config/`, and each live task's `brief.md` and `report.md` - nothing else. The cold
archive stays on disk and in `~/fleet-archive`, and is never in the branch to restore.

**A second mate is the same shape with its own root and branch** - `git clone --branch
home/analytics ... <that home>/data` - and that is reasoned, not tested. This notebook runs one live
home, `~/firstmate` on `home/main`, which is what the recipe above was checked against; both
second-mate homes are archived under `~/fleet-archive`, so nothing here proved their path end to end.

### compact-adviser

[compact-adviser](https://github.com/kunchenguid/compact-adviser) tells a Claude Code or Pi session
when it is safe to `/compact`.

- **Claude Code:** `install-tools.sh` installs the plugin. It loads only while
  `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1`, which [hosts/common.nix](hosts/common.nix) exports to every
  login shell - the same switch turns on Firstmate's Calm mod.
- **Pi:** `npm:compact-adviser@0.1.6` is in the `settings.json` seed, pinned like the packages
  beside it, and Pi installs a listed package when it starts. The seed is day-one content, never
  re-applied to a live host, so a host whose settings predate it runs
  `pi install npm:compact-adviser@0.1.6` once.

**The key** is a TypeSafe API key - a secret, so never in this repository. Once per machine, either
put `TYPESAFE_API_KEY=...` in a private `~/.secrets.env` outside any clone, which every login shell
on both hosts exports ([hosts/common.nix](hosts/common.nix)), or save it once per harness through
`/compact-adviser` in Pi and in Claude Code (once the mod has loaded).

## Make it yours

1. **The account name.** [flake.nix](flake.nix) names it once, in `user = "haro";`. The bootstrap
   scripts offer to rewrite that line when it does not match `whoami`.
2. **The rulebook.** `home/AGENTS.md` is the one global rulebook; both machines link it into
   Claude, Codex, OpenCode, Grok and Pi. Write your own; the links do not care what is in it.
3. **Your own configs.** WezTerm and nvim are out-of-store pointers into `home/`, so an edit in the
   clone is live with no rebuild. Claude's and Pi's `settings.json` are **seeds**: copied once when
   absent, and after that the live file belongs to the program that rewrites it - which is why the
   clone no longer goes dirty every time Claude records a model. Anything that must not regress lives
   outside them, in the session variables and the shell.
4. **Packages and tools.** Base packages are plain names in `hosts/wsl-ubuntu.nix` or
   `hosts/mac.nix`. Everything an installer brings is one line in [tools.list](tools.list), which
   `install-tools.sh` and `doctor.sh` both read, so adding or swapping a tool is that line and a
   re-run of the two - never a rebuild.
5. **Secrets.** None are here: passwords and API keys go in a `.env` in the home that needs one, and a
   key every shell should carry - `TYPESAFE_API_KEY` for [compact-adviser](#compact-adviser) - in a
   private `~/.secrets.env` outside any clone, which every login shell exports.

The host-specific choices to look at first are the Herdr memory ceilings in
[pkgs/herdr/module.nix](pkgs/herdr/module.nix), sized for this box's RAM, and the `.wslconfig` in
[windows.ps1](windows.ps1), which sizes the VM they sit inside.
