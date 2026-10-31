{
  # Every module is imported on both platforms; each one's `config` body is
  # guarded by its own enable flag, and Nix's laziness means a disabled
  # module's packages are never evaluated. That is what lets the i3 and
  # AeroSpace modules coexist here despite being platform-specific.
  imports = [
    ./aerospace
    ./agents
    ./dunst
    ./i3
    ./machine
    ./picom
    ./rofi
  ];
}
