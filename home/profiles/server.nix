{ ... }:

{
  # Headless machines: the common CLI layer (zsh, git, go, kubectl, kind, helm)
  # and nothing else. None of the desktop modules (i3, picom, rofi, dunst) are
  # imported, so this profile pulls in no X dependencies.
  imports = [ ../common ];

  # Fixes up PATH, XDG_DATA_DIRS and locale handling that NixOS would otherwise
  # provide. Required on any non-NixOS distribution.
  targets.genericLinux.enable = true;
}
