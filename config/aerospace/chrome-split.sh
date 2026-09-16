#!/usr/bin/env bash
#
# chrome-split.sh [ratio] [profile-name]
#
# Asks which Chrome profile to use, opens a *new* window in that profile beside
# the focused window, and sets the split (default: focused window keeps 0.6).
#
# Passing a profile name skips the dialog, so a binding can go straight to one
# profile:  chrome-split.sh 0.6 "Relote"
#
# Chrome's AppleScript `make new window` can't choose a profile, so the window
# is opened via `open -na ... --profile-directory=`, which Chrome routes into
# its existing process rather than starting a second copy.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/logging.sh"
source "$DIR/split-lib.sh"

NEW_WORKSPACE=0
if [ "${1:-}" = "--new-workspace" ]; then NEW_WORKSPACE=1; shift; fi

RATIO="${1:-0.6}"
WANT="${2:-}"

# Profiles, and asking which one, belong to chrome-lib.sh -- joining a meeting
# link needs exactly the same thing, and one of those two having its own copy
# is how they come to disagree about which profile is which.
# shellcheck source=/dev/null
source "$DIR/chrome-lib.sh"

if [ -n "$WANT" ]; then
  PROFILE_DIR="$(chrome_profile_dir "$WANT")"
  [ -n "$PROFILE_DIR" ] || { echo "chrome-split: unknown profile '$WANT'" >&2; exit 1; }
else
  # Shift+Return on the same row opens on a fresh workspace instead of beside
  # the current window: one row per profile, two destinations.
  export PICKER="$DIR/bin/picker"
  PROFILE_DIR="$(chrome_pick_profile "Which Chrome profile?" "new workspace")"
  # Exit 2 is the picker's alt-select: same profile, different destination.
  [ "$?" -eq 2 ] && NEW_WORKSPACE=1
fi

# Cancelled: leave the layout untouched.
[ -z "${PROFILE_DIR:-}" ] && exit 0

# Capture before opening: `open -a` activates Chrome, which moves focus, and
# AeroSpace does not reliably place the new window where you were. The menu
# exports these from before the picker took focus.
ORIG_WID="${DOT_ORIG_WID:-$($AEROSPACE list-windows --focused --format '%{window-id}')}"
ORIG_WS="${DOT_ORIG_WS:-$($AEROSPACE list-workspaces --focused)}"

if [ "$NEW_WORKSPACE" -eq 1 ]; then
  TARGET_WS="$($AEROSPACE list-workspaces --monitor all --empty | head -1)"
  if [ -z "$TARGET_WS" ]; then
    echo "chrome-split: no empty workspace available" >&2
    exit 1
  fi
else
  TARGET_WS="$ORIG_WS"
fi

BEFORE="$(snapshot_windows)"
open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" --new-window

NEW="$(wait_for_new_window "$BEFORE")"

if [ -z "$NEW" ]; then
  echo "chrome-split: new window never appeared" >&2
  exit 1
fi

# One round-trip for the move, the layout assertions and the switch.
place_window "$NEW" "$TARGET_WS"
$AEROSPACE workspace "$TARGET_WS" 2>/dev/null
sleep 0.1

# Only split when it went beside something; on a fresh workspace it is alone.
if [ "$NEW_WORKSPACE" -eq 0 ] && [ -n "$ORIG_WID" ] && [ "$ORIG_WID" != "$NEW" ]; then
  split_resize "$ORIG_WID" "$RATIO" || true
fi
