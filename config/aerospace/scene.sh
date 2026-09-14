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
source "$DIR/logging.sh"
source "$DIR/split-lib.sh"

LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
STATE_FILE="$STATE_DIR/scenes"   # "<workspace>\t<scene name>" per line

# --- scene bookkeeping ----------------------------------------------------
# Remembering which workspaces this script opened is what makes closing safe:
# a scene workspace can be emptied without a prompt, anything else can't.

# remember_scene <workspace> <scene> <window-id>...
#
# The window ids matter. An earlier version recorded only the workspace, and
# pruned an entry only once that workspace was completely empty -- so if the
# scene's own windows were gone but you had since put your own there, the entry
# survived and `close` destroyed them. That happened. Recording the ids means
# close only ever touches windows the scene actually opened.
remember_scene() {
  mkdir -p "$STATE_DIR"
  prune_scenes
  local ws="$1" name="$2"; shift 2
  local ids; ids="$(printf '%s,' "$@")"; ids="${ids%,}"
  local tmp="$STATE_FILE.tmp"
  [ -f "$STATE_FILE" ] && grep -v "^$ws	" "$STATE_FILE" > "$tmp" 2>/dev/null
  printf '%s\t%s\t%s\n' "$ws" "$name" "$ids" >> "$tmp"
  [ -f "$tmp" ] && mv "$tmp" "$STATE_FILE"
}

# Window ids a scene opened that are still open.
scene_live_windows() {   # <workspace>
  local ws="$1" name ids alive="" id
  IFS=$'\t' read -r _ name ids < <(awk -F'\t' -v w="$ws" '$1==w{print;exit}' "$STATE_FILE" 2>/dev/null)
  [ -n "${ids:-}" ] || return 0
  local existing; existing="$($AEROSPACE list-windows --all --format '%{window-id}')"
  for id in ${ids//,/ }; do
    printf '%s\n' "$existing" | grep -qx "$id" && alive="$alive $id"
  done
  printf '%s' "${alive# }"
}

forget_scene() {     # <workspace>
  [ -f "$STATE_FILE" ] || return 0
  local tmp="$STATE_FILE.tmp"
  grep -v "^$1	" "$STATE_FILE" > "$tmp" 2>/dev/null || true
  [ -f "$tmp" ] && mv "$tmp" "$STATE_FILE"
}

# Drops entries whose windows are all gone.
#
# Keyed on the scene's *own* windows, not on the workspace having anything at
# all: an entry that outlives its windows is how `close` ends up destroying
# whatever you have since put there.
prune_scenes() {
  [ -f "$STATE_FILE" ] || return 0
  local tmp="$STATE_FILE.tmp" ws name ids
  : > "$tmp"
  while IFS=$'\t' read -r ws name ids; do
    [ -n "${ws:-}" ] || continue
    [ -n "$(scene_live_windows "$ws")" ] && printf '%s\t%s\t%s\n' "$ws" "$name" "$ids"
  done < "$STATE_FILE" >> "$tmp"
  mv "$tmp" "$STATE_FILE"
}

scene_of() {         # <workspace> -> scene name, or empty
  [ -f "$STATE_FILE" ] || return 0
  awk -F'\t' -v w="$1" '$1 == w { print $2; exit }' "$STATE_FILE"
}

# --- list -----------------------------------------------------------------
# Single source of truth for what scenes exist, so the launcher stays in sync.

SCENES_FILE="$DIR/scenes.json"

# scenes.local.json is yours and gitignored; it is merged over the shipped
# examples, so a fork gets sensible defaults and your own scenes survive a pull.
if [ -f "$DIR/scenes.local.json" ]; then
  _merged="$(mktemp)"
  trap 'rm -f "$_merged"' EXIT
  if jq -s '.[0] * .[1]' "$DIR/scenes.json" "$DIR/scenes.local.json" > "$_merged" 2>/dev/null; then
    SCENES_FILE="$_merged"
  fi
fi

# The merged set, for anything outside this file that needs to know what scenes
# exist. A temp file would not outlive this process, so hand over the JSON --
# one subprocess, and no second implementation of the merge to drift from.
if [ "${1:-}" = "--scenes-json" ]; then
  cat "$SCENES_FILE"
  exit 0
fi

if [ "${1:-}" = "--list" ]; then
  jq -r 'keys[]' "$SCENES_FILE" 2>/dev/null
  exit 0
fi

if [ "${1:-}" = "--describe" ]; then
  # "<scene>\t<short summary of its windows>", for the launcher's detail column.
  jq -r '
    to_entries[]
    | .key + "\t" + ([ .value.windows[]
        | sub("^app:"; "")
        | sub("^chrome-app:https?://(www\\.)?"; "")
        | sub("^chrome:https?://(www\\.)?"; "")
        | split(" ")[0] | split("/")[0] ] | join(" + "))
  ' "$SCENES_FILE" 2>/dev/null
  exit 0
fi

if [ "${1:-}" = "--open-scenes" ]; then
  prune_scenes
  [ -f "$STATE_FILE" ] && cat "$STATE_FILE"
  exit 0
fi

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

  if [ "$FORCE" -eq 1 ]; then
    WIDS="$($AEROSPACE list-windows --workspace "$WS" --format '%{window-id}')"
  else
    # Only the windows this scene opened, never whatever else has arrived since.
    WIDS="$(scene_live_windows "$WS" | tr ' ' '\n')"
  fi
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

# Scenes live in scenes.json, so adding one is data rather than code. Each
# entry is a ratio plus a list of window specs, left to right:
#   app:<App Name>     summon that app's window, launching it if not running
#   chrome:<urls...>   a new Chrome window with those tabs
#   chrome-app:<url>   a Chrome --app window: no tab strip, no toolbar
# ratio is the share of the width given to the first window.
if ! jq -e --arg s "$SCENE" 'has($s)' "$SCENES_FILE" >/dev/null 2>&1; then
  echo "scene: unknown scene '$SCENE'. Known:" >&2
  jq -r 'keys[] | "  " + .' "$SCENES_FILE" >&2 2>/dev/null
  exit 1
fi

RATIO="$(jq -r --arg s "$SCENE" '.[$s].ratio // 0.5' "$SCENES_FILE")"
WINDOWS=()
while IFS= read -r spec; do
  [ -n "$spec" ] && WINDOWS+=("$spec")
done < <(jq -r --arg s "$SCENE" '.[$s].windows[]' "$SCENES_FILE")

if [ "${#WINDOWS[@]}" -eq 0 ]; then
  echo "scene: '$SCENE' defines no windows" >&2
  exit 1
fi

# Resolve the Chrome profile directory from its display name, else use Default.
PROFILE_DIR=""
if [ -n "$PROFILE_NAME" ]; then
  PROFILE_DIR="$(jq -r --arg n "$PROFILE_NAME" '
    .profile.info_cache | to_entries[] | select(.value.name == $n) | .key
  ' "$LOCAL_STATE" 2>/dev/null | head -1)"
fi
PROFILE_DIR="${PROFILE_DIR:-Default}"

# Already open? Go to it rather than building a second copy on another
# workspace -- pressing the shortcut twice should land you on your scene, not
# leave two of them lying around.
prune_scenes
EXISTING="$(awk -F'\t' -v s="$SCENE" '$2 == s { print $1; exit }' "$STATE_FILE" 2>/dev/null)"
if [ -n "$EXISTING" ]; then
  FIRST="$(scene_live_windows "$EXISTING" | awk '{print $1}')"
  $AEROSPACE eval "workspace $EXISTING${FIRST:+; focus --window-id $FIRST}" >/dev/null 2>&1 \
    || $AEROSPACE workspace "$EXISTING"
  exit 0
fi

# A scene wants a clean workspace, not whatever is already open.
WS="$($AEROSPACE list-workspaces --monitor all --empty | head -1)"
if [ -z "$WS" ]; then
  echo "scene: no empty workspace available" >&2
  exit 1
fi

# Show the empty workspace *before* opening anything. The windows may still be
# created on the workspace you were on -- an empty one cannot hold focus, so
# AeroSpace falls back to the previously focused window -- but you are no longer
# looking at it, so you never see them appear somewhere and fly away. They are
# still moved by id rather than by trusting focus.


# Opens one window spec and prints the resulting window id.
open_spec() {
  local spec="$1" kind rest before
  kind="${spec%%:*}"
  rest="${spec#*:}"

  case "$kind" in
    app)
      # Native apps get summoned, not duplicated -- most only have one window,
      # and a second copy of Telegram isn't a thing anyone wants.
      local existing
      existing="$(find_app_window "$rest")"
      if [ -n "$existing" ]; then
        printf '%s' "$existing"
        return 0
      fi
      before="$(snapshot_windows)"
      open -a "$rest"
      wait_for_new_window "$before"
      ;;
    chrome)
      before="$(snapshot_windows)"
      # $rest is deliberately unquoted: several URLs become several tabs.
      open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" \
           --new-window $rest
      wait_for_new_window "$before"
      ;;
    chrome-app)
      before="$(snapshot_windows)"
      open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" \
           --app="$rest"
      wait_for_new_window "$before"
      ;;
    *)
      echo "scene: unknown window spec '$spec'" >&2
      return 1
      ;;
  esac
}

$AEROSPACE workspace "$WS"

# Place each window the moment it appears, in spec order, so the first ends up
# leftmost and each simply pops into the workspace you are already watching.
WIDS=()
for spec in "${WINDOWS[@]}"; do
  wid="$(open_spec "$spec")"
  if [ -z "$wid" ]; then
    echo "scene: window for '$spec' never appeared" >&2
    exit 1
  fi
  place_window "$wid" "$WS"
  WIDS+=("$wid")
done

if [ "${#WIDS[@]}" -ge 2 ]; then
  split_resize "${WIDS[0]}" "$RATIO"
fi
# Land on the scene. The switch at the top does not stick while the workspace is
# still empty -- focus falls back to the previous window -- and a launching app
# steals focus again as it comes up. Assert it once more now that the windows
# are here and settled.
$AEROSPACE eval "workspace $WS; focus --window-id ${WIDS[0]}" >/dev/null 2>&1 || true
remember_scene "$WS" "$SCENE" "${WIDS[@]}"
