{
  pkgs,
  lib,
  machine,
}:

let
  # Binaries that must come from the Ubuntu system rather than nixpkgs: they
  # talk to the distro's X server or its GPU drivers, and a nixpkgs build
  # would need nixGL wrapping and break on driver upgrades. Symlinked into a
  # derivation so the scripts below can put them on PATH by store path.
  xClients = pkgs.runCommand "system-x-clients" { } ''
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (n: "ln -s /usr/bin/${n} $out/bin/${n}") [
      "xinput"
      "xrandr"
      "setxkbmap"
      "notify-send"
    ]}
  '';

  # Prepended, not replaced, so runtimeInputs still resolve.
  useSystemX = ''
    PATH="${xClients}/bin:$PATH"
  '';
in
{
  keymapToggle = pkgs.writeShellApplication {
    name = "keymap_toggle";
    runtimeInputs = [ pkgs.gawk ];
    text = ''
      ${useSystemX}
      CURRENT=$(setxkbmap -query | awk '
          BEGIN{layout=""}
          /^layout/{layout=$2}
          END{printf("%s",layout)}')

      if [ "$CURRENT" = "us" ]; then
          setxkbmap se
          notify-send -u low "Keymap set to: Swedish"
      else
          setxkbmap us
          notify-send -u low "Keymap set to: English"
      fi
    '';
  };

  getKeymap = pkgs.writeShellApplication {
    name = "get_keymap";
    runtimeInputs = [ pkgs.gawk ];
    text = ''
      ${useSystemX}
      setxkbmap -query | awk '
          BEGIN{layout="";variant=""}
          /^layout/{layout=$2}
          /^variant/{variant=" ("$2")"}
          END{printf("%s%s",layout,variant)}'
    '';
  };

  touchpadToggle = pkgs.writeShellApplication {
    name = "touchpad_toggle";
    runtimeInputs = with pkgs; [
      gawk
      gnugrep
    ];
    text = ''
      ${useSystemX}
      NAME="''${1:-${machine.touchpadName}}"

      # NAME is braced below because a bare $NAME followed by '[' reads as an
      # array subscript (shellcheck SC1087).
      ID=$(xinput list \
          | grep 'ouchpad' \
          | grep -E "''${NAME}[[:space:]]+id=[0-9]{1,2}" \
          | grep -Eo 'id=[0-9]{1,2}' \
          | grep -Eo '[0-9]{1,2}') || true

      if [ -z "$ID" ]; then
          notify-send -u low "Failed to toggle touchpad" "No device matching '$NAME'"
          exit 1
      fi

      STATE=$(xinput list-props "$ID" | grep 'Device Enabled' | awk '{print $4}')

      if [ "$STATE" -eq 1 ]; then
          xinput disable "$ID"
          notify-send -u low "Touchpad disabled"
      else
          xinput enable "$ID"
          notify-send -u low "Touchpad enabled"
      fi
    '';
  };

  # Selects exactly one external-display arrangement: the presentation output
  # wins over the extra output, and with neither connected the laptop panel is
  # the only active one. `mirror` stacks the external onto the panel instead of
  # placing it above.
  setupScreens = pkgs.writeShellApplication {
    name = "setup_screens";
    runtimeInputs = [ pkgs.gnugrep ];
    text = ''
      ${useSystemX}
      PRIMARY="${machine.mainOutput}"
      EXTRA="${machine.extraOutput}"
      PRESENTATION="${machine.presentationOutput}"
      PRESENTATION_SIZE="1920x1080"

      PRESENTATION_POSITION="--above"
      EXTRA_POSITION="--above"
      EXTRA_SIZE="--auto"
      if [ "''${1:-}" = "mirror" ]; then
          notify-send -u low "Screen mirror"
          PRESENTATION_POSITION="--same-as"
          EXTRA_POSITION="--same-as"
          EXTRA_SIZE="--mode 1920x1080"
      fi

      if xrandr | grep -q "$PRESENTATION connected"; then
          xrandr --output "$EXTRA" --off
          xrandr --output "$PRESENTATION" --auto
          xrandr --output "$PRIMARY" --primary --auto \
                 --output "$PRESENTATION" --mode "$PRESENTATION_SIZE" \
                 "$PRESENTATION_POSITION" "$PRIMARY"
          notify-send -u low "presentation screen enabled ($PRESENTATION)"

      elif xrandr | grep -q "$EXTRA connected"; then
          xrandr --output "$PRESENTATION" --off
          # shellcheck disable=SC2086 # EXTRA_SIZE carries an option and its value
          xrandr --output "$PRIMARY" --primary --auto \
                 --output "$EXTRA" $EXTRA_SIZE "$EXTRA_POSITION" "$PRIMARY"
          notify-send -u low "second screen enabled ($EXTRA)"

      else
          if ! xrandr | grep -q "$PRIMARY connected"; then
             echo "Error! Primary screen not found: $PRIMARY" >&2
          fi
          xrandr --output "$EXTRA" --off
          xrandr --output "$PRESENTATION" --off
          xrandr --output "$PRIMARY" --primary --auto
          notify-send -u low "second screen(s) disabled"
      fi
    '';
  };
}
