#!/usr/bin/env bash
#
# Shared by every dot capability.
#
# describe() prints the JSON descriptor and exits. Keeping the descriptor next
# to the implementation is the whole point: there is no second place to update,
# so the surface can't drift from what actually runs.

# Consumed by the capability scripts that source this file, which the linter
# cannot see from here.
# shellcheck disable=SC2034
DOT_ROOT="${DOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AEROSPACE=/opt/homebrew/bin/aerospace
# Ghostty's CLI lives inside the app bundle, and is on PATH only for
# interactive shells -- its shell integration puts it there. Anything AeroSpace
# execs gets the [exec] PATH table instead, which does not have it, so the
# launcher would silently fail to reach a binary a terminal finds instantly.
GHOSTTY="$(command -v ghostty 2>/dev/null)"
[ -n "$GHOSTTY" ] || GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
AERO_CONFIG="$HOME/.aerospace.toml"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
SCENES_JSON="$DOT_ROOT/config/aerospace/scenes.json"
SKETCHY="$HOME/.config/sketchybar"

# keybinding <substring of the binding's command> -> "alt-shift-space" or empty
keybinding() {
  grep -E "^[[:space:]]*[a-z0-9-]+ = " "$AERO_CONFIG" 2>/dev/null \
    | grep -F -- "$1" | head -1 \
    | sed -E 's/^[[:space:]]*([a-z0-9-]+) =.*/\1/'
}

# Pretty-print a binding for humans: alt-shift-space -> ⌥⇧space
keysym() {
  [ -n "${1:-}" ] || return 0
  printf '%s' "$1" | sed -e 's/alt-/⌥/g'  -e 's/shift-/⇧/g' \
                         -e 's/ctrl-/⌃/g' -e 's/cmd-/⌘/g'   \
                         -e 's/enter/↩/'  -e 's/backspace/⌫/' \
                         -e 's|backslash|\\|' -e 's/semicolon/;/' \
                         -e 's/slash/\//' -e 's/comma/,/' -e 's/minus/-/' \
                         -e 's/equal/=/'
}

# Append a line to the mutation audit log. Anything that changes system state
# should call this, so an agent's actions are reviewable after the fact.
audit() {
  mkdir -p "$STATE_DIR"
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "${DOT_ACTOR:-user}" "$*" \
    >> "$STATE_DIR/audit.log"
}
