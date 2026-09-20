{ pkgs, ... }:

# Owns the shell both hosts come up in: zsh, starship, the aliases, six commands and EDITOR.

{
  home.packages = with pkgs; [
    ripgrep # fast search
    fd # fast find
    fzf # fuzzy finder
    jq # json on the command line
    lazygit
    neovim
  ];

  home.sessionVariables.EDITOR = "nvim";

  # Installer-managed tools land in ~/.local/bin (claude, codex, cursor-agent, pi, the AXI tools,
  # no-mistakes), and Home Manager puts it on PATH for no shell by itself. ~/bin stays on PATH for
  # anything hand-placed there; nothing this repo installs targets it.
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true; # ghost text from history
    syntaxHighlighting.enable = true; # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };
}
