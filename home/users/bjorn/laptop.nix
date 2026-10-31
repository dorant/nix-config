{ ... }:

{
  imports = [ ../../profiles/linux-desktop.nix ];

  # Hardware values for this laptop. Read them with:
  #   xrandr          output names
  #   xinput list     touchpad device name
  #   ip link         wireless interface
  my.machine = {
    # Intel driver. The same panel is eDP-1-1 under the Nvidia driver.
    mainOutput = "eDP-1";
    extraOutput = "DP-3";
    presentationOutput = "DP-1";
    touchpadName = "SYNA2393:00 06CB:7A13 Touchpad";
    wirelessInterface = "wlp59s0";
  };
}
