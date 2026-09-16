#!/usr/bin/env bash
#
# Which Chrome profile. Sourced, never executed.
#
# Chrome's AppleScript cannot choose a profile when making a window, so the
# only way in is `open -na ... --profile-directory=<dir>`, which Chrome routes
# into its existing process rather than starting a second copy. The mapping
# from the name you recognise to the directory Chrome wants lives in its own
# Local State file.
#
# Two callers need this -- opening a browser beside a window, and joining a
# meeting link -- which is one more than should have its own copy.

CHROME_LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"

# "<display name>\t<profile directory>\t<account email>", ordered as Chrome
# numbers them. The email is shown dimmed in the picker and is searchable.
chrome_profiles() {
  jq -r '
    .profile.info_cache | to_entries
    | sort_by(.key)[]
    | "\(.value.name)\t\(.key)\t\(.value.user_name // "")"
  ' "$CHROME_LOCAL_STATE" 2>/dev/null
}

chrome_profile_dir() {   # <display name>
  chrome_profiles | awk -F'\t' -v n="$1" '$1 == n { print $2; exit }'
}

# Ask, and print the chosen *directory*. Empty output means cancelled, which
# every caller should treat as "do nothing" rather than "use the default".
#
# Exit status 2 is the picker's alt-select, passed straight through: callers
# that offer a second destination read it, and callers that do not can ignore
# it because the chosen profile is on stdout either way.
chrome_pick_profile() {   # [prompt] [alt-hint]
  local prompt="${1:-Which Chrome profile?}" alt="${2:-}" profiles rows choice rc
  profiles="$(chrome_profiles)"
  [ -n "$profiles" ] || { echo "chrome: could not read Chrome profiles" >&2; return 1; }

  rows="$(printf '%s\n' "$profiles" | awk -F'\t' '{ print $1 "\t" $3 }')"
  local picker="${PICKER:-$HOME/.config/aerospace/bin/picker}"
  if [ -x "$picker" ]; then
    choice="$(printf '%s\n' "$rows" \
      | PICKER_PROMPT="$prompt" PICKER_CONTEXT=chrome-profile \
        PICKER_ALT_HINT="$alt" "$picker")"
    rc=$?
  else
    # Fallback when the picker has not been built. No detail column, so the
    # email is dropped rather than shown as a stray tab.
    choice="$(printf '%s\n' "$rows" | cut -f1 | osascript -l JavaScript -e '
      function run() {
        var app = Application.currentApplication();
        app.includeStandardAdditions = true;
        var names = app.doShellScript("cat").split("\r");
        app.activate();
        var picked = app.chooseFromList(names, { withPrompt: "Chrome profile" });
        return picked === false ? "" : picked[0];
      }' 2>/dev/null)"
    rc=0
  fi
  [ -n "$choice" ] || return 1
  chrome_profile_dir "$choice"
  return "$rc"
}

# Open a URL in a named profile, in a new window.
chrome_open_in() {   # <profile-directory> <url>...
  local dir="$1"; shift
  open -na "Google Chrome" --args --profile-directory="$dir" --new-window "$@"
}
