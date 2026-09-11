#!/usr/bin/env bash
#
# macOS Focus indicator.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/focus_lib.sh"

BELL="󰂚"

if ! focus_db_readable; then
  sketchybar --set "$NAME" icon="$BELL" icon.color="$MAROON" \
                           label="Grant FDA" label.color="$MAROON" \
                           label.drawing=on \
                           background.color="$TRANSPARENT" \
                           background.border_color="$TRANSPARENT"
  exit 0
fi

ACTIVE="$(focus_active_id)"

# Publish the state for processes without Full Disk Access. Only sketchybar is
# granted FDA, so anything else (the launcher, run via AeroSpace) can't read
# the DND database itself and reads this instead.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
mkdir -p "$STATE_DIR"
if [ -n "$ACTIVE" ]; then
  printf '%s\t%s\n' "$ACTIVE" "$(focus_name_for "$ACTIVE")" > "$STATE_DIR/focus"
else
  : > "$STATE_DIR/focus"
fi

# Icon only: the per-mode glyph says *which* Focus is on, and the filled pill
# says *that* one is on, so the mode name would just be repeating itself.
if [ -n "$ACTIVE" ]; then
  sketchybar --set "$NAME" icon="$(focus_glyph "$ACTIVE")" \
                           icon.color="$WS_ACTIVE_FG" \
                           label.drawing=off \
                           background.color="$MAUVE" \
                           background.border_color="$MAUVE"
else
  # Focus off: stay quiet, just a dim bell.
  sketchybar --set "$NAME" icon="$BELL" \
                           icon.color="$OVERLAY1" \
                           label.drawing=off \
                           background.color="$TRANSPARENT" \
                           background.border_color="$TRANSPARENT"
fi
