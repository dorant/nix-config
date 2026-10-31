{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.my.i3;
  machine = config.my.machine;

  xTools = import ../../../pkgs/x-tools.nix { inherit pkgs lib machine; };

  wallpaper = ./TCP118v1_by_Tiziano_Consonni.jpg;
  lockScript = "${config.xdg.configHome}/i3/i3lock-fancy-multimonitor/lock";
in
{
  options.my.i3.enable = lib.mkEnableOption ''
    i3 configuration. The i3 binary itself comes from apt; this generates
    its config, the i3blocks bar, and the helper scripts it calls
  '';

  config = lib.mkIf cfg.enable {
    home.packages =
      with xTools;
      [
        keymapToggle
        touchpadToggle
        setupScreens
        getKeymap
      ]
      ++ [
        # Userland tools with no X-server or GPU coupling, so nixpkgs is safe.
        pkgs.playerctl
        pkgs.brightnessctl
      ];

    xdg.configFile = {
      "i3/config".text = ''
        set $mod Mod4
        set $main_window ${machine.mainOutput}
        set $touchpad_name "${machine.touchpadName}"
        set $autolock_minutes 60

        font pango: System San Francisco Display 10

        floating_modifier $mod

        bindsym $mod+Return exec i3-sensible-terminal
        bindsym $mod+Shift+q kill
        bindsym $mod+d exec --no-startup-id i3-dmenu-desktop --dmenu='rofi -i -dmenu'

        bindsym $mod+j focus left
        bindsym $mod+k focus down

        bindsym $mod+Left focus left
        bindsym $mod+Down focus down
        bindsym $mod+Up focus up
        bindsym $mod+Right focus right

        bindsym $mod+Shift+j move left
        bindsym $mod+Shift+k move down
        bindsym $mod+Shift+l move up
        bindsym $mod+Shift+odiaeresis move right

        bindsym $mod+Shift+Left move left
        bindsym $mod+Shift+Down move down
        bindsym $mod+Shift+Up move up
        bindsym $mod+Shift+Right move right

        bindsym $mod+h split h
        bindsym $mod+v split v
        bindsym $mod+f fullscreen toggle

        bindsym $mod+s layout stacking
        bindsym $mod+w layout tabbed
        bindsym $mod+e layout toggle split

        bindsym $mod+Shift+space floating toggle
        bindsym $mod+space focus mode_toggle
        bindsym $mod+a focus parent

        set $ws1 "1: Emacs "
        set $ws2 "2: Chrome "
        set $ws3 "3: Teams "
        set $ws4 "4: >"

        bindsym $mod+1 workspace $ws1
        bindsym $mod+2 workspace $ws2
        bindsym $mod+3 workspace $ws3
        bindsym $mod+4 workspace $ws4
        bindsym $mod+5 workspace 5
        bindsym $mod+6 workspace 6
        bindsym $mod+7 workspace 7
        bindsym $mod+8 workspace 8
        bindsym $mod+9 workspace 9
        bindsym $mod+0 workspace 10

        bindsym $mod+Shift+1 move container to workspace $ws1
        bindsym $mod+Shift+2 move container to workspace $ws2
        bindsym $mod+Shift+3 move container to workspace $ws3
        bindsym $mod+Shift+4 move container to workspace $ws4
        bindsym $mod+Shift+5 move container to workspace 5
        bindsym $mod+Shift+6 move container to workspace 6
        bindsym $mod+Shift+7 move container to workspace 7
        bindsym $mod+Shift+8 move container to workspace 8
        bindsym $mod+Shift+9 move container to workspace 9
        bindsym $mod+Shift+0 move container to workspace 10

        bindsym $mod+Shift+c reload
        bindsym $mod+Shift+r restart
        bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"

        mode "resize" {
                bindsym j resize shrink width 10 px or 10 ppt
                bindsym k resize grow height 10 px or 10 ppt
                bindsym l resize shrink height 10 px or 10 ppt
                bindsym odiaeresis resize grow width 10 px or 10 ppt

                bindsym Left resize shrink width 10 px or 10 ppt
                bindsym Down resize grow height 10 px or 10 ppt
                bindsym Up resize shrink height 10 px or 10 ppt
                bindsym Right resize grow width 10 px or 10 ppt

                bindsym Return mode "default"
                bindsym Escape mode "default"
        }

        bindsym $mod+r mode "resize"

        bar {
          status_command i3blocks -c ${config.xdg.configHome}/i3/i3blocks.conf

          # Applets live on the primary screen only, though every screen gets a bar.
          tray_output $main_window

          colors {
              background #002b36
              statusline #839496
              separator  #586e75
              focused_workspace  #b58900 #b58900 #002b36
              active_workspace   #586e75 #586e75 #002b36
              inactive_workspace #073642 #002b36 #839496
              urgent_workspace   #dc322f #dc322f #fdf6e3
          }
        }

        #                       border   background  text     indicator
        client.focused          #002b36  #586e75     #fdf6e3  #268bd2
        client.focused_inactive #002b36  #073642     #839496  #073642
        client.unfocused        #002b36  #073642     #839496  #073642
        client.urgent           #002b36  #dc322f     #fdf6e3  #002b36

        # pactl rather than wpctl: it drives both PulseAudio and pipewire-pulse,
        # and Ubuntu's default differs by release.
        bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%
        bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%
        bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle

        bindsym XF86MonBrightnessUp exec ${pkgs.brightnessctl}/bin/brightnessctl set +10%
        bindsym XF86MonBrightnessDown exec ${pkgs.brightnessctl}/bin/brightnessctl set 10%-

        bindsym XF86AudioPlay exec ${pkgs.playerctl}/bin/playerctl play
        bindsym XF86AudioPause exec ${pkgs.playerctl}/bin/playerctl pause
        bindsym XF86AudioNext exec ${pkgs.playerctl}/bin/playerctl next
        bindsym XF86AudioPrev exec ${pkgs.playerctl}/bin/playerctl previous

        focus_follows_mouse no
        hide_edge_borders vertical

        set $setup_background feh --bg-fill ${wallpaper}
        set $lock ${lockScript}

        bindsym mod1+Control+l exec $lock
        exec --no-startup-id "xautolock -time $autolock_minutes -locker $lock"

        bindsym $mod+p exec pavucontrol

        bindsym $mod+Control+Left  move workspace to output left
        bindsym $mod+Control+Right move workspace to output right
        bindsym $mod+Control+Up    move workspace to output up
        bindsym $mod+Control+Down  move workspace to output down

        bindsym $mod+t exec ${xTools.touchpadToggle}/bin/touchpad_toggle $touchpad_name
        bindsym $mod+l exec ${xTools.keymapToggle}/bin/keymap_toggle
        bindsym $mod+m exec ${xTools.setupScreens}/bin/setup_screens mirror && $setup_background

        # Window identifiers come from `xprop`: WM_CLASS(STRING) = "<INSTANCE>", "<CLASS>"
        for_window [title="xzoom 2"] floating enable
        for_window [class="Pavucontrol"] floating enable
        for_window [class="Arandr"] floating enable
        for_window [class="Arandr"] resize set 800 600

        for_window [title="Microsoft Teams Notification" class="microsoft teams - preview"] floating enable
        for_window [title="Microsoft Teams Notification" class="Microsoft Teams - Preview"] floating enable

        exec --no-startup-id "setxkbmap -layout us"

        assign [class="Google-chrome"] $ws2
        assign [class="teams-for-linux"] $ws3
        assign [class="Microsoft Teams - Preview"] $ws3
        assign [class="Slack"] $ws3

        exec --no-startup-id google-chrome
        exec --no-startup-id slack
        exec --no-startup-id teams-for-linux
        exec --no-startup-id i3-msg 'workspace $ws1; exec i3-sensible-terminal'
        exec --no-startup-id i3-msg 'workspace $ws4; exec i3-sensible-terminal; workspace $ws1'

        exec --no-startup-id nm-applet
        exec --no-startup-id blueman-applet
        exec --no-startup-id pasystray

        exec_always ${xTools.setupScreens}/bin/setup_screens
        exec_always --no-startup-id $setup_background
        exec_always --no-startup-id picom --config ${config.xdg.configHome}/picom.conf

        exec_always --no-startup-id xinput set-prop $touchpad_name "libinput Tapping Enabled" 1
        # Natural scrolling, matching the Mac.
        exec_always --no-startup-id xinput set-prop $touchpad_name "libinput Natural Scrolling Enabled" 1
      '';

      "i3/i3blocks.conf".text = ''
        #
        # Icons: http://fontawesome.io/cheatsheet/
        #

        # Blocklet scripts come from Ubuntu's i3blocks package. Verify this
        # path matches the installed version with `dpkg -L i3blocks`.
        command=/usr/share/i3blocks/$BLOCK_NAME
        separator_block_width=25
        markup=none

        [keymap]
        label=
        interval=1
        command=${xTools.getKeymap}/bin/get_keymap

        # Volume changes are applied by the pactl keybindings above; this block
        # only displays the level.
        [volume]
        label=
        instance=Master
        interval=1
        signal=10

        [disk]
        label=
        interval=30

        [iface]
        label=
        interval=10

        [wifi]
        label=
        instance=${machine.wirelessInterface}
        interval=4

        [battery]
        label=⚡
        interval=30

        [time]
        label=
        command=date '+%Y-%m-%d %H:%M'
        interval=1
      '';

      # The lock script locates lock.png and text.png relative to itself, so
      # the whole directory has to be installed together.
      "i3/i3lock-fancy-multimonitor".source = ./i3lock-fancy-multimonitor;

      # pavucontrol is bound to $mod+p above and rewrites this file itself;
      # the committed copy only seeds the window geometry on a fresh machine.
      "pavucontrol.ini".source = ./pavucontrol.ini;
    };
  };
}
