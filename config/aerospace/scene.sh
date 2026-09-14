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
  local tmp; tmp="$(mktemp)"
  [ -f "$STATE_FILE" ] && grep -v "^$ws	" "$STATE_FILE" > "$tmp" 2>/dev/null
  printf '%s\t%s\t%s\n' "$ws" "$name" "$ids" >> "$tmp"
  mv "$tmp" "$STATE_FILE"
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
  local tmp; tmp="$(mktemp)"
  grep -v "^$1	" "$STATE_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$STATE_FILE"
}

PREV_FILE="$STATE_DIR/scenes-previous"   # the ledger as it was before a restart

# A ledger written before this boot describes the previous session: every
# window in it went away with the machine, and the next prune would drop the
# lot without anyone getting to see what was open.
#
# Move it aside once, the first time anything touches the ledger after a
# restart, so `dot scene restore` still has something to offer. Keyed on the
# boot clock rather than on the windows being gone, because "all its windows
# are gone" is also what closing a scene by hand looks like.
stage_previous_session() {
  [ -s "$STATE_FILE" ] || return 0
  local boot mtime
  # "{ sec = 1785738856, usec = 84400 } Mon Aug  3 ...". Anchored on the
  # opening brace: a greedy .* before "sec = " matches the *last* one, which is
  # "usec = ", and hands back a boot time in 1970.
  boot="$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^{ *sec *= *\([0-9][0-9]*\).*/\1/p')"
  [ -n "$boot" ] || return 0
  mtime="$(stat -f %m "$STATE_FILE" 2>/dev/null)"
  [ -n "$mtime" ] || return 0
  [ "$mtime" -lt "$boot" ] || return 0
  mv "$STATE_FILE" "$PREV_FILE"
  : > "$STATE_FILE"
}

# Drops entries whose windows are all gone, and collapses any workspace that
# somehow has two lines -- the last one wins.
#
# These three functions used to share one temp path, $STATE_FILE.tmp. Nothing
# here runs concurrently on purpose, but remember_scene calls prune_scenes and
# both then wrote and moved the same file; a failed mv left the ledger with a
# duplicated line and "mv: scenes.tmp: No such file or directory" in the log.
# mktemp each, so they cannot collide however they end up nested.
#
# Keyed on the scene's *own* windows, not on the workspace having anything at
# all: an entry that outlives its windows is how `close` ends up destroying
# whatever you have since put there.
prune_scenes() {
  stage_previous_session
  [ -f "$STATE_FILE" ] || return 0
  local tmp ws name ids; tmp="$(mktemp)"
  while IFS=$'\t' read -r ws name ids; do
    [ -n "${ws:-}" ] || continue
    [ -n "$(scene_live_windows "$ws")" ] && printf '%s\t%s\t%s\n' "$ws" "$name" "$ids"
  done < "$STATE_FILE" \
    | awk -F'\t' '{ line[$1] = $0 } END { for (w in line) print line[w] }' > "$tmp"
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
#
# A null in the local file is a tombstone: it is how you delete a scene you did
# not write. Removing the key would only let the shipped one back in on the
# next merge, which reads as the delete having silently failed.
if [ -f "$DIR/scenes.local.json" ]; then
  _merged="$(mktemp)"
  trap 'rm -f "$_merged"' EXIT
  if jq -s '.[0] * .[1] | with_entries(select(.value != null))' \
       "$DIR/scenes.json" "$DIR/scenes.local.json" > "$_merged" 2>/dev/null; then
    SCENES_FILE="$_merged"
  fi
fi

# Stage on demand and print what the previous session had, as
# "<workspace>\t<scene>" per line. The capability needs this before anything
# else has had a chance to prune, so it cannot wait for a prune to do it.
if [ "${1:-}" = "--previous-session" ]; then
  stage_previous_session
  [ -f "$PREV_FILE" ] && cut -f1,2 "$PREV_FILE"
  exit 0
fi

if [ "${1:-}" = "--forget-previous" ]; then
  rm -f "$PREV_FILE"
  exit 0
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
        # Only a chrome spec holds several space-separated URLs. Trimming an
        # app spec at the first space turned "T3 Code (Alpha)" into "T3".
        | if startswith("app:") then sub("^app:"; "")
          else sub("^chrome(-app)?:https?://(www\\.)?"; "")
               | split(" ")[0] | split("/")[0] end ] | join(" + "))
  ' "$SCENES_FILE" 2>/dev/null
  exit 0
fi

if [ "${1:-}" = "--open-scenes" ]; then
  prune_scenes
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
  # `|| [ -n "$wid" ]`: scene_live_windows prints its ids without a trailing
  # newline, so read returns false on the last one -- which dropped the final
  # window of every scene, leaving it behind and out of the ledger.
  LIVE=""
  while read -r wid || [ -n "$wid" ]; do
    [ -n "$wid" ] && LIVE="$LIVE $wid"
  done < <(scene_live_windows "$FROM" | tr ' ' '\n')
  MOVE_WIDS=()
  while read -r wid; do
    case " $LIVE " in *" $wid "*) MOVE_WIDS+=("$wid") ;; esac
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
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    placed="$($AEROSPACE list-windows --workspace "$TARGET" --format '%{window-id}')"
    settled=1
    for wid in "${MOVE_WIDS[@]}"; do
      printf '%s\n' "$placed" | grep -qx "$wid" || settled=0
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
  # Two independent views of what is still open. AeroSpace knows the windows it
  # manages; CGWindowList sees every window there is, including ones AeroSpace
  # does not tile. Either one saying "still open" is enough to leave the app
  # alone -- the conservative direction is the safe one here.
  live="$($AEROSPACE list-windows --monitor all --format '%{app-name}' 2>/dev/null)"
  local geom="$DIR/bin/geometry"
  [ -x "$geom" ] && live="$live
$("$geom" 2>/dev/null | cut -f6)"

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
      echo "scene: could not quit $app -- grant Automation for it (dot doctor says where)" >&2
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

  printf '%s\n' "$WIDS" | while read -r wid; do
    [ -n "$wid" ] && $AEROSPACE close --window-id "$wid" 2>/dev/null
  done
  forget_scene "$WS"

  if [ -n "$APPS" ]; then
    # The windows have to be actually gone before asking whether any are left,
    # and `close` returns before that.
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      still=0
      for wid in $WIDS; do
        $AEROSPACE list-windows --monitor all --format '%{window-id}' 2>/dev/null \
          | grep -qx "$wid" && still=1
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
WS=""
if [ -n "${SCENE_WS:-}" ]; then
  $AEROSPACE list-workspaces --monitor all --empty | grep -qx "$SCENE_WS" && WS="$SCENE_WS"
fi
[ -n "$WS" ] || WS="$($AEROSPACE list-workspaces --monitor all --empty | head -1)"
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
