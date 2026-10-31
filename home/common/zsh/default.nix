{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    # `unsetopt share_history` in the old .zshrc: each terminal keeps its own
    # history ordering rather than interleaving across open shells.
    history = {
      share = false;
      extended = true;
      size = 50000;
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      # zsh-autosuggestions and zsh-syntax-highlighting are enabled above as
      # first-class options and must not also be listed here.
      plugins = [
        "git"
        "kubectl"
        "docker"
      ];
    };

    shellAliases = {
      ec = "emacsclient -n";
      h = "history";
      hist = "history -t'%F %T'";
      k = "kubectl";
      kadmin = "KUBECONFIG=$HOME/.kube/stack-admin.conf kubectl";
      hadmin = "KUBECONFIG=$HOME/.kube/stack-admin.conf helm";
      images = ''kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" | tr " " "\n"'';
      ll = "ls -la";
    };

    # Secrets are kept out of this repo (and the world-readable Nix store):
    # the token lives in an untracked file sourced at shell startup. envExtra
    # lands in ~/.zshenv, so the variable reaches non-interactive shells too,
    # which is where the kiro-cli wrapper reads GH_VALKEY_OPERATOR_READONLY_TOKEN.
    envExtra = ''
      if [ -f "$HOME/.config/gh_secrets.env" ]; then
        source "$HOME/.config/gh_secrets.env"
      fi
    '';

    initContent = ''
      DISABLE_AUTO_TITLE="true"

      # Timestamp format for the history builtin, matching the `hist` alias.
      HIST_STAMPS="yyyy-mm-dd"

      # The default autosuggestion grey is unreadable against the solarized
      # dark background.
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'

      # zsh-syntax-highlighting declares this as an associative array, but its
      # plugin is sourced after initContent, so declare it here to keep the
      # subscripts from being parsed as arithmetic.
      typeset -A ZSH_HIGHLIGHT_STYLES
      ZSH_HIGHLIGHT_STYLES[path]=none
      ZSH_HIGHLIGHT_STYLES[path_prefix]=none
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Replaces `eval $(dircolors ~/.dir_colors/dircolors)` from the old .zshrc.
  # The palette is the seebi Solarized Dark theme, vendored at the repo root
  # because it is upstream content rather than configuration to maintain here.
  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = builtins.readFile ./dircolors.conf;
  };
}
