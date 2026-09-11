#!/usr/bin/env bash
#
# Refreshes every workspace pill in one batched sketchybar call.
#
# A workspace is drawn only when it holds windows or is the focused one, so the
# 31 persistent workspaces declared in ~/.aerospace.toml stay out of the way
# until you actually use them.
#
# macOS ships bash 3.2, which has no associative arrays -- string subscripts
# silently collapse to index 0 there, which would merge every letter workspace
# into one bucket. Windows are grouped with awk instead.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"
# shellcheck source=/dev/null
source "$CONFIG_DIR/plugins/icon_map.sh"

# exec-on-workspace-change hands us the focused workspace; fall back to a query
# for the event sources that don't (front_app_switched, forced updates).
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

WINDOWS="$(aerospace list-windows --monitor all --format '%{workspace}|%{app-name}')"

args=()
while read -r ws; do
  [ -z "$ws" ] && continue

  icons=""
  while read -r app; do
    [ -z "$app" ] && continue
    __icon_map "$app"
    # icon_result is set by __icon_map, in the sourced icon_map.sh
    # shellcheck disable=SC2154
    icons="${icons}${icon_result}"
  done < <(printf '%s\n' "$WINDOWS" | awk -F'|' -v w="$ws" '$1 == w { print $2 }' | sort -u)

  if [ "$ws" = "$FOCUSED" ]; then
    bg=$WS_ACTIVE_BG fg=$WS_ACTIVE_FG bd=$WS_ACTIVE_BORDER draw=on
  elif [ -n "$icons" ]; then
    bg=$WS_OCCUPIED_BG fg=$WS_OCCUPIED_FG bd=$WS_OCCUPIED_BORDER draw=on
  else
    bg=$TRANSPARENT fg=$OVERLAY0 bd=$TRANSPARENT draw=off
  fi

  [ -n "$icons" ] && label_draw=on || label_draw=off

  args+=(--set space."$ws"
    drawing="$draw"
    background.color="$bg"
    background.border_color="$bd"
    icon.color="$fg"
    label.color="$fg"
    label="$icons"
    label.drawing="$label_draw"
  )
done < <(aerospace list-workspaces --all)

# Animate so the highlight eases between pills instead of snapping.
sketchybar --animate sin 12 "${args[@]}"
