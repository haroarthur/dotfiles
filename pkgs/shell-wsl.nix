{ config, lib, ... }:

# Owns the two shell pieces that are the WSL host's alone: bash as the login shell, and so the shell
# a WezTerm pane comes up in, and the WezTerm OSC 7 working-directory hook.

let
  # Percent-encodes $PWD byte by byte, in the syntax bash and zsh share - the offset stays `$i`
  # because zsh reads a bare `i` there as a history modifier. It reports to a terminal only: zsh runs
  # chpwd hooks inside command substitution, where the escape would be captured as data.
  osc7 = ''
    _dotfiles_osc7() {
      [ -t 1 ] || return 0
      local LC_ALL=C
      local encoded="" char hex i
      for (( i = 0; i < ''${#PWD}; i++ )); do
        char="''${PWD:$i:1}"
        case "$char" in
          [A-Za-z0-9/._~-]) encoded="$encoded$char" ;;
          *) printf -v hex '%%%02X' "'$char"; encoded="$encoded$hex" ;;
        esac
      done
      printf '\033]7;file://%s%s\033\\' "''${HOSTNAME:-''${HOST:-}}" "$encoded"
    }
  '';

  osc7Zsh = osc7 + ''
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _dotfiles_osc7
    _dotfiles_osc7
  '';

  osc7Bash = osc7 + ''
    case "''${PROMPT_COMMAND:-};''${STARSHIP_PROMPT_COMMAND:-}" in
      *_dotfiles_osc7*) ;;
      *) PROMPT_COMMAND="_dotfiles_osc7''${PROMPT_COMMAND:+;''${PROMPT_COMMAND}}" ;;
    esac
  '';
in
{
  # mkAfter layers onto ./shell.nix's zsh block rather than redefining it.
  programs.zsh.initContent = lib.mkAfter osc7Zsh;

  programs.bash = {
    enable = true;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    # Enabling bash hands Home Manager ~/.bashrc, so the distribution's aliases worth keeping are
    # restated; the rest is read off the zsh block so the two shells cannot drift.
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    }
    // config.programs.zsh.shellAliases;
    initExtra = lib.mkMerge [
      # bash has no chpwd, so it reports from PROMPT_COMMAND - at 1800, BEFORE starship's init at
      # 1900, which moves an existing PROMPT_COMMAND aside and so still reads the real exit status.
      # The guard keeps a re-sourced bashrc from stacking copies.
      (lib.mkOrder 1800 osc7Bash)
      (lib.mkOrder 2000 ''
        [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
        if [ -x /usr/bin/dircolors ]; then
          test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        fi
      '')
    ];
  };
}
