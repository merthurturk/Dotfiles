#!/usr/bin/env bash
#
# Shared sizing helper for the split-* scripts.

AEROSPACE=/opt/homebrew/bin/aerospace
AEROSPACE_CONFIG="$HOME/.aerospace.toml"

# Read an integer gap out of ~/.aerospace.toml, defaulting to 0.
_gap() {
  local v
  v="$(sed -n "s/^$1[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$AEROSPACE_CONFIG" | head -1)"
  echo "${v:-0}"
}

# Visible width of the focused monitor. The aerospace CLI exposes no geometry
# placeholders, so this comes from NSScreen, matched by name.
_focused_monitor_width() {
  local mon
  mon="$($AEROSPACE list-monitors --focused --format '%{monitor-name}')"
  osascript -l JavaScript -e '
function run(argv) {
  ObjC.import("AppKit");
  var want = argv[0], s = $.NSScreen.screens;
  for (var i = 0; i < s.count; i++) {
    var sc = s.objectAtIndex(i);
    if (ObjC.unwrap(sc.localizedName) === want)
      return String(Math.round(sc.visibleFrame.size.width));
  }
  return String(Math.round($.NSScreen.mainScreen.visibleFrame.size.width));
}' "$mon"
}

# find_app_window <app-name> [workspace]
# Prints the first matching window id, or nothing.
#
# Names are compared with punctuation and non-ASCII stripped, because some apps
# carry invisible bidi marks: WhatsApp reports as "\u200eWhatsApp", so a literal
# equality test silently never matches and callers conclude it isn't running.
find_app_window() {
  local app="$1" scope="${2:-}"
  { if [ -n "$scope" ]; then
      $AEROSPACE list-windows --workspace "$scope" --format '%{window-id}|%{app-name}'
    else
      $AEROSPACE list-windows --all --format '%{window-id}|%{app-name}'
    fi
  } | awk -F'|' -v a="$app" '
      function norm(s) { gsub(/[^A-Za-z0-9]/, "", s); return tolower(s) }
      norm($2) == norm(a) { print $1; exit }
    '
}

# split_resize <window-id> <ratio>
# Sizes that window to <ratio> of the two-tile area; its sibling takes the rest.
split_resize() {
  local wid="$1" ratio="$2"
  local outer_l outer_r inner_h mon_w tile_w target n
  outer_l="$(_gap 'gaps\.outer\.left')"
  outer_r="$(_gap 'gaps\.outer\.right')"
  inner_h="$(_gap 'gaps\.inner\.horizontal')"
  mon_w="$(_focused_monitor_width)"

  # Tiles share the row: an outer gap each side, and an inner gap between each
  # adjacent pair. Counting windows keeps this right with 3+ on the workspace,
  # not just the two-window case.
  n="$($AEROSPACE list-windows --workspace focused --count)"
  [ "${n:-0}" -lt 2 ] && n=2
  tile_w=$(( mon_w - outer_l - outer_r - inner_h * (n - 1) ))

  # `resize width` sets the *node* width, which carries half the inner gap, so
  # the visible window lands INNER_H/2 narrower than asked. Measured at several
  # widths and confirmed constant; add it back.
  target="$(awk -v w="$tile_w" -v r="$ratio" -v g="$inner_h" \
                'BEGIN { printf "%d", w * r + 0.5 + g / 2 }')"

  $AEROSPACE resize --window-id "$wid" width "$target"
}
