{
  pkgs,
  lib,
  username,
  ...
}:

{
  imports = [
    ./cli
    ./fonts
    ./git
    ./zsh
  ];

  home = {
    # mkDefault so the nix-darwin integration, which derives both from
    # users.users.<name>, takes precedence on macOS. On standalone Linux these
    # are the only definitions and apply as written.
    username = lib.mkDefault username;
    homeDirectory = lib.mkDefault (
      if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"
    );

    # The release this profile was first installed with. It is not a version to
    # keep current: home-manager uses it to decide which backwards-compatible
    # defaults to keep, so bumping it changes behaviour and is only safe after
    # reading that release's notes.
    stateVersion = "26.05";

    sessionVariables = {
      LANG = "en_US.UTF-8";
      EDITOR = "emacsclient -n";
    };
  };

  programs.home-manager.enable = true;
}
