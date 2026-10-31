{ ... }:

{
  imports = [
    ../common
    ../modules
  ];

  # There is no i3 on macOS. AeroSpace tiles in a similar way and needs no
  # SIP changes. GUI applications come from the Homebrew casks declared in
  # hosts/mac.nix.
  my.aerospace.enable = true;

  # Claude only on the mac; Kiro is not run here (kiro.enable left off).
  my.agents = {
    enable = true;
    claude.enable = true;
  };

  # profileExtra rather than initContent: this runs for login shells, where
  # PATH belongs, and it leaves the zsh initContent in common/zsh untouched.
  programs.zsh.profileExtra = ''
    # Homebrew provides the GUI casks that nixpkgs cannot ship on macOS.
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  '';
}
