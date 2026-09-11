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
