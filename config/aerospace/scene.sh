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

remember_scene() {   # <workspace> <scene>
  mkdir -p "$STATE_DIR"
  prune_scenes
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

# Drops entries whose workspace no longer has any windows. Without this,
# reopening a scene (which summons its windows out of the old workspace) leaves
# a stale row behind and the launcher offers a Close for an empty workspace.
prune_scenes() {
  [ -f "$STATE_FILE" ] || return 0
  local tmp="$STATE_FILE.tmp" ws name
  : > "$tmp"
  while IFS=$'\t' read -r ws name; do
    [ -n "${ws:-}" ] || continue
    if [ -n "$($AEROSPACE list-windows --workspace "$ws" --format '%{window-id}')" ]; then
      printf '%s\t%s\n' "$ws" "$name" >> "$tmp"
    fi
  done < "$STATE_FILE"
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
  local before="$1" new=""
  # shellcheck disable=SC2034  # counted loop; the index is deliberately unused
  for _i in $(seq 1 60); do
    sleep 0.25
    new="$(comm -13 <(printf '%s\n' "$before") \
                    <($AEROSPACE list-windows --all --format '%{window-id}' | sort) \
           | head -1)"
    [ -n "$new" ] && break
  done
  printf '%s' "$new"
}

snapshot() { $AEROSPACE list-windows --all --format '%{window-id}' | sort; }

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
      before="$(snapshot)"
      open -a "$rest"
      wait_new_window "$before"
      ;;
    chrome)
      before="$(snapshot)"
      # $rest is deliberately unquoted: several URLs become several tabs.
      open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" \
           --new-window $rest
      wait_new_window "$before"
      ;;
    chrome-app)
      before="$(snapshot)"
      open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" \
           --app="$rest"
      wait_new_window "$before"
      ;;
    *)
      echo "scene: unknown window spec '$spec'" >&2
      return 1
      ;;
  esac
}

WIDS=()
for spec in "${WINDOWS[@]}"; do
  wid="$(open_spec "$spec")"
  if [ -z "$wid" ]; then
    echo "scene: window for '$spec' never appeared" >&2
    exit 1
  fi
  WIDS+=("$wid")
done

# Move in order so the first spec ends up leftmost, then reveal the workspace.
# Force tiling: an app may open its window floating, which would sit on top of
# the layout instead of in it, and can't be resized.
for wid in "${WIDS[@]}"; do
  $AEROSPACE move-node-to-workspace --window-id "$wid" "$WS"
  $AEROSPACE layout --window-id "$wid" tiling >/dev/null 2>&1 || true
  $AEROSPACE layout --window-id "$wid" tiles  >/dev/null 2>&1 || true
done
$AEROSPACE workspace "$WS"
sleep 0.4

if [ "${#WIDS[@]}" -ge 2 ]; then
  split_resize "${WIDS[0]}" "$RATIO"
fi
$AEROSPACE focus --window-id "${WIDS[0]}" 2>/dev/null || true
remember_scene "$WS" "$SCENE"
