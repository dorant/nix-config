{ config, lib, ... }:

{
  options.my.dunst.enable = lib.mkEnableOption ''
    dunst configuration. The daemon comes from apt and is started on demand
    over D-Bus by the notify-send calls in the helper scripts
  '';

  config = lib.mkIf config.my.dunst.enable {
    xdg.configFile."dunst/dunstrc".source = ./dunstrc;
  };
}
