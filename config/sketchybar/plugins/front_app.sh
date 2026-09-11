#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
# shellcheck source=/dev/null
source "$CONFIG_DIR/plugins/icon_map.sh"

if [ "$SENDER" = "front_app_switched" ]; then
  __icon_map "$INFO"
  # icon_result is set by __icon_map, in the sourced icon_map.sh
  # shellcheck disable=SC2154
  sketchybar --set "$NAME" icon="$icon_result" label="$INFO"
fi
