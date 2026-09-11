#!/usr/bin/env bash
#
# Left click  -> toggle Focus on/off.
# Right click -> open Focus settings.
#
# macOS exposes no CLI for changing Focus; the Shortcuts "Set Focus" action is
# the only supported route. Not every macOS build offers a "Toggle" option in
# that action, so rather than depend on it we read the current state from the
# DND database ourselves and run whichever direction is needed. That keeps the
# user-authored shortcuts to a single action each, with no If/Otherwise logic.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/focus_lib.sh"

open_settings() {
  open "x-apple.systempreferences:com.apple.Focus-Settings.extension" 2>/dev/null \
    || open "x-apple.systempreferences:com.apple.preference.notifications"
}

have_shortcut() { shortcuts list 2>/dev/null | grep -Fxq "$1"; }

# Say which shortcut is missing, on the chip itself, then restore.
hint() {
  sketchybar --set "$NAME" label="Create '$1'" \
                           label.color="$MAROON" \
                           label.drawing=on \
                           background.color="$TRANSPARENT" \
                           background.border_color="$TRANSPARENT"
  sleep 2
  sketchybar --trigger focus_change
  exit 0
}

if [ "$BUTTON" = "right" ]; then
  open_settings
  exit 0
fi

# Directional shortcuts take priority: a shortcut merely *named* "Toggle Focus"
# only really toggles on builds whose Set Focus action offers a Toggle option.
if [ -n "$(focus_active_id)" ]; then
  WANT="Focus Off"
else
  WANT="Focus On"
fi

if have_shortcut "$WANT"; then
  shortcuts run "$WANT" >/dev/null 2>&1
elif have_shortcut "Toggle Focus"; then
  shortcuts run "Toggle Focus" >/dev/null 2>&1
else
  hint "$WANT"
fi

sleep 1
sketchybar --trigger focus_change
