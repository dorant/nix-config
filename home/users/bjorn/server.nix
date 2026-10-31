{ ... }:

{
  # stack1 through stack3 are identical headless servers, so they share this
  # one configuration, applied to each via the `stack` flake output. There are
  # no per-host hardware values to set (no displays, no touchpad), unlike the
  # laptop.
  imports = [ ../../profiles/server.nix ];
}
