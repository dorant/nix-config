{ config, lib, ... }:

{
  options.my.picom.enable = lib.mkEnableOption ''
    picom configuration. The compositor binary comes from apt, since it links
    against the distro's GPU drivers; i3 starts it
  '';

  # The settings predate the compton-to-picom rename but remain valid for
  # picom, so the file is installed verbatim under its new name.
  config = lib.mkIf config.my.picom.enable {
    xdg.configFile."picom.conf".source = ./picom.conf;
  };
}
