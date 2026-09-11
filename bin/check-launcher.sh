#!/usr/bin/env bash
#
# Verifies the launcher is still the complete entry point.
#
# alt-space is the single discovery surface for this setup, so anything a key
# or a bar button can do must also be reachable from it. This fails if a
# binding or click script has no corresponding launcher entry.
#
# Run after adding or removing any action.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$REPO/config/aerospace/launcher.sh"
TOML="$REPO/aerospace.toml"
BARRC="$REPO/config/sketchybar/sketchybarrc"

# Scripts the launcher legitimately doesn't list:
#   launcher.sh  can't launch itself
#   mode.sh      internal, fired by binding-mode changes
EXEMPT="launcher.sh mode.sh"

MENU="$("$LAUNCHER" --dry-run 2>/dev/null)"
if [ -z "$MENU" ]; then
  echo "FAIL: launcher --dry-run produced nothing" >&2
  exit 1
fi

fail=0
checked=0

# AeroSpace bindings that call our own scripts. Commented-out lines are skipped
# by requiring the line to start with the key name.
BINDINGS="$(grep -E "^[[:space:]]*[a-z0-9-]+ = 'exec-and-forget \\\$HOME/\.config/aerospace/" "$TOML" \
            | sed -E "s|.*/\.config/aerospace/||; s|'.*||")"

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  script="$(printf '%s' "$cmd" | awk '{print $1}')"
  arg="$(printf '%s' "$cmd" | awk '{print $2}')"

  case " $EXEMPT " in *" $script "*) continue ;; esac
  checked=$((checked + 1))

  if [ -n "$arg" ]; then
    pattern="$script.*$arg"
  else
    pattern="$script"
  fi

  # Check the rendered menu first, then the launcher source: some entries are
  # state-dependent (a Close only renders while a scene is open), and the
  # failure this guards against is "added a binding, never touched launcher.sh".
  if ! printf '%s\n' "$MENU" | grep -q -- "$pattern" \
     && ! grep -q -- "$pattern" "$LAUNCHER"; then
    echo "MISSING from launcher: $cmd   (aerospace.toml)" >&2
    fail=1
  fi
done <<EOF
$BINDINGS
EOF

# Bar buttons with a click handler: each fronts a feature the launcher must
# also expose. scene_click.sh -> "scene", focus_click.sh -> "focus", etc.
while IFS= read -r plugin; do
  [ -n "$plugin" ] || continue
  checked=$((checked + 1))
  feature="$(printf '%s' "$plugin" | sed 's/_click\.sh$//')"
  if ! printf '%s\n' "$MENU" | grep -qi -- "$feature" \
     && ! grep -qi -- "$feature" "$LAUNCHER"; then
    echo "MISSING from launcher: $plugin   (sketchybarrc click_script)" >&2
    fail=1
  fi
done <<EOF
$(grep -oE '[a-z_]+_click\.sh' "$BARRC" | sort -u)
EOF

if [ "$fail" -eq 0 ]; then
  echo "ok: $checked entry point(s) all reachable from the launcher"
else
  {
    echo ""
    echo "Add the missing action to config/aerospace/launcher.sh:"
    echo '  add "<label>" "<detail: its keybinding>" "<command>"'
  } >&2
fi
exit "$fail"
