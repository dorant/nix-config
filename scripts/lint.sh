#!/usr/bin/env bash
set -eu

# Structural checks that the option system cannot express. Run by
# `nix run .#lint` and by CI.
#
# Loops that would otherwise read from a pipe use a here-string instead: a
# piped `while` body runs in a subshell, where `fail` could not stop the
# script.

status=0

fail() {
  echo "lint: $1" >&2
  status=1
}

# Every module under home/modules must be imported by home/modules/default.nix.
# An unimported module declares its options but contributes nothing, which
# looks identical to one that is merely disabled.
for dir in home/modules/*/; do
  name=$(basename "$dir")
  if ! grep -q "\./$name" home/modules/default.nix; then
    fail "home/modules/$name is not imported by home/modules/default.nix"
  fi
done

# Every module must be switched on by some profile, or it is dead code.
# machine/ declares hardware values rather than a feature, so it has no flag.
for dir in home/modules/*/; do
  name=$(basename "$dir")
  [ "$name" = "machine" ] && continue
  if ! grep -rq "$name\.enable\|$name = {" home/profiles/; then
    fail "no profile enables my.$name"
  fi
done

# Conversely, every enable flag a profile sets must be declared somewhere, so a
# typo fails here rather than at eval. Only the `my` namespace is checked:
# either `my.<name>.enable` or a bare `<name>.enable` inside a `my = { ... }`
# block. Options like targets.genericLinux.enable have their own schema.
#
# A flag either names a module directory (my.i3.enable), or is a sub-option of
# one (my.agents.claude.enable), in which case that module must declare it.
keys=$(grep -rhoE '^[[:space:]]*[A-Za-z0-9_.-]+\.enable[[:space:]]*=' home/profiles/ |
  tr -d ' \t=' | sed 's/\.enable$//' | sort -u)

while read -r key; do
  [ -n "$key" ] || continue
  case "$key" in
  my.*) flag=${key#my.} ;;
  *.*) continue ;;
  *) flag=$key ;;
  esac

  # my.<module>.enable
  if [ -d "home/modules/$flag" ]; then
    continue
  fi

  # my.<module>.<sub>.enable: the module must declare <sub> as an attribute.
  parent=${flag%.*}
  sub=${flag##*.}
  if [ "$parent" != "$flag" ] && [ -d "home/modules/$parent" ]; then
    if grep -qE "^[[:space:]]*$sub = \{" "home/modules/$parent/default.nix"; then
      continue
    fi
    fail "home/modules/$parent declares no '$sub' option"
    continue
  fi

  # A bare flag inside a `my = { ... }` block, where the profile nests the
  # module name one level up (my = { agents = { claude.enable = ...; }; }).
  if grep -rqE "^[[:space:]]*$sub = \{" home/modules/*/default.nix; then
    continue
  fi

  fail "profile enables my.$flag, which is neither a module nor a declared option"
done <<<"$keys"

# Hardware values belong in the machine module's typed options, not inlined
# into a module that both machines share.
if grep -rnE '"(eDP|DP|HDMI)-[0-9]' home/modules/ | grep -v '^home/modules/machine/'; then
  fail "xrandr output name hardcoded outside home/modules/machine"
fi

if grep -rnE 'wlp[0-9]|wlan[0-9]' home/modules/ | grep -v '^home/modules/machine/'; then
  fail "wireless interface hardcoded outside home/modules/machine"
fi

[ "$status" -eq 0 ] && echo "lint: ok"
exit "$status"
