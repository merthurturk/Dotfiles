#!/usr/bin/env bash
#
# macOS Focus indicator.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/focus_lib.sh"

# Hover: only the border changes, so the state-driven fill below is untouched.
# mouse.exited deliberately falls through to the normal repaint, which restores
# the correct border for whatever state the item is in.
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --animate sin 8 --set "$NAME" background.border_color="$BLUE"
  exit 0
fi

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
if [ $? -ne 0 ]; then
  # jq failed -- almost always Assertions.json caught mid-write. Treating that
  # as "no focus" makes the chip flash off and back, so leave it alone instead.
  exit 0
fi

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
