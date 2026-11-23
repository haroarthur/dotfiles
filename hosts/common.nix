{
  config,
  lib,
  pkgs,
  ...
}:

# Owns what both hosts share: links into home/ and ~/.agents, session flags, secrets and program settings.

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

  # A private ~/.secrets.env (KEY=value, outside any clone). The option is Home Manager-internal, but it
  # is the one way into hm-session-vars.sh, which every login shell sources.
  home.sessionVariablesExtra = ''
    if [ -r "$HOME/.secrets.env" ]; then set -a; . "$HOME/.secrets.env"; set +a; fi
  '';

  home.file = {
    # One rulebook, linked into every harness.
    ".claude/CLAUDE.md".source = link ".dotfiles/home/AGENTS.md";
    ".codex/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";
    ".config/opencode/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";
    ".grok/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";
    ".pi/agent/AGENTS.md".source = link ".dotfiles/home/AGENTS.md";

    # Skills live in ~/.agents (haroarthur/agents): Codex reads it natively, Claude through this.
    ".claude/skills".source = link ".agents/skills";

    ".config/nvim".source = link ".dotfiles/home/.config/nvim";
    ".config/wezterm".source = link ".dotfiles/home/.config/wezterm";

    # Pi: only the authored files, so credentials and sessions stay local.
    ".pi/agent/themes".source = link ".dotfiles/home/.pi/agent/themes";
    ".pi/agent/extensions".source = link ".dotfiles/home/.pi/agent/extensions";
    ".pi/agent/models.json".source = link ".dotfiles/home/.pi/agent/models.json";
  };

  # Writable files, never links: each program rewrites its own. Claude's and Cursor's get their tracked
  # `attribution` merged on every activation; Pi's is a day-one seed.
  home.activation.manageProgramSettings =
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
      (
        let
          seed = target: source: ''
            settings_target="${config.home.homeDirectory}/${target}"
            settings_dir="$(${pkgs.coreutils}/bin/dirname "$settings_target")"
            run ${pkgs.coreutils}/bin/install -d -m 0755 -- "$settings_dir"
            if [ ! -e "$settings_target" ] && [ ! -L "$settings_target" ]; then
              run ${pkgs.coreutils}/bin/install -m 0644 -- ${source} "$settings_target"
            fi
          '';
          merge = target: seedFile: ''
            settings_target="${config.home.homeDirectory}/${target}"
            settings_dir="$(${pkgs.coreutils}/bin/dirname "$settings_target")"
            run ${pkgs.coreutils}/bin/install -d -m 0755 -- "$settings_dir"
            if [ ! -e "$settings_target" ] && [ ! -L "$settings_target" ]; then
              run ${pkgs.coreutils}/bin/install -m 0644 -- ${seedFile} "$settings_target"
            else
              settings_tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_dir/.settings.XXXXXX")"
              if ! ${pkgs.jq}/bin/jq --null-input --slurpfile policy ${seedFile} 'input * ($policy[0] | {attribution})' "$settings_target" > "$settings_tmp"; then
                ${pkgs.coreutils}/bin/rm -f -- "$settings_tmp"
                echo "Cannot merge managed settings into $settings_target" >&2
                exit 1
              fi
              if ! ${pkgs.diffutils}/bin/cmp -s -- "$settings_target" "$settings_tmp"; then
                run ${pkgs.coreutils}/bin/chmod 0644 "$settings_tmp"
                run ${pkgs.coreutils}/bin/mv -f -- "$settings_tmp" "$settings_target"
              else
                ${pkgs.coreutils}/bin/rm -f -- "$settings_tmp"
              fi
            fi
          '';
        in
        merge ".claude/settings.json" ../home/.claude/settings.json
        + merge ".cursor/cli-config.json" ../home/.cursor/cli-config.json
        + seed ".pi/agent/settings.json" ../home/.pi/agent/settings.json
      );

  # Seeded, never linked: Herdr rewrites config.toml and keeps sockets, logs and sessions beside it.
  # Before the systemd reload, so a first activation leaves a config for the service.
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
