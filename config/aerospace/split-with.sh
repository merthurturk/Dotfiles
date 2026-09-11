#!/usr/bin/env bash
#
# split-with.sh <app-name> [ratio]
#
# Puts <app-name> beside the currently focused window in the focused workspace
# and sets the split, e.g.
#
#     split-with.sh "Google Chrome" 0.6
#
# leaves the window that was focused occupying 0.6 of the tiling width and the
# summoned app the remaining 0.4.
#
# Sizing lives in split-lib.sh, shared with chrome-split.sh.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/split-lib.sh"

APP="${1:?usage: split-with.sh <app-name> [ratio]}"
RATIO="${2:-0.6}"

WS="$($AEROSPACE list-workspaces --focused)"
ORIG_WID="$($AEROSPACE list-windows --focused --format '%{window-id}')"

find_window() {  # $1 = --workspace value, or "--all"
  if [ "$1" = "--all" ]; then
    $AEROSPACE list-windows --all --format '%{window-id}|%{app-name}'
  else
    $AEROSPACE list-windows --workspace "$1" --format '%{window-id}|%{app-name}'
  fi | awk -F'|' -v a="$APP" '$2 == a { print $1; exit }'
}

WID="$(find_window focused)"

if [ -z "$WID" ]; then
  # Already running elsewhere? Pull that window here instead of opening a copy.
  WID="$(find_window --all)"
  if [ -n "$WID" ]; then
    $AEROSPACE move-node-to-workspace --window-id "$WID" "$WS"
  else
    open -a "$APP"
    for _ in $(seq 1 40); do      # up to ~10s for the window to be adopted
      sleep 0.25
      WID="$(find_window focused)"
      [ -n "$WID" ] && break
    done
  fi
fi

if [ -z "$WID" ]; then
  echo "split-with: no window found for '$APP'" >&2
  exit 1
fi
if [ "$WID" = "$ORIG_WID" ]; then
  echo "split-with: '$APP' is already the focused window; nothing to split against" >&2
  exit 1
fi

split_resize "$ORIG_WID" "$RATIO"
