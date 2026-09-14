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
source "$DIR/scenes-lib.sh"
source "$DIR/ledger-lib.sh"

LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"

# --- list -----------------------------------------------------------------
# Single source of truth for what scenes exist, so the launcher stays in sync.

# The merge, the tombstone rule and the cache all live in scenes-lib.sh, which
# the bar sources too. SCENES_FILE is a materialised copy of the merged set so
# the rest of this file can keep passing a path to jq.
# Materialised once, here, rather than through a function: `V="$(f)"` runs f in
# a subshell, so a variable it sets is lost to the parent -- which meant the
# EXIT trap had nothing to remove and every run of this script leaked a temp
# file. There were 380 of them.
_SCENES_FILE="$(mktemp)"
trap 'rm -f "$_SCENES_FILE"' EXIT
scenes_merged > "$_SCENES_FILE"
SCENES_FILE="$_SCENES_FILE"

# Stage on demand and print what the previous session had, as
# "<workspace>\t<scene>" per line. The capability needs this before anything
# else has had a chance to prune, so it cannot wait for a prune to do it.
if [ "${1:-}" = "--previous-session" ]; then
  previous_session_rows
  exit 0
fi

if [ "${1:-}" = "--forget-previous" ]; then
  forget_previous_session
  exit 0
fi

# The merged set, for anything outside this file that needs to know what scenes
# exist. A temp file would not outlive this process, so hand over the JSON --
# one subprocess, and no second implementation of the merge to drift from.
if [ "${1:-}" = "--scenes-json" ]; then
  scenes_merged
  exit 0
fi

if [ "${1:-}" = "--list" ]; then
  jq -r 'keys[]' "$SCENES_FILE" 2>/dev/null
  exit 0
fi

if [ "${1:-}" = "--describe" ]; then
  scenes_summary_tsv
  exit 0
fi

# A read, and deliberately not a pruning one any more.
#
# prune_scenes asks AeroSpace which windows still exist -- once per ledger row
# -- and then rewrites the file. That made the palette's slowest descriptor a
# disk write and an IPC storm, on the one path where latency is felt. Every
# writer already prunes (remember_scene calls it, close calls forget_scene), so
# the only thing this drops is garbage-collecting a scene whose windows you
# closed by hand, and the cost of that is a stale row in the launcher until the
# next scene command -- at which point closing it says "already empty" and
# forgets it, which was always the handled path.
if [ "${1:-}" = "--open-scenes" ]; then
  [ -f "$STATE_FILE" ] && cat "$STATE_FILE"
  exit 0
fi

# --- close ----------------------------------------------------------------

# --- move -----------------------------------------------------------------
# scene.sh move <target-workspace> [source-workspace]
#
# Moves a whole scene somewhere else. Only the windows the scene opened travel:
# anything else that has since landed on that workspace stays where it is, for
# the same reason `close` only ever closes the scene's own windows.
if [ "${1:-}" = "move" ]; then
  shift
  STAY=0
  if [ "${1:-}" = "--stay" ]; then STAY=1; shift; fi
  TARGET="${1:-}"
  if [ -z "$TARGET" ]; then
    echo "scene: usage: scene.sh move [--stay] <workspace> [from-workspace]" >&2
    exit 1
  fi
  FROM="${2:-$($AEROSPACE list-workspaces --focused)}"

  NAME="$(scene_of "$FROM")"
  if [ -z "$NAME" ]; then
    echo "scene: workspace $FROM is not running a scene." >&2
    if [ -s "$STATE_FILE" ]; then
      echo "scene: open scenes are:" >&2
      sed 's/^/  workspace /;s/\t/  -> /' "$STATE_FILE" >&2
    fi
    exit 1
  fi
  if [ "$TARGET" = "$FROM" ]; then
    echo "scene: $NAME is already on workspace $TARGET" >&2
    exit 0
  fi
  if ! $AEROSPACE list-workspaces --monitor all | grep -qx "$TARGET"; then
    echo "scene: no workspace '$TARGET'" >&2
    exit 1
  fi

  # In the order they sit on the source workspace, not the order the scene
  # opened them in. You may have rearranged them since, and a move should not
  # quietly reshuffle a layout you arranged by hand.
  #
  # scene_live_windows already returns them space-separated; splitting that on
  # newlines and reading it back only created the chance to drop the last one.
  LIVE=" $(scene_live_windows "$FROM") "
  MOVE_WIDS=()
  while read -r wid; do
    case "$LIVE" in *" $wid "*) MOVE_WIDS+=("$wid") ;; esac
  done < <($AEROSPACE list-windows --workspace "$FROM" --format '%{window-id}')

  if [ "${#MOVE_WIDS[@]}" -eq 0 ]; then
    forget_scene "$FROM"
    echo "scene: $NAME has no windows left to move" >&2
    exit 1
  fi

  # One round-trip, in the scene's own order, so the windows arrive left to
  # right the way they were rather than in whatever order the moves land.
  batch=""
  for wid in "${MOVE_WIDS[@]}"; do
    batch="$batch${batch:+; }move-node-to-workspace --window-id $wid $TARGET"
    batch="$batch; layout tiling --window-id $wid; layout tiles --window-id $wid"
  done
  $AEROSPACE eval "$batch" >/dev/null 2>&1 || true

  # eval returns when the commands are accepted, not when they have taken
  # effect, so wait for the windows to actually be on the target before
  # recording that they are.
  for _ in $(seq 1 20); do
    placed="$($AEROSPACE list-windows --workspace "$TARGET" --format '%{window-id}')"
    settled=1
    for wid in "${MOVE_WIDS[@]}"; do
      case "$NL$placed$NL" in *"$NL$wid$NL"*) ;; *) settled=0 ;; esac
    done
    [ "$settled" -eq 1 ] && break
    sleep 0.02
  done

  # The ledger moves with it, or `close` would aim at the workspace the scene
  # used to be on -- which by then is whatever you have put there since.
  forget_scene "$FROM"
  remember_scene "$TARGET" "$NAME" "${MOVE_WIDS[@]}"

  # Go with it by default: you asked to move the thing you were looking at, so
  # being left staring at where it used to be is not the outcome you wanted.
  if [ "$STAY" -eq 0 ]; then
    $AEROSPACE eval "workspace $TARGET; focus --window-id ${MOVE_WIDS[0]}" >/dev/null 2>&1 \
      || $AEROSPACE workspace "$TARGET"
  fi

  # Put the ratio back, and only now: re-tiling into a workspace spreads the
  # windows evenly, so the scene loses its split in the move. Measured -- a
  # 60/40 scene came out 840/840 on a 1710pt display.
  #
  # It has to happen after the switch above, because AeroSpace gives a hidden
  # workspace no real geometry at all: its windows sit parked off-screen at
  # whatever size they last had, and two windows of that same scene measured
  # 1852pt and 626pt while hidden. Resizing into that is aiming at nothing,
  # which is what made an earlier version land a 97/3 split. With --stay there
  # is nothing to aim at, so the split is left for the next time the workspace
  # is shown.
  if [ "$STAY" -eq 0 ] && [ "${#MOVE_WIDS[@]}" -ge 2 ]; then
    RATIO="$(jq -r --arg s "$NAME" '.[$s].ratio // 0.5' "$SCENES_FILE" 2>/dev/null)"
    split_resize "${MOVE_WIDS[0]}" "${RATIO:-0.5}" || true
  fi

  echo "scene: moved $NAME from workspace $FROM to $TARGET"
  exit 0
fi

# --- quitting apps --------------------------------------------------------
#
# Closing the messaging scene and leaving WhatsApp running is half a job. But
# closing the chill scene must never quit Chrome, because Chrome is also the
# window you have open on another workspace.
#
# Configuration alone cannot tell those apart -- it does not know what else you
# have open right now. So the scene only says *whether* it tidies up after
# itself ("quit": true, off by default), and the decision about each app is made
# by looking: quit it only if closing the scene left it with no windows at all.
# That gets both cases right without being told, and it stays right on the day
# you happen to have a second WhatsApp window somewhere.

# Reads "<app-name>|<bundle-id>" per line on stdin; prints what it quit.
# On stdin, not as arguments: app names have spaces in them, and "Google
# Chrome|com.google.Chrome" splits into two useless words.
quit_if_empty() {
  local entry app bundle live quit_names=""
  # AeroSpace alone decides this.
  #
  # An earlier version also consulted CGWindowListCopyWindowInfo, on the theory
  # that two views are safer than one. They are not, when one of them is wrong:
  # CG retains entries for windows that have already closed. With WhatsApp and
  # Telegram sitting there running with no windows at all, it still reported a
  # 840x1051 "Telegram @ Mert" for each of them -- and a Ghostty that had quit
  # an hour earlier. So the cross-check never let either app be quit, which is
  # exactly the case this feature exists for.
  #
  # AeroSpace is the authority on which windows exist; it is what every other
  # decision in this repo is made from, and it was right here too.
  live="$($AEROSPACE list-windows --monitor all --format '%{app-name}' 2>/dev/null)"

  while IFS= read -r entry; do
    app="${entry%%|*}"; bundle="${entry#*|}"
    [ -n "$app" ] && [ -n "$bundle" ] || continue
    printf '%s\n' "$live" | grep -qxF "$app" && continue
    case " $quit_names " in *" $app "*) continue ;; esac
    # By bundle id: an app can be renamed, and "tell application <name>" will
    # happily go looking for a file by that name if no such app is running.
    if osascript -e "tell application id \"$bundle\" to quit" >/dev/null 2>&1; then
      quit_names="$quit_names $app"
    else
      # Quitting another app is an Apple Event, so the first attempt asks for
      # Automation permission. Run from a keybinding there may be no prompt to
      # answer -- it just fails -- so say what happened rather than leaving the
      # app silently running. System Settings > Privacy & Security > Automation.
      echo "scene: could not quit $app -- allow it under Privacy & Security > Automation" >&2
    fi
  done
  printf '%s' "${quit_names# }"
}

if [ "${1:-}" = "close" ]; then
  shift
  # Flags in any position: `close --force 5` and `close 5 --force` both read
  # naturally, and guessing wrong about which one someone typed is a poor
  # reason to silently ignore --no-quit.
  FORCE=0; QUIT_OVERRIDE=""; WS=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force)   FORCE=1 ;;
      --quit)    QUIT_OVERRIDE=1 ;;
      --no-quit) QUIT_OVERRIDE=0 ;;
      -*) echo "scene: unknown option $1" >&2; exit 1 ;;
      *) [ -z "$WS" ] && WS="$1" ;;
    esac
    shift
  done
  [ -n "$WS" ] || WS="$($AEROSPACE list-workspaces --focused)"

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

  QUIT="${QUIT_OVERRIDE:-$(jq -r --arg s "$NAME" 'if .[$s].quit then 1 else 0 end' \
                           "$SCENES_FILE" 2>/dev/null)}"
  # Which apps these windows belong to, read before they are gone.
  APPS=""
  if [ "${QUIT:-0}" = "1" ]; then
    APPS="$($AEROSPACE list-windows --monitor all \
              --format '%{window-id}|%{app-name}|%{app-bundle-id}' 2>/dev/null \
            | awk -F'|' -v ids="$(printf '%s' "$WIDS" | tr '\n' ' ')" '
                BEGIN { n = split(ids, a, " "); for (i = 1; i <= n; i++) want[a[i]] = 1 }
                want[$1] { print $2 "|" $3 }' | sort -u)"
  fi

  # One round-trip for the lot, the same way the open path batches placement.
  batch=""
  for wid in $WIDS; do
    [ -n "$wid" ] && batch="$batch${batch:+; }close --window-id $wid"
  done
  [ -n "$batch" ] && $AEROSPACE eval "$batch" >/dev/null 2>&1
  forget_scene "$WS"

  if [ -n "$APPS" ]; then
    # The windows have to be actually gone before asking whether any are left,
    # and `close` returns before that. Up to two seconds: an app is entitled to
    # take a moment over closing a window, and quitting it early would be
    # deciding on stale information.
    # One enumeration per tick, tested against every id -- not one enumeration
    # per id per tick, which was up to 150 round-trips over two seconds and
    # saturated the same socket the closes were travelling on.
    for _ in $(seq 1 50); do
      open_now="$($AEROSPACE list-windows --monitor all --format '%{window-id}' 2>/dev/null)"
      still=0
      for wid in $WIDS; do
        case "$NL$open_now$NL" in *"$NL$wid$NL"*) still=1 ;; esac
      done
      [ "$still" -eq 0 ] && break
      sleep 0.04
    done
    quit="$(printf '%s\n' "$APPS" | quit_if_empty)"
    [ -n "$quit" ] && echo "scene: quit $quit"
  fi
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
#
# SCENE_WS asks for a particular one -- `dot scene restore` uses it to put a
# scene back where it was before the reboot -- but only if it is empty. A
# preference cannot be allowed to override the one rule that keeps this safe.
EMPTY="$($AEROSPACE list-workspaces --monitor all --empty)"
WS=""
if [ -n "${SCENE_WS:-}" ]; then
  case "$NL$EMPTY$NL" in *"$NL$SCENE_WS$NL"*) WS="$SCENE_WS" ;; esac
fi
[ -n "$WS" ] || WS="$(printf '%s\n' "$EMPTY" | head -1)"
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

# Land on the scene. The switch at the top does not stick while the workspace is
# still empty -- focus falls back to the previous window -- and a launching app
# steals focus again as it comes up. Assert it once more now that the windows
# are here and settled.
$AEROSPACE eval "workspace $WS; focus --window-id ${WIDS[0]}" >/dev/null 2>&1 || true

# The split goes last, and only once the workspace is actually the one on
# screen. AeroSpace gives a workspace no real geometry until it is showing, so
# a resize issued before that assertion lands on parked windows and sticks
# there: a 60/40 scene opened as 1852/626 on a 1710pt display, reproducibly,
# and came out exactly 1008/672 when the identical call was made a moment
# later. `dot scene move` had the same ordering bug and the same fix.
if [ "${#WIDS[@]}" -ge 2 ]; then
  sleep 0.15
  split_resize "${WIDS[0]}" "$RATIO"
fi
remember_scene "$WS" "$SCENE" "${WIDS[@]}"
