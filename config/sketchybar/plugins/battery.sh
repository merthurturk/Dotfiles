#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo '\d+%' | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

# A Mac mini or Studio reports no percentage. Exiting without a --set left the
# item in the status bracket, drawing an empty slot and its padding for ever;
# hide it, the way the music chip hides itself.
[ -z "$PERCENTAGE" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

case "${PERCENTAGE}" in
  9[0-9]|100) ICON="󰁹" COLOR=$GREEN  ;;
  [6-8][0-9]) ICON="󰂀" COLOR=$GREEN  ;;
  [3-5][0-9]) ICON="󰁾" COLOR=$YELLOW ;;
  [1-2][0-9]) ICON="󰁻" COLOR=$PEACH  ;;
  *)          ICON="󰁺" COLOR=$RED    ;;
esac

if [ -n "$CHARGING" ]; then
  ICON="󰂄"
  COLOR=$GREEN
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
