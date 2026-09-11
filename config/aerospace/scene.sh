#!/usr/bin/env bash
#
# scene.sh [scene] [chrome-profile-name]
#
# Opens a named window layout on a fresh, empty workspace: a wide "main" Chrome
# window holding several tabs, and a narrow "side" window beside it.
#
# The side window is opened with Chrome's --app flag, which drops the tab strip
# and toolbar -- what you want for a chat panel that has to live in ~500pt.
#
# Add a scene by adding a case below.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/split-lib.sh"

SCENE="${1:-chill}"
PROFILE_NAME="${2:-}"
LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"

case "$SCENE" in
  chill)
    MAIN_URLS=(https://www.youtube.com https://x.com https://www.instagram.com)
    SIDE_URL="https://app.contextengine.com/chat"
    RATIO=0.70
    ;;
  *)
    echo "scene: unknown scene '$SCENE'" >&2
    exit 1
    ;;
esac

# Resolve the Chrome profile directory from its display name, else use Default.
PROFILE_DIR=""
if [ -n "$PROFILE_NAME" ]; then
  PROFILE_DIR="$(jq -r --arg n "$PROFILE_NAME" '
    .profile.info_cache | to_entries[] | select(.value.name == $n) | .key
  ' "$LOCAL_STATE" 2>/dev/null | head -1)"
fi
PROFILE_DIR="${PROFILE_DIR:-Default}"

# A scene wants a clean workspace, not whatever is already open.
WS="$($AEROSPACE list-workspaces --monitor all --empty | head -1)"
if [ -z "$WS" ]; then
  echo "scene: no empty workspace available" >&2
  exit 1
fi
$AEROSPACE workspace "$WS"
sleep 0.3

# Waits for a window to appear on the focused workspace that wasn't in $1.
wait_new_window() {
  local before="$1" new=""
  local i
  for i in $(seq 1 60); do
    sleep 0.25
    new="$(comm -13 <(printf '%s\n' "$before") \
                    <($AEROSPACE list-windows --workspace focused --format '%{window-id}' | sort) \
           | head -1)"
    [ -n "$new" ] && break
  done
  printf '%s' "$new"
}

snapshot() { $AEROSPACE list-windows --all --format '%{window-id}' | sort; }

BEFORE="$(snapshot)"
open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" \
     --new-window "${MAIN_URLS[@]}"
MAIN_WID="$(wait_new_window "$BEFORE")"
if [ -z "$MAIN_WID" ]; then
  echo "scene: main window never appeared" >&2
  exit 1
fi

BEFORE="$(snapshot)"
open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" \
     --app="$SIDE_URL"
SIDE_WID="$(wait_new_window "$BEFORE")"
if [ -z "$SIDE_WID" ]; then
  echo "scene: side window never appeared" >&2
  exit 1
fi

split_resize "$MAIN_WID" "$RATIO"
$AEROSPACE focus --window-id "$MAIN_WID" 2>/dev/null || true
