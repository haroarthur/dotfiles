{
  config,
  lib,
  pkgs,
  ...
}:

# Owns what both hosts share: the shared npm toolchain, the rulebook links, the Claude session flags
# and the private secrets export, the editable pointers into home/, the one skills symlink and the
# Herdr config seed.

let
  # An out-of-store link under $HOME, so an edit in the clone is live with no rebuild.
  link = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${path}";
in
{
  programs.home-manager.enable = true;

  # Both hosts need npm for the installer-managed AXI and harness tools.
  home.packages = [ pkgs.nodejs ];

  # Claude flags as shell env - not in settings.json - so Claude cannot regress them by rewrite.
  home.sessionVariables = {
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = "500000";
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
    CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1";
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
    # Claude Mods load only while this is exactly 1: the compact-adviser plugin and Firstmate's Calm mod.
    CLAUDE_CODE_ENABLE_FUNCTION_HOOKS = "1";
  };

  # Secrets never enter this repository: a private ~/.secrets.env of KEY=value lines, kept outside any
  # clone, is exported beside the flags above - TYPESAFE_API_KEY for compact-adviser, for one
  # (README.md#compact-adviser). The option is Home Manager-internal, but it is the one way into
  # hm-session-vars.sh, the file every login shell on both hosts already sources.
  home.sessionVariablesExtra = ''
    if [ -r "$HOME/.secrets.env" ]; then set -a; . "$HOME/.secrets.env"; set +a; fi
  '';

  home.file = {
    # One rulebook, linked into every harness; a link costs nothing while the harness is absent.
    ".claude/CLAUDE.md".source = link ".dotfiles/home/AGENTS.md";
    ".codex/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";
    ".config/opencode/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";
    ".grok/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";
    ".pi/agent/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";

    # Skills live in ~/.agents (haroarthur/agents): Codex reads it natively, Claude through this.
    ".claude/skills".source = link ".agents/skills";

    ".config/nvim".source = link ".dotfiles/home/.config/nvim";
    ".config/wezterm".source = link ".dotfiles/home/.config/wezterm";

    # Pi: only the authored files, so credentials and sessions stay local. settings.json is not here -
    # it is seeded below, with Claude's.
    ".pi/agent/themes".source = link ".dotfiles/home/.pi/agent/themes";
    ".pi/agent/extensions".source = link ".dotfiles/home/.pi/agent/extensions";
    ".pi/agent/models.json".source = link ".dotfiles/home/.pi/agent/models.json";
  };

  # Claude's and Pi's settings.json are SEEDED, never linked, for the reason Herdr's config.toml is:
  # both programs rewrite the file they were given - Claude its model and the dangerous-mode prompt,
  # Pi the changelog version it last showed - and behind an out-of-store link every one of those
  # writes landed in the git tree, so the clone was permanently dirty. The tracked file is day-one
  # content; after that the live file belongs to the program. Nothing that must not regress lives in
  # them: the Claude session variables above and the `cc` alias in pkgs/shell.nix are outside both.
  home.activation.seedProgramSettings =
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
      (
        let
          seed = target: source: ''
            seed_target="${config.home.homeDirectory}/${target}"
            run ${pkgs.coreutils}/bin/install -d -m 0755 -- "$(${pkgs.coreutils}/bin/dirname "$seed_target")"
            if [ ! -e "$seed_target" ] && [ ! -L "$seed_target" ]; then
              run ${pkgs.coreutils}/bin/install -m 0644 -- ${source} "$seed_target"
            fi
          '';
        in
        seed ".claude/settings.json" ../home/.claude/settings.json
        + seed ".pi/agent/settings.json" ../home/.pi/agent/settings.json
      );

  # Herdr's config is seeded, never linked: Herdr rewrites config.toml and keeps its sockets, logs
  # and sessions beside it, which must not land in the git tree. Only an absent file is written,
  # before the systemd reload so a first activation leaves a config for the service.
  home.activation.seedHomeHerdrConfig =
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
      ''
        herdr_config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
        herdr_config_file="$herdr_config_root/config.toml"
        run ${pkgs.coreutils}/bin/install -d -m 0700 -- "$herdr_config_root"
        if [ ! -e "$herdr_config_file" ] && [ ! -L "$herdr_config_file" ]; then
          run ${pkgs.coreutils}/bin/install -m 0600 -- \
            ${../home/.config/herdr/config.toml} "$herdr_config_file"
        fi
      '';
}
