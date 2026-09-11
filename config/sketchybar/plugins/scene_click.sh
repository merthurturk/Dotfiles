#!/usr/bin/env bash
#
# Left click  -> open the chill scene on an empty workspace.
# Right click -> close the scene on the focused workspace.
#
# Closing refuses any workspace the scene script didn't open, so give that
# refusal some visible feedback -- stderr goes nowhere from a bar click.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.config/aerospace/logging.sh"

source "$CONFIG_DIR/colors.sh"

SCENE="$HOME/.config/aerospace/scene.sh"

if [ "$BUTTON" != "right" ]; then
  "$SCENE" chill
  exit 0
fi

if ! "$SCENE" close 2>/dev/null; then
  sketchybar --set scene label="Not a scene" \
                         label.drawing=on \
                         label.color="$MAROON" \
                         label.padding_right=10
  sleep 2
  sketchybar --set scene label.drawing=off
fi
