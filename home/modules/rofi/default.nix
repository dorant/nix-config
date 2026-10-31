{ config, lib, ... }:

{
  options.my.rofi.enable = lib.mkEnableOption ''
    rofi configuration. The launcher comes from apt and is invoked by the
    i3 dmenu keybinding
  '';

  config = lib.mkIf config.my.rofi.enable {
    xdg.configFile."rofi/config.rasi".source = ./config.rasi;
  };
}
