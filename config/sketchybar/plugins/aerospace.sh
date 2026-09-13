#!/usr/bin/env bash
#
# Refreshes every workspace pill in one batched sketchybar call.
#
# A workspace is drawn only when it holds windows or is the focused one, so the
# 31 persistent workspaces declared in ~/.aerospace.toml stay out of the way
# until you actually use them. A workspace hosting a scene shows the scene's
# badge -- its glyph and name in its own colour -- instead of app icons.
#
# This runs on every workspace switch, so it is deliberately subprocess-frugal.
# Everything is gathered once, then a single awk pass emits the whole sketchybar
# argument list. An earlier version looped in shell, forking awk and sort per
# workspace: ~70 processes and 270ms, which reads as lag when you switch.
#
# macOS ships bash 3.2, which has no associative arrays -- string subscripts
# silently collapse to index 0 there, which would merge every letter workspace
# into one bucket. All grouping happens in awk.

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

# A split is an absolute width in points, so it is wrong on a different-sized
# display. Restore each scene's declared ratio when the displays change; it
# resizes hidden workspaces in place, so nothing visibly moves.
if [ "$SENDER" = "display_change" ]; then
  ( "$HOME/.local/bin/dot" window reflow >/dev/null 2>&1 & )
fi

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
SCENES_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/scenes"
SCENES_JSON="$HOME/.config/aerospace/scenes.json"

# --- gather once ----------------------------------------------------------

WINDOWS="$(aerospace list-windows --monitor all --format '%{workspace}|%{app-name}' | sort -u)"
WORKSPACES="$(aerospace list-workspaces --all)"

# __icon_map is a shell function, so awk can't call it. Resolve the handful of
# distinct apps here; everything else is awk's job.
APP_GLYPHS=""
while IFS= read -r app; do
  [ -n "$app" ] || continue
  __icon_map "$app"
  # icon_result is set by __icon_map, in the sourced icon_map.sh
  # shellcheck disable=SC2154
  APP_GLYPHS="${APP_GLYPHS}G	${app}	${icon_result}
"
done < <(printf '%s\n' "$WINDOWS" | cut -d'|' -f2- | sort -u)

# scenes.local.json overrides the shipped examples; see config/aerospace/scene.sh
SCENES_LOCAL="$HOME/.config/aerospace/scenes.local.json"
SCENE_DEFS=""
if [ -f "$SCENES_JSON" ]; then
  if [ -f "$SCENES_LOCAL" ]; then
    SCENE_DEFS="$(jq -s -r '.[0] * .[1] |
      to_entries[] | ["D", .key, (.value.icon // ""), (.value.label // .key),
                      (.value.badge // "BLUE")] | @tsv' \
      "$SCENES_JSON" "$SCENES_LOCAL" 2>/dev/null)"
  else
    SCENE_DEFS="$(jq -r '
      to_entries[] | ["D", .key, (.value.icon // ""), (.value.label // .key),
                      (.value.badge // "BLUE")] | @tsv' "$SCENES_JSON" 2>/dev/null)"
  fi
fi

SCENE_STATE=""
[ -f "$SCENES_STATE" ] && SCENE_STATE="$(sed 's/^/S\t/' "$SCENES_STATE")"

# "NAME=tint,edge,deep;…" so awk can look a badge up instead of forking.
BADGES=""
for b in PEACH TEAL MAUVE BLUE GREEN; do
  t=""; e=""; d=""
  eval "t=\${BADGE_${b}_TINT:-}"
  eval "e=\${BADGE_${b}_EDGE:-}"
  eval "d=\${BADGE_${b}_DEEP:-}"
  [ -n "$t" ] && BADGES="${BADGES}${b}=${t},${e},${d};"
done

# --- one pass -------------------------------------------------------------

args=()
while IFS= read -r a; do args+=("$a"); done < <(
  { printf '%s\n' "$APP_GLYPHS"
    printf '%s\n' "$SCENE_DEFS"
    printf '%s\n' "$SCENE_STATE"
    printf '%s\n' "$WINDOWS" | sed 's/^/W\t/;s/|/\t/'
    printf '%s\n' "$WORKSPACES" | sed 's/^/L\t/'
  } | awk -F'\t' \
      -v focused="$FOCUSED" -v badges="$BADGES" \
      -v app_font="$APP_FONT" -v scene_font="$FONT_MEDIUM:12.0" \
      -v a_bg="$WS_ACTIVE_BG" -v a_fg="$WS_ACTIVE_FG" -v a_bd="$WS_ACTIVE_BORDER" \
      -v o_bg="$WS_OCCUPIED_BG" -v o_fg="$WS_OCCUPIED_FG" -v o_bd="$WS_OCCUPIED_BORDER" \
      -v clear="$TRANSPARENT" -v dim="$OVERLAY0" -v base="$BASE" '
    BEGIN {
      n = split(badges, bs, ";")
      for (i = 1; i <= n; i++) {
        if (bs[i] == "") continue
        split(bs[i], kv, "="); split(kv[2], c, ",")
        tint[kv[1]] = c[1]; edge[kv[1]] = c[2]; deep[kv[1]] = c[3]
      }
    }
    $1 == "G" { glyph[$2] = $3; next }
    $1 == "D" { sIcon[$2] = $3; sLabel[$2] = $4; sBadge[$2] = $5; next }
    $1 == "S" { wsScene[$2] = $3; next }
    $1 == "W" { icons[$2] = icons[$2] glyph[$3]; next }

    $1 == "L" {
      ws = $2
      if (ws in wsScene) {
        s  = wsScene[ws]; b = (s in sBadge) ? sBadge[s] : "BLUE"
        tt = (b in tint) ? tint[b] : o_bg
        ee = (b in edge) ? edge[b] : o_bd
        dd = (b in deep) ? deep[b] : o_fg
        label = sIcon[s] " " sLabel[s]
        font = scene_font; pad = 2; draw = "on"; ldraw = "on"
        if (ws == focused) { bg = dd; fg = base; bd = dd }
        else               { bg = tt; fg = dd;   bd = ee }
      } else {
        label = icons[ws]; font = app_font; pad = 4
        ldraw = (label == "") ? "off" : "on"
        if (ws == focused)   { bg = a_bg; fg = a_fg; bd = a_bd; draw = "on" }
        else if (label != "") { bg = o_bg; fg = o_fg; bd = o_bd; draw = "on" }
        else                  { bg = clear; fg = dim; bd = clear; draw = "off" }
      }
      print "--set"; print "space." ws
      print "drawing=" draw
      print "background.color=" bg
      print "background.border_color=" bd
      print "icon.color=" fg
      print "label.color=" fg
      print "label=" label
      print "label.font=" font
      print "label.padding_left=" pad
      print "label.drawing=" ldraw
    }'
)

sketchybar --animate sin 8 "${args[@]}"
