# dotfiles

Home configuration for two machines - Windows + WSL Ubuntu, and a Mac - cloned to `~/.dotfiles`.
[README.md](README.md) is the reader's entry point; this file is what an agent needs before editing.

- Machine-wide agent rulebook: [home/AGENTS.md](home/AGENTS.md)
- Host compositions: [hosts/](hosts/). Packing: [pkgs/](pkgs/). Every file's header is one sentence saying what it owns
- [pkgs/shell.nix](pkgs/shell.nix) is the one module BOTH hosts import; anything WSL-only about the shell belongs in [pkgs/shell-wsl.nix](pkgs/shell-wsl.nix)
- **Use official installers for tools that ship them and host packages for plain packages; keep custom Nix integration only where there is a concrete blocker, named in the file that keeps it.** No new wrapper, control plane or converger without naming the blocker
- **[windows.ps1](windows.ps1) is one self-contained file** and must stay that way: it may never read a sibling. `$distro` is its single source for the distro name, and the README mirrors that name
- **[tools.list](tools.list) owns the doctor's tool checks and `install-tools.sh`'s npm inputs.** Never grow a second tool list. A harness plugin (compact-adviser) is never a row there
- **Skills are not in this repository.** They live in `haroarthur/agents` at `~/.agents`; the one pointer is `~/.claude/skills` in [hosts/common.nix](hosts/common.nix). Never add a `home/skills/` or a second skill list
- Every PR body reports the total Nix+shell line count before and after, computed as `git ls-files '*.nix' '*.sh' | xargs wc -l | tail -1`; never claim "lean" unless that number went down
- Comments carry only a non-obvious reason - a workaround, a constraint, a surprising behaviour - in as few lines as it takes. No history, no restated code, no argument for the design; the README carries no research notes or dated checks

A fresh machine comes up in two phases, and the split is load-bearing: **phase 1 is the machine and needs no login**, **phase 2 is the account** and starts at `gh auth login`. Nothing that needs a credential belongs in phase 1; that is what lets CI run the entry scripts ([.github/workflows/bootstrap-check.yml](.github/workflows/bootstrap-check.yml)).

`./doctor.sh` is read-only and **advisory on purpose** - never wire it into `rebuild.sh` or `bootstrap.sh` as a gate; only a phase-1 FAIL means anything. `./install-tools.sh` installs each tool only when absent, so a rerun never restarts a running daemon. Claude's and Pi's `settings.json`, like the Herdr config, are **seeded and never linked** ([hosts/common.nix](hosts/common.nix)); never turn them back into `home.file` entries.

Never run `bootstrap.sh` / `rebuild.sh` / `home-manager switch` without being told to. What protects a live host is the `wsl-ubuntu-safe` guard both scripts build before they switch ([flake.nix](flake.nix)); a hand-run `home-manager switch` goes around it. `bootstrap.sh` is for a NEW box only.

Prove a change by building, not switching: `nix flake check`. A refactor must also leave the live host untouched: build the generation before and after and compare the `herdr.service` and `herdr-panes.slice` unit files byte for byte, because a switch never restarts the running server and a changed unit is what a later restart would adopt. Run `nix fmt` before committing; new files must be `git add`ed before Nix can see them.

## Firstmate on a new machine

Day-one install is in [README.md](README.md#skills-and-firstmate). Never clone over a live Firstmate home; never `npx skills add` Firstmate. Restore a home's records only into a `data/` that does not exist yet - [README.md](README.md#records-for-a-fresh-firstmate-home); never reach past git's refusal into a home that already has records.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
