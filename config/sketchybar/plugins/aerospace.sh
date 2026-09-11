#!/usr/bin/env bash
#
# Refreshes every workspace pill in one batched sketchybar call.
#
# A workspace is drawn only when it holds windows or is the focused one, so the
# 31 persistent workspaces declared in ~/.aerospace.toml stay out of the way
# until you actually use them.
#
# A workspace hosting a scene shows the scene's own badge -- its glyph and name
# in the scene's colour -- instead of the usual app icons, since "chill" says
# more than three browser glyphs do.
#
# macOS ships bash 3.2, which has no associative arrays -- string subscripts
# silently collapse to index 0 there, which would merge every letter workspace
# into one bucket. Windows are grouped with awk instead.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/fonts.sh"
# shellcheck source=/dev/null
source "$CONFIG_DIR/plugins/icon_map.sh"

# Hover: only the border changes, leaving the state-driven fill below intact.
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --animate sin 8 --set "$NAME" background.border_color="$BLUE"
  exit 0
fi

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
WINDOWS="$(aerospace list-windows --monitor all --format '%{workspace}|%{app-name}')"

SCENES_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/scenes"
SCENES_JSON="$HOME/.config/aerospace/scenes.json"

# Returns "<glyph>\t<name>\t<BADGE>" for a workspace running a scene.
scene_badge() {
  local ws="$1" name
  [ -f "$SCENES_STATE" ] || return 1
  name="$(awk -F'\t' -v w="$ws" '$1 == w { print $2; exit }' "$SCENES_STATE")"
  [ -n "$name" ] || return 1
  jq -r --arg s "$name" '
    if has($s) then "\(.[$s].icon // "")\t\($s)\t\(.[$s].badge // "BLUE")" else empty end
  ' "$SCENES_JSON" 2>/dev/null
}

args=()
while read -r ws; do
  [ -z "$ws" ] && continue

  scene="$(scene_badge "$ws")"

  if [ -n "$scene" ]; then
    glyph="$(printf '%s' "$scene" | cut -f1)"
    sname="$(printf '%s' "$scene" | cut -f2)"
    badge="$(printf '%s' "$scene" | cut -f3)"
    # Indirect lookup of BADGE_<NAME>_TINT / _DEEP from colors.sh, falling
    # back to the ordinary pill colours for an unknown badge name.
    tint="$WS_OCCUPIED_BG"
    deep="$WS_OCCUPIED_FG"
    eval "tint=\${BADGE_${badge}_TINT:-$tint}"
    eval "deep=\${BADGE_${badge}_DEEP:-$deep}"

    label="$glyph $sname"
    label_font="$FONT_BOLD:13.0"
    draw=on
    label_draw=on
    if [ "$ws" = "$FOCUSED" ]; then
      bg="$deep"; fg="$BASE"; bd="$deep"
    else
      bg="$tint"; fg="$deep"; bd="$deep"
    fi
  else
    icons=""
    while read -r app; do
      [ -z "$app" ] && continue
      __icon_map "$app"
      # icon_result is set by __icon_map, in the sourced icon_map.sh
      # shellcheck disable=SC2154
      icons="${icons}${icon_result}"
    done < <(printf '%s\n' "$WINDOWS" | awk -F'|' -v w="$ws" '$1 == w { print $2 }' | sort -u)

    label="$icons"
    label_font="$APP_FONT"
    [ -n "$icons" ] && label_draw=on || label_draw=off

    if [ "$ws" = "$FOCUSED" ]; then
      bg=$WS_ACTIVE_BG fg=$WS_ACTIVE_FG bd=$WS_ACTIVE_BORDER draw=on
    elif [ -n "$icons" ]; then
      bg=$WS_OCCUPIED_BG fg=$WS_OCCUPIED_FG bd=$WS_OCCUPIED_BORDER draw=on
    else
      bg=$TRANSPARENT fg=$OVERLAY0 bd=$TRANSPARENT draw=off
    fi
  fi

  args+=(--set space."$ws"
    drawing="$draw"
    background.color="$bg"
    background.border_color="$bd"
    icon.color="$fg"
    label.color="$fg"
    label="$label"
    label.font="$label_font"
    label.drawing="$label_draw"
  )
done < <(aerospace list-workspaces --all)

# Animate so the highlight eases between pills instead of snapping.
sketchybar --animate sin 12 "${args[@]}"
