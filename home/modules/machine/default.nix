{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  # Hardware-specific values that used to be hand-edited in i3/config and
  # i3/setup_screens.sh on every install. Declared as typed options so an
  # unset or misspelled one fails at eval with a clear message, rather than
  # silently interpolating an empty string into a config file.
  options.my.machine = {
    mainOutput = mkOption {
      type = types.str;
      example = "eDP-1";
      description = ''
        xrandr name of the built-in panel. Carries the tray, and is the
        primary output in every arrangement. Differs between the Intel and
        Nvidia drivers on the same laptop (eDP-1 vs eDP-1-1).
      '';
    };

    extraOutput = mkOption {
      type = types.str;
      example = "DP-3";
      description = "xrandr name of the everyday external monitor.";
    };

    presentationOutput = mkOption {
      type = types.str;
      example = "DP-1-1";
      description = ''
        xrandr name of the USB-C/projector output. Takes precedence over
        extraOutput when both are connected.
      '';
    };

    touchpadName = mkOption {
      type = types.str;
      example = "SYNA2393:00 06CB:7A13 Touchpad";
      description = ''
        Device name as reported by `xinput list`. Matched as a substring, so
        it must be exact enough to select one device.
      '';
    };

    wirelessInterface = mkOption {
      type = types.str;
      example = "wlp2s0";
      description = "Interface name from `ip link`, for the status bar.";
    };
  };
}
