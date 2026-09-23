# hosts/

| File | Status |
| --- | --- |
| `wsl-ubuntu.nix` | The Windows + WSL Ubuntu composition. Home Manager only; **no Homebrew**. Composes this host's packing from `../pkgs`, the floor `flake.nix`'s `wsl-ubuntu-safe` check guards. |
| `common.nix` | Shared out-of-store links (WezTerm included) + Claude session flags + the private `~/.secrets.env` export. Points `~/.claude/skills` at `~/.agents/skills`. **Seeds**, never links: the Herdr config, and Claude's and Pi's `settings.json` - each is rewritten by the program that owns it. |
| `mac.nix` | The Mac Home Manager user (wired into `darwinConfigurations.mac`). Imports `../pkgs/shell.nix` - the same shell the WSL host comes up in - and adds host packages and fontconfig. Never `../pkgs/shell-wsl.nix`. |
| `darwin-mac.nix` | Real nix-darwin + nix-homebrew: WezTerm/Claude casks, Herdr brew. **Do not apply from WSL.** |

Day-one Mac entry point: repo-root `bootstrap-mac.sh` -> `darwinConfigurations.mac`.

The Mac composition is evaluated on Linux by the `mac-eval` flake check, so a `hosts/mac.nix` or
`hosts/darwin-mac.nix` that does not evaluate goes red in CI.
