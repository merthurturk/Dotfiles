#!/usr/bin/env bash
#
# scene.sh <scene> [chrome-profile-name]   open a named layout
# scene.sh close [workspace]               close everything on a scene workspace
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

LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
STATE_FILE="$STATE_DIR/scenes"   # "<workspace>\t<scene name>" per line

# --- scene bookkeeping ----------------------------------------------------
# Remembering which workspaces this script opened is what makes closing safe:
# a scene workspace can be emptied without a prompt, anything else can't.

remember_scene() {   # <workspace> <scene>
  mkdir -p "$STATE_DIR"
  local tmp="$STATE_FILE.tmp"
  [ -f "$STATE_FILE" ] && grep -v "^$1	" "$STATE_FILE" > "$tmp" 2>/dev/null
  printf '%s\t%s\n' "$1" "$2" >> "$tmp"
  mv "$tmp" "$STATE_FILE"
}

forget_scene() {     # <workspace>
  [ -f "$STATE_FILE" ] || return 0
  local tmp="$STATE_FILE.tmp"
  grep -v "^$1	" "$STATE_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$STATE_FILE"
}

scene_of() {         # <workspace> -> scene name, or empty
  [ -f "$STATE_FILE" ] || return 0
  awk -F'\t' -v w="$1" '$1 == w { print $2; exit }' "$STATE_FILE"
}

# --- close ----------------------------------------------------------------

if [ "${1:-}" = "close" ]; then
  shift
  FORCE=0
  if [ "${1:-}" = "--force" ]; then FORCE=1; shift; fi
  WS="${1:-$($AEROSPACE list-workspaces --focused)}"

  NAME="$(scene_of "$WS")"
  if [ -z "$NAME" ] && [ "$FORCE" -eq 0 ]; then
    # Refuse rather than prompt. Defaulting to the focused workspace plus a
    # dismissible dialog is too easy to fire at the wrong target -- focus
    # drifts on its own as apps activate.
    echo "scene: workspace $WS was not opened as a scene; refusing to close it." >&2
    if [ -s "$STATE_FILE" ]; then
      echo "scene: open scenes are:" >&2
      sed 's/^/  workspace /;s/\t/  -> /' "$STATE_FILE" >&2
      echo "scene: close one with  scene.sh close <workspace>" >&2
    else
      echo "scene: no scenes are currently open." >&2
    fi
    echo "scene: use  scene.sh close --force $WS  to close it anyway." >&2
    exit 1
  fi

  WIDS="$($AEROSPACE list-windows --workspace "$WS" --format '%{window-id}')"
  if [ -z "$WIDS" ]; then
    forget_scene "$WS"
    echo "scene: workspace $WS is already empty" >&2
    exit 0
  fi

  printf '%s\n' "$WIDS" | while read -r wid; do
    [ -n "$wid" ] && $AEROSPACE close --window-id "$wid" 2>/dev/null
  done
  forget_scene "$WS"
  exit 0
fi

# --- open -----------------------------------------------------------------

SCENE="${1:-chill}"
PROFILE_NAME="${2:-}"

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

# Note we do NOT switch to $WS first. `open -a` activates Chrome, which moves
# focus; an empty workspace has no window to hold focus, so AeroSpace falls
# back to the previously focused window and the new windows are born on *that*
# workspace instead. So let them open wherever they land and move them by id.

wait_new_window() {   # <sorted list of window ids that existed before>
  local before="$1" new="" i
  for i in $(seq 1 60); do
    sleep 0.25
    new="$(comm -13 <(printf '%s\n' "$before") \
                    <($AEROSPACE list-windows --all --format '%{window-id}' | sort) \
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

# Move main first so it ends up on the left, then reveal the workspace.
$AEROSPACE move-node-to-workspace --window-id "$MAIN_WID" "$WS"
$AEROSPACE move-node-to-workspace --window-id "$SIDE_WID" "$WS"
$AEROSPACE workspace "$WS"
sleep 0.4

split_resize "$MAIN_WID" "$RATIO"
$AEROSPACE focus --window-id "$MAIN_WID" 2>/dev/null || true
remember_scene "$WS" "$SCENE"
