{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.my.aerospace.enable = lib.mkEnableOption ''
    AeroSpace, the tiling window manager standing in for i3 on macOS.
    Keybindings mirror the i3 ones where macOS allows it; Alt substitutes
    for i3's Mod4, which macOS reserves
  '';

  config = lib.mkIf config.my.aerospace.enable {
    home.packages = [ pkgs.aerospace ];

    xdg.configFile."aerospace/aerospace.toml".text = ''
      start-at-login = true
      default-root-container-layout = 'tiles'

      [gaps]
      inner.horizontal = 4
      inner.vertical = 4
      outer.left = 4
      outer.right = 4
      outer.top = 4
      outer.bottom = 4

      [mode.main.binding]
      alt-enter = 'exec-and-forget open -na Alacritty'

      alt-h = 'split horizontal'
      alt-v = 'split vertical'
      alt-f = 'fullscreen'

      alt-left = 'focus left'
      alt-down = 'focus down'
      alt-up = 'focus up'
      alt-right = 'focus right'

      alt-shift-left = 'move left'
      alt-shift-down = 'move down'
      alt-shift-up = 'move up'
      alt-shift-right = 'move right'

      alt-1 = 'workspace 1'
      alt-2 = 'workspace 2'
      alt-3 = 'workspace 3'
      alt-4 = 'workspace 4'
      alt-5 = 'workspace 5'

      alt-shift-1 = 'move-node-to-workspace 1'
      alt-shift-2 = 'move-node-to-workspace 2'
      alt-shift-3 = 'move-node-to-workspace 3'
      alt-shift-4 = 'move-node-to-workspace 4'
      alt-shift-5 = 'move-node-to-workspace 5'

      alt-r = 'mode resize'

      [mode.resize.binding]
      left = 'resize width -50'
      right = 'resize width +50'
      up = 'resize height -50'
      down = 'resize height +50'
      enter = 'mode main'
      esc = 'mode main'
    '';
  };
}
