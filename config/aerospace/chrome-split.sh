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
source "$DIR/split-lib.sh"

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
  CHOICE="$(printf '%s\n' "${NAMES[@]}" | PICKER_PROMPT="Which Chrome profile?" "$PICKER")"
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

ORIG_WID="$($AEROSPACE list-windows --focused --format '%{window-id}')"
BEFORE="$($AEROSPACE list-windows --all --format '%{window-id}' | sort)"

open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR" --new-window

# Wait for AeroSpace to adopt the new window into the focused workspace.
NEW=""
for _ in $(seq 1 60); do
  sleep 0.25
  NEW="$(comm -13 <(printf '%s\n' "$BEFORE") \
                  <($AEROSPACE list-windows --workspace focused --format '%{window-id}' | sort) \
         | head -1)"
  [ -n "$NEW" ] && break
done

if [ -z "$NEW" ]; then
  echo "chrome-split: new window never appeared" >&2
  exit 1
fi

# Nothing to split against if the workspace was empty before.
[ -n "$ORIG_WID" ] && [ "$ORIG_WID" != "$NEW" ] && split_resize "$ORIG_WID" "$RATIO"
