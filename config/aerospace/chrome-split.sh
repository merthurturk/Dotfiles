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
LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"

# "<display name>\t<profile directory>\t<account email>", ordered as Chrome
# numbers them. The email is shown dimmed in the picker and is searchable.
PROFILES="$(jq -r '
  .profile.info_cache | to_entries
  | sort_by(.key)[]
  | "\(.value.name)\t\(.key)\t\(.value.user_name // "")"
' "$LOCAL_STATE" 2>/dev/null)"

if [ -z "$PROFILES" ]; then
  echo "chrome-split: could not read Chrome profiles" >&2
  exit 1
fi

# The picker takes "label<TAB>detail" per line.
NAMES=()
while IFS=$'\t' read -r name _dir email; do
  [ -n "$name" ] && NAMES+=("$(printf '%s\t%s' "$name" "$email")")
done <<EOF
$PROFILES
EOF

PICKER="$DIR/bin/picker"

if [ -n "$WANT" ]; then
  CHOICE="$WANT"
elif [ -x "$PICKER" ]; then
  # Native panel: auto-focused, type-to-filter, arrows + enter, esc to cancel.
  # Shift+Return on the same row opens on a fresh workspace instead of beside
  # the current window: one row per profile, two destinations.
  CHOICE="$(printf '%s\n' "${NAMES[@]}" \
    | PICKER_PROMPT="Which Chrome profile?" PICKER_CONTEXT=chrome-profile \
      PICKER_ALT_HINT="new workspace" "$PICKER")"
  [ "$?" -eq 2 ] && NEW_WORKSPACE=1
else
  # Fallback if the picker hasn't been built. It has no detail column, so strip
  # the tab-separated email off each entry.
  PLAIN=("${NAMES[@]%%$'\t'*}")
  CHOICE="$(osascript -l JavaScript -e '
function run(argv) {
  var app = Application.currentApplication();
  app.includeStandardAdditions = true;
  app.activate();
  var picked = app.chooseFromList(argv, {
    withPrompt: "Which Chrome profile?",
    withTitle: "Split with Chrome",
    defaultItems: [argv[0]]
  });
  return picked === false ? "" : picked[0];
}' "${PLAIN[@]}" 2>/dev/null)"
fi

# Cancelled: leave the layout untouched.
[ -z "$CHOICE" ] && exit 0

PROFILE_DIR="$(printf '%s\n' "$PROFILES" | awk -F'\t' -v n="$CHOICE" '$1 == n { print $2; exit }')"
[ -n "$PROFILE_DIR" ] || { echo "chrome-split: unknown profile '$CHOICE'" >&2; exit 1; }

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

place_window "$NEW" "$TARGET_WS"
$AEROSPACE workspace "$TARGET_WS" 2>/dev/null
sleep 0.4

# Only split when it went beside something; on a fresh workspace it is alone.
if [ "$NEW_WORKSPACE" -eq 0 ] && [ -n "$ORIG_WID" ] && [ "$ORIG_WID" != "$NEW" ]; then
  split_resize "$ORIG_WID" "$RATIO" || true
fi
