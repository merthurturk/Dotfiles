#!/usr/bin/env bash
#
# Shared sizing helper for the split-* scripts.

# Respect an already-resolved value; see libexec/dot/_lib.sh.
: "${AEROSPACE:=$(command -v aerospace 2>/dev/null || echo /opt/homebrew/bin/aerospace)}"
AEROSPACE_CONFIG="$HOME/.aerospace.toml"

# Read an integer gap out of ~/.aerospace.toml, defaulting to 0.
# The three gaps a split needs, read in one pass. Each used to be its own
# sed+head over the same file: six forks for three numbers.
_GAPS=""
_gap() {
  [ -n "$_GAPS" ] || _GAPS="$(sed -n \
    -e 's/^gaps\.outer\.left[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/outer_left \1/p' \
    -e 's/^gaps\.outer\.right[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/outer_right \1/p' \
    -e 's/^gaps\.inner\.horizontal[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/inner_horizontal \1/p' \
    "$AEROSPACE_CONFIG" 2>/dev/null)"
  local v
  v="$(printf '%s\n' "$_GAPS" | awk -v k="$1" '$1 == k { print $2; exit }')"
  echo "${v:-0}"
}

# Visible width of the focused monitor. The aerospace CLI exposes no geometry
# placeholders, so this comes from NSScreen, matched by name.
# _monitor_width_for [monitor-name]
# Width of that monitor; the focused one when the name is empty.
#
# The caller passes the name because it already knows it: split_resize reads
# the window's monitor, workspace and neighbour count out of one enumeration.
# Looking the monitor up again in here was a second round-trip over the same
# list. Taking the *focused* monitor instead would be wrong whenever the window
# being sized is on a workspace you are not looking at -- which is exactly what
# reflow does.
_monitor_width_for() {
  local mon cache
  mon="${1:-}"
  [ -n "$mon" ] || mon="$($AEROSPACE list-monitors --focused --format '%{monitor-name}')"

  # Asking AppKit costs ~180ms, and this sits on the visible path of every
  # split. A monitor's width doesn't change while it's plugged in, so cache it
  # per monitor; display_change clears the directory.
  cache="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/monitor-width"
  mkdir -p "$cache"
  local file="$cache/${mon//[^A-Za-z0-9]/_}"
  # -s, not -r: an osascript that returned nothing still created the file, and
  # every later read then produced an empty width -- which makes tile_w
  # negative and hands a nonsense target to `aerospace resize`.
  if [ -s "$file" ]; then cat "$file"; return 0; fi

  local w
  w="$(osascript -l JavaScript -e '
function run(argv) {
  ObjC.import("AppKit");
  var want = argv[0], s = $.NSScreen.screens;
  for (var i = 0; i < s.count; i++) {
    var sc = s.objectAtIndex(i);
    if (ObjC.unwrap(sc.localizedName) === want)
      return String(Math.round(sc.visibleFrame.size.width));
  }
  return String(Math.round($.NSScreen.mainScreen.visibleFrame.size.width));
}' "$mon")"
  # Only cache a real answer, for the same reason.
  [ -n "$w" ] && printf '%s' "$w" > "$file"
  printf '%s' "$w"
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

# --- opening and placing a window ------------------------------------------
#
# scene.sh, chrome-split.sh and `dot ai` all do the same three things: note
# which windows exist, launch something, then put the window that appears where
# it belongs. Each had its own copy, and the focus race in it was fixed three
# separate times. One copy now.

# Snapshot of every window id, sorted, for wait_for_new_window to diff against.
snapshot_windows() { $AEROSPACE list-windows --all --format '%{window-id}' | sort; }

# wait_for_new_window <snapshot> [timeout-quarter-seconds]
# Prints the id of the first window that appeared since the snapshot.
#
# Looks everywhere, not just the focused workspace: activating an app moves
# focus, and the new window does not reliably land where you were.
# The poll interval is the latency you feel: the window is typically ready well
# before the next tick, so a quarter second was up to 250ms of dead time per
# window. 20ms costs nothing measurable and reads as instant.
wait_for_new_window() {
  local before="$1" limit="${2:-750}" new="" i
  for ((i = 0; i < limit; i++)); do
    sleep 0.02
    new="$(comm -13 <(printf '%s\n' "$before") <(snapshot_windows) | head -1)"
    [ -n "$new" ] && break
  done
  printf '%s' "$new"
}

# place_window <window-id> <workspace>
# Moves it there and asserts a tiled layout. `resize` refuses both floating
# windows and an accordion root, and an app can open one floating without
# warning; both calls are no-ops when already true.
# One `eval` rather than three calls: each round-trip is ~40ms and each triggers
# its own relayout, which is what makes a window visibly shuffle into place.
place_window() {
  $AEROSPACE eval "move-node-to-workspace --window-id $1 $2; \
                   layout tiling --window-id $1; \
                   layout tiles --window-id $1" >/dev/null 2>&1 || true
}

# split_resize <window-id> <ratio>
# Sizes that window to <ratio> of the two-tile area; its sibling takes the rest.
# _split_widths <window-id> <ratio>  ->  "<node width> <visible width>"
#
# Two different numbers, and confusing them is easy: `resize width` sets the
# *node* width, which carries half the inner gap, so the window you can see
# ends up INNER_H/2 narrower than the number you asked for. Ask for 1013 and
# measure 1008.
#
# split_resize wants the first. `dot window reflow --arrived`, which compares
# against what `dot window geometry` measured, wants the second -- comparing
# the two is how the first version of that check decided a correct split was
# 5pt wrong and resized it on every arrival.
_split_widths() {
  local wid="$1" ratio="$2"
  local outer_l outer_r inner_h mon mon_w tile_w n row

  # One enumeration, three answers. This used to ask AeroSpace separately for
  # the window's monitor, its workspace, and that workspace's window count --
  # three round-trips (~57ms) for one row of one list.
  row="$($AEROSPACE list-windows --all \
           --format '%{window-id}|%{workspace}|%{monitor-name}' 2>/dev/null \
         | awk -F'|' -v w="$wid" '
             $1 == w { ws = $2; mon = $3 }
             { count[$2]++ }
             END { if (ws != "") print ws "|" mon "|" count[ws] }')"
  [ -n "$row" ] || return 1
  n="${row##*|}"; mon="${row%|*}"; mon="${mon#*|}"

  outer_l="$(_gap outer_left)"
  outer_r="$(_gap outer_right)"
  inner_h="$(_gap inner_horizontal)"
  mon_w="$(_monitor_width_for "$mon")"

  # Tiles share the row: an outer gap each side, and an inner gap between each
  # adjacent pair. Counting windows keeps this right with 3+ on the workspace,
  # not just the two-window case.
  [ "${n:-0}" -lt 2 ] && n=2
  tile_w=$(( mon_w - outer_l - outer_r - inner_h * (n - 1) ))

  awk -v w="$tile_w" -v r="$ratio" -v g="$inner_h" \
      'BEGIN { printf "%d %d", w * r + 0.5 + g / 2, w * r + 0.5 }'
}

split_target()   { local x; x="$(_split_widths "$@")" || return 1; printf '%s' "${x%% *}"; }
split_expected() { local x; x="$(_split_widths "$@")" || return 1; printf '%s' "${x##* }"; }

split_resize() {
  local wid="$1" ratio="$2" target
  target="$(split_target "$wid" "$ratio")" || return 1

  # `resize` refuses floating windows (AeroSpace issue #9), and an app can open
  # one floating without warning. It also refuses when the workspace has drifted
  # into an accordion root, which has happened twice here without anyone asking
  # for it. A split is by definition a tiles layout, so assert both -- each is a
  # no-op when already true, and both fit in one round-trip.
  $AEROSPACE eval "layout --window-id $wid tiling; layout --window-id $wid tiles" \
    >/dev/null 2>&1 || true

  if ! $AEROSPACE resize --window-id "$wid" width "$target" 2>/dev/null; then
    echo "split: couldn't resize window $wid -- it may be alone on its workspace" >&2
    return 1
  fi
}
