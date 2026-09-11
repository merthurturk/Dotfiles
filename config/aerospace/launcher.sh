#!/usr/bin/env bash
#
# A command palette for the whole setup. One shortcut, every action, with its
# keybinding shown alongside -- so it doubles as the place to rediscover
# bindings you've forgotten.
#
# Entries are built fresh each run, so they reflect current state: Focus shows
# on or off, only open scenes offer a Close, only occupied workspaces are
# listed.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/logging.sh"
AEROSPACE=/opt/homebrew/bin/aerospace
SKETCHY_DIR="$HOME/.config/sketchybar"
PICKER="$DIR/bin/picker"

MENU="$(mktemp)"
trap 'rm -f "$MENU"' EXIT

# add <label> <detail> <command>
add() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$MENU"; }

# keyhint <substring of a binding's command> -> "⌥⇧space", or empty
#
# Read out of aerospace.toml rather than hardcoded, so a hint can never drift
# from the binding it describes -- and actions with no binding honestly show
# none instead of borrowing a neighbour's.
keyhint() {
  local key
  key="$(grep -E "^[[:space:]]*[a-z0-9-]+ = " "$HOME/.aerospace.toml" \
         | grep -F -- "$1" | head -1 \
         | sed -E 's/^[[:space:]]*([a-z0-9-]+) =.*/\1/')"
  [ -n "$key" ] || return 0
  printf '%s' "$key" | sed -e 's/alt-/⌥/g'  -e 's/shift-/⇧/g' \
                           -e 's/ctrl-/⌃/g' -e 's/cmd-/⌘/g'   \
                           -e 's/enter/↩/'  -e 's/backspace/⌫/' \
                           -e 's/backslash/\\/' -e 's/semicolon/;/' \
                           -e 's/slash/\//' -e 's/comma/,/' -e 's/minus/-/' \
                           -e 's/equal/=/'
}

# --- scenes ---------------------------------------------------------------

# Detail is the scene's keybinding if it has one, else a summary of its windows,
# so an unbound scene still says what it does instead of showing nothing.
while IFS=$'\t' read -r scene summary; do
  [ -n "${scene:-}" ] || continue
  hint="$(keyhint "scene.sh $scene")"
  add "Open scene: $scene" "${hint:-$summary}" "'$DIR/scene.sh' '$scene'"
done < <("$DIR/scene.sh" --describe)

while IFS=$'\t' read -r ws name; do
  [ -n "${ws:-}" ] || continue
  add "Close scene: $name" "workspace $ws" "'$DIR/scene.sh' close '$ws'"
done < <("$DIR/scene.sh" --open-scenes)

# --- focus ----------------------------------------------------------------

# Focus state is published by the sketchybar plugin -- it's the only process
# with Full Disk Access to the TCC-protected DND database, and this script runs
# under AeroSpace, which has none.
FOCUS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/focus"
run_focus="CONFIG_DIR='$SKETCHY_DIR' NAME=focus BUTTON=left '$SKETCHY_DIR/plugins/focus_click.sh'"

if [ -f "$FOCUS_STATE" ]; then
  focus_name="$(cut -f2 "$FOCUS_STATE")"
  if [ -n "$focus_name" ]; then
    add "Focus: turn off" "$focus_name is on" "$run_focus"
  else
    add "Focus: turn on" "Do Not Disturb" "$run_focus"
  fi
  add "Focus settings" "right-click the bar chip" \
      "open 'x-apple.systempreferences:com.apple.Focus-Settings.extension'"
fi

# --- windows --------------------------------------------------------------

add "Chrome beside this window" "$(keyhint chrome-split.sh)" "'$DIR/chrome-split.sh' 0.6"
add "Balance window sizes"      "$(keyhint balance-sizes)"   "$AEROSPACE balance-sizes"
add "Reset workspace layout"    "⌥⇧; then r" "$AEROSPACE flatten-workspace-tree"
add "Toggle floating / tiling"  "⌥⇧; then f" "$AEROSPACE layout floating tiling"
add "Toggle fullscreen"         ""      "$AEROSPACE fullscreen"
add "Close focused window"      ""      "$AEROSPACE close"

# --- workspaces -----------------------------------------------------------

current="$($AEROSPACE list-workspaces --focused)"
while read -r ws; do
  [ -n "$ws" ] && [ "$ws" != "$current" ] || continue
  apps="$($AEROSPACE list-windows --workspace "$ws" --format '%{app-name}' \
          | sort -u | paste -sd ', ' -)"
  add "Go to workspace $ws" "$apps" "$AEROSPACE workspace '$ws'"
done < <($AEROSPACE list-workspaces --monitor all --empty no)

# --- music ----------------------------------------------------------------

if pgrep -x Music >/dev/null 2>&1; then
  now="$(osascript -e 'tell application "Music"
    if player state is playing or player state is paused then
      return (artist of current track) & " — " & (name of current track)
    end if
  end tell' 2>/dev/null)"
  add "Focus Music" "${now:-Apple Music}" "'$SKETCHY_DIR/plugins/music_click.sh'"
fi

# --- system ---------------------------------------------------------------

add "Reload AeroSpace config" "" "$AEROSPACE reload-config"
add "Reload SketchyBar"       "" "sketchybar --reload"

# --- pick and run ---------------------------------------------------------

# --dry-run prints the menu instead of showing the picker; handy for debugging
# and for checking the state-dependent entries without a GUI.
if [ "${1:-}" = "--dry-run" ]; then
  awk -F'\t' '{ printf "%-34s %-28s %s\n", $1, $2, $3 }' "$MENU"
  exit 0
fi

if [ ! -x "$PICKER" ]; then
  echo "launcher: picker not built - run install.sh" >&2
  exit 1
fi

CHOICE="$(cut -f1,2 "$MENU" \
  | PICKER_PROMPT="What do you want to do?" PICKER_CONTEXT=launcher "$PICKER")"
[ -z "$CHOICE" ] && exit 0

CMD="$(awk -F'\t' -v c="$CHOICE" '$1 == c { print $3; exit }' "$MENU")"
[ -z "$CMD" ] && exit 1

eval "$CMD"
