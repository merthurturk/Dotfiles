#!/usr/bin/env bash
#
# Shared by every dot capability.
#
# describe() prints the JSON descriptor and exits. Keeping the descriptor next
# to the implementation is the whole point: there is no second place to update,
# so the surface can't drift from what actually runs.

# Consumed by the capability scripts that source this file, which the linter
# cannot see from here.
# shellcheck disable=SC2034
DOT_ROOT="${DOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AEROSPACE=/opt/homebrew/bin/aerospace
# Ghostty's CLI lives inside the app bundle, and is on PATH only for
# interactive shells -- its shell integration puts it there. Anything AeroSpace
# execs gets the [exec] PATH table instead, which does not have it, so the
# launcher would silently fail to reach a binary a terminal finds instantly.
GHOSTTY="$(command -v ghostty 2>/dev/null)"
[ -n "$GHOSTTY" ] || GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
AERO_CONFIG="$HOME/.aerospace.toml"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
# Deliberately no SCENES_JSON here. The shipped file must never be read on its
# own -- scenes.local.json is merged over it, tombstones and all -- and a
# plausible-looking variable in the shared lib is how a fifth private copy of
# that merge gets written. Ask the owner: scenes_json() below.
SKETCHY="$HOME/.config/sketchybar"
SCENE_SH="$DOT_ROOT/config/aerospace/scene.sh"
SCENES_LOCAL="$DOT_ROOT/config/aerospace/scenes.local.json"
PICKER="$DOT_ROOT/config/aerospace/bin/picker"
LEDGER="$STATE_DIR/scenes"

# keybinding <substring of the binding's command> -> "alt-shift-space" or empty
#
# The config is read once per process. `dot scene open --describe` calls this
# per scene, and re-reading and re-filtering aerospace.toml for each one is a
# cost that grows with how many scenes you have -- which `dot scene save`
# exists to make grow.
_BINDS=""
keybinding() {
  [ -n "$_BINDS" ] || _BINDS="$(grep -E "^[[:space:]]*[a-z0-9-]+ = " "$AERO_CONFIG" 2>/dev/null)"
  printf '%s\n' "$_BINDS" \
    | grep -F -- "$1" | head -1 \
    | sed -E 's/^[[:space:]]*([a-z0-9-]+) =.*/\1/'
}

# Pretty-print a binding for humans: alt-shift-space -> ⌥⇧space
keysym() {
  [ -n "${1:-}" ] || return 0
  printf '%s' "$1" | sed -e 's/alt-/⌥/g'  -e 's/shift-/⇧/g' \
                         -e 's/ctrl-/⌃/g' -e 's/cmd-/⌘/g'   \
                         -e 's/enter/↩/'  -e 's/backspace/⌫/' \
                         -e 's|backslash|\\|' -e 's/semicolon/;/' \
                         -e 's/slash/\//' -e 's/comma/,/' -e 's/minus/-/' \
                         -e 's/equal/=/'
}

# --- scenes ---------------------------------------------------------------

# The merged scenes.json + scenes.local.json, cached.
#
# scene.sh owns the merge -- tombstones and all -- and this does not reimplement
# it; it asks, and remembers the answer. Five descriptors read this on every
# ⌥space, and each ask costs a bash start, a mktemp and a jq (~21ms) for a file
# that only changes when you edit a scene.
#
# The cache is invalidated three ways: either input being newer, scene.sh
# itself being newer (otherwise changing the merge rule would leave every
# capability reading the old answer), and explicitly by json_update.
#
# That last one is not belt-and-braces. mtime on this filesystem has one-second
# granularity, so a write followed immediately by a read -- `dot scene edit`
# saving and then printing what it saved, which is every edit -- compares equal
# and the stale answer wins. It did: an edit reported the old icon back, and
# `dot scene delete` could not find a scene that had just been renamed.
SCENES_CACHE="$STATE_DIR/scenes-merged.json"
scenes_json() {
  local cache="$SCENES_CACHE"
  local shipped="$DOT_ROOT/config/aerospace/scenes.json"
  if [ -s "$cache" ] && [ ! "$shipped" -nt "$cache" ] \
     && [ ! "$SCENES_LOCAL" -nt "$cache" ] && [ ! "$SCENE_SH" -nt "$cache" ]; then
    cat "$cache"; return 0
  fi
  local tmp; tmp="$(mktemp)"
  if "$SCENE_SH" --scenes-json 2>/dev/null > "$tmp" && [ -s "$tmp" ]; then
    mkdir -p "$STATE_DIR"; mv "$tmp" "$cache"; cat "$cache"
  else
    rm -f "$tmp"; echo '{}'
  fi
}

scene_exists() { scenes_json | jq -e --arg n "$1" 'has($n)' >/dev/null 2>&1; }

# A scene name is how you address it on the command line, so keep it typeable.
slug() { printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-'; }

# --- what you were looking at ---------------------------------------------

# The palette takes focus, so "the focused window" stops being yours the moment
# you press a key. `dot menu` captures both before opening the picker and
# exports them; these fall back to asking, for when a capability is run from a
# shell instead.
orig_ws()  { printf '%s' "${DOT_ORIG_WS:-$($AEROSPACE list-workspaces --focused 2>/dev/null)}"; }
orig_wid() { printf '%s' "${DOT_ORIG_WID:-$($AEROSPACE list-windows --focused --format '%{window-id}' 2>/dev/null)}"; }

# --- the picker -----------------------------------------------------------

# pick <prompt> [history-context]   rows as "label\tdetail" on stdin
pick() {
  [ -x "$PICKER" ] || { echo "dot: picker not built - run install.sh" >&2; return 1; }
  PICKER_PROMPT="$1" PICKER_CONTEXT="${2:-dot}" "$PICKER"
}
# ask <prompt>                      one line of text
ask() {
  [ -x "$PICKER" ] || { echo "dot: picker not built - run install.sh" >&2; return 1; }
  PICKER_MODE=input PICKER_PROMPT="$1" "$PICKER" </dev/null
}
# confirm <prompt> <yes-label> <detail>   -> 0 if the yes row was chosen
confirm() {
  local ans
  ans="$(printf '%s\t%s\nCancel\t\n' "$2" "${3:-}" | pick "$1" confirm)"
  [ "$ans" = "$2" ]
}

# --- workspaces -----------------------------------------------------------

# Rows for a palette that offers "somewhere else to put this": every occupied
# workspace with what is on it, plus the first empty one. JSON [{ws, detail}].
#
# Not all thirty empty workspaces -- that is thirty copies of the same row.
workspace_rows() {   # <workspace to leave out>
  $AEROSPACE list-windows --monitor all --format '%{workspace}|%{app-name}' 2>/dev/null \
    | sort -u \
    | jq -R -s --arg cur "$1" \
          --arg empty "$($AEROSPACE list-workspaces --monitor all --empty 2>/dev/null | head -1)" \
          --arg state "$(cat "$LEDGER" 2>/dev/null)" '
        ($state | split("\n") | map(select(length>0) | split("\t"))
                | map({(.[0]): .[1]}) | add // {}) as $scenes
        | (split("\n") | map(select(length>0) | split("|"))
           | group_by(.[0])
           | map({ws: .[0][0], apps: (map(.[1]) | join(", "))}))
          + (if $empty == "" then [] else [{ws: $empty, apps: "empty"}] end)
        | map(select(.ws != $cur))
        | map({ws, detail: (if $scenes[.ws] then "scene: " + $scenes[.ws] else .apps end)})'
}

# --- writing ---------------------------------------------------------------

# json_update <file> <jq args...>   read-modify-write, atomically
#
# Bootstraps {} if the file is missing, and goes through mktemp rather than
# "<file>.tmp": scene.sh had three functions sharing one fixed suffix, and a
# nested call moved the file out from under its caller.
json_update() {
  local file="$1"; shift
  [ -f "$file" ] || echo '{}' > "$file"
  local tmp; tmp="$(mktemp)"
  if jq "$@" "$file" > "$tmp" && [ -s "$tmp" ]; then
    mv "$tmp" "$file"
    [ "$file" = "$SCENES_LOCAL" ] && rm -f "$SCENES_CACHE"
    return 0
  else
    rm -f "$tmp"; echo "dot: could not write $file" >&2; return 1
  fi
}

# The bar reads the scene definitions and the ledger on every repaint, so a
# change shows up on the next workspace switch anyway -- but waiting for one to
# see whether you liked the colour is a poor way to choose a colour.
repaint() { sketchybar --trigger aerospace_workspace_change >/dev/null 2>&1 || true; }

# Append a line to the mutation audit log. Anything that changes system state
# should call this, so an agent's actions are reviewable after the fact.
audit() {
  mkdir -p "$STATE_DIR"
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "${DOT_ACTOR:-user}" "$*" \
    >> "$STATE_DIR/audit.log"
}
