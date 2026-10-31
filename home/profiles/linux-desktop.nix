{ ... }:

{
  # The i3 session on Ubuntu. Each module here generates configuration only;
  # the binaries (i3, picom, rofi, dunst, i3blocks, i3lock, the tray applets)
  # come from apt because they link against the distro's X server and GPU
  # drivers. See the README for the full division.
  imports = [
    ../common
    ../modules
  ];

  # Fixes up PATH, XDG_DATA_DIRS and locale handling that NixOS would
  # otherwise provide. Required on any non-NixOS distribution.
  targets.genericLinux.enable = true;

  my = {
    i3.enable = true;
    picom.enable = true;
    rofi.enable = true;
    dunst.enable = true;

    # Docker is available on the laptop, so the containerised agents and the
    # kind cluster they talk to both live here. Both Kiro and Claude.
    agents = {
      enable = true;
      kiro.enable = true;
      claude.enable = true;
    };
  };
}
