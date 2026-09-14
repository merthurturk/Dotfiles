#!/usr/bin/env bash
#
# The ledger: which scene is open on which workspace, and which windows it
# opened. Sourced, never executed.
#
# Recording the window ids is what makes closing safe. An earlier version
# recorded only the workspace and pruned an entry once that workspace was
# empty -- so if the scene's own windows were gone but you had since put your
# own there, the entry survived and `close` destroyed them. That happened.
#
# This lives in its own file because five capabilities need to read it and
# three need to write it, and they were each doing that with their own awk
# over the tab-separated format. That made the column count public API. It is
# sourced rather than executed so asking the owner costs nothing.

LEDGER_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
STATE_FILE="$LEDGER_DIR/scenes"        # "<workspace>\t<scene>\t<id,id>" per line
PREV_FILE="$LEDGER_DIR/scenes-previous"
: "${AEROSPACE:=/opt/homebrew/bin/aerospace}"
NL=$'\n'

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
#
# The second argument is the list of live ids, for callers with more than one
# workspace to check: prune_scenes walked every ledger row and this re-asked
# AeroSpace for the same list each time, one round-trip per open scene.
scene_live_windows() {   # <workspace> [live-ids]
  local ws="$1" name ids alive="" id existing="${2:-}"
  IFS=$'\t' read -r _ name ids < <(awk -F'\t' -v w="$ws" '$1==w{print;exit}' "$STATE_FILE" 2>/dev/null)
  [ -n "${ids:-}" ] || return 0
  [ -n "$existing" ] || existing="$($AEROSPACE list-windows --all --format '%{window-id}')"
  for id in ${ids//,/ }; do
    case "$NL$existing$NL" in *"$NL$id$NL"*) alive="$alive $id" ;; esac
  done
  printf '%s' "${alive# }"
}

forget_scene() {     # <workspace>
  [ -f "$STATE_FILE" ] || return 0
  local tmp; tmp="$(mktemp)"
  grep -v "^$1	" "$STATE_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$STATE_FILE"
}


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

# Drops entries whose windows are all gone.
#
# These three functions used to share one temp path, $STATE_FILE.tmp. Nothing
# here runs concurrently on purpose, but remember_scene calls prune_scenes and
# both then wrote and moved the same file; a failed mv left the ledger with a
# duplicated line and "mv: scenes.tmp: No such file or directory" in the log.
# mktemp each, so they cannot collide however they end up nested.
#
# That fix is also why there is no dedupe pass here any more. There was one,
# and `for (w in line)` walks an awk hash in unspecified order -- so every
# prune quietly reshuffled the ledger, and with it the order of `dot scene
# list`, of what `dot scene restore` replays, and of which workspace a
# first-match lookup calls "the" one for a scene. It was guarding against a
# duplicate that mktemp had already made impossible.
#
# Keyed on the scene's *own* windows, not on the workspace having anything at
# all: an entry that outlives its windows is how `close` ends up destroying
# whatever you have since put there.
prune_scenes() {
  stage_previous_session
  [ -f "$STATE_FILE" ] || return 0
  local tmp ws name ids live; tmp="$(mktemp)"
  live="$($AEROSPACE list-windows --all --format '%{window-id}' 2>/dev/null)"
  while IFS=$'\t' read -r ws name ids; do
    [ -n "${ws:-}" ] || continue
    [ -n "$(scene_live_windows "$ws" "$live")" ] && printf '%s\t%s\t%s\n' "$ws" "$name" "$ids"
  done < "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

scene_of() {         # <workspace> -> scene name, or empty
  [ -f "$STATE_FILE" ] || return 0
  awk -F'\t' -v w="$1" '$1 == w { print $2; exit }' "$STATE_FILE"
}

# --- reading, for anyone who is not scene.sh ------------------------------

# Every row, untouched. Deliberately does not prune: pruning asks AeroSpace
# about every scene's windows and rewrites the file, which is not something a
# read should do -- and every writer prunes already.
ledger_rows() { [ -f "$STATE_FILE" ] && cat "$STATE_FILE"; }

# The workspaces a named scene is open on, comma-separated.
workspaces_of() {    # <scene>
  awk -F'\t' -v s="$1" '$2 == s { print $1 }' "$STATE_FILE" 2>/dev/null | paste -sd ', ' -
}

# The window ids recorded for a workspace, comma-separated as stored.
ids_of() {           # <workspace>
  awk -F'\t' -v w="$1" '$1 == w { print $3; exit }' "$STATE_FILE" 2>/dev/null
}

# The previous session's rows, staging them aside first if the ledger predates
# this boot. Callers get "<workspace>\t<scene>"; the window ids are gone with
# the machine and mean nothing now.
previous_session_rows() {
  stage_previous_session
  [ -f "$PREV_FILE" ] && cut -f1,2 "$PREV_FILE"
}
forget_previous_session() { rm -f "$PREV_FILE"; }

# --- writing --------------------------------------------------------------

# Drop every row for a named scene. `forget_scene` is by workspace; this is the
# other axis, wanted when a scene is deleted or renamed out from under itself.
ledger_forget_scene() {   # <scene>
  [ -f "$STATE_FILE" ] || return 0
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v s="$1" '$2 != s' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

ledger_rename_scene() {   # <old> <new>
  [ -f "$STATE_FILE" ] || return 0
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v o="$1" -v n="$2" 'BEGIN{OFS="\t"} $2 == o { $2 = n } 1' \
    "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}
