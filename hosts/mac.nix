{ username, ... }:

{
  # nix-darwin's own state version, an integer counter unrelated to the
  # nixpkgs 26.05 release number. Set once at install and left alone.
  system.stateVersion = 5;
  system.primaryUser = username;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  users.users.${username}.home = "/Users/${username}";

  programs.zsh.enable = true;

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      AppleKeyboardUIMode = 3;
      "com.apple.swipescrolldirection" = true;
    };
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 36;
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
    };
  };

  # Casks are apps that must self-update or integrate with macOS in ways a
  # nix store path cannot. Homebrew itself has to be installed once by hand.
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    casks = [
      "google-chrome"
      "slack"
      "microsoft-teams"
      "emacs-app"
      "nikitabobko/tap/aerospace"
    ];
  };
}
