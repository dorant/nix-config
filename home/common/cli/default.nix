{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    fd
    fzf
    htop
    jq
    ripgrep
    tree

    kubectl
    kubectx
    kubernetes-helm
    kind

    go
    gopls
    shellcheck
  ];

  programs.bat.enable = true;

  # tmux, useful on the headless servers for keeping sessions alive across SSH
  # disconnects. Config is kept minimal and non-opinionated: the prefix key is
  # left at the default C-b, so add personal remaps per machine if wanted.
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 50000;
  };

  # Project-local toolchains and environment, replacing the per-language PATH
  # and *_HOME exports that the old .zshrc set globally.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
