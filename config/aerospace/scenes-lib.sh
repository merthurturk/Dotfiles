#!/usr/bin/env bash
#
# What a scene is, and where that answer comes from.
#
# `scenes.json` is version-controlled examples; `scenes.local.json` is yours,
# gitignored, and merged over it. A `null` in the local file is a tombstone --
# how you delete a scene you did not write, since removing the key would only
# let the shipped one back in on the next merge.
#
# That rule used to be written out in four places: scene.sh, window-reflow,
# scene-list and the bar's workspace plugin. Three were converted to ask
# scene.sh; the bar was left because it is on the repaint path and asking costs
# a process. This file is the answer to that -- it is sourced, not executed, so
# there is one implementation and no fork.
#
# Both caches are rebuilt together from one jq, and invalidated by either input
# or by this file itself being newer. That last one matters: change the merge
# rule and every consumer would otherwise keep the old answer until someone
# happened to touch a scene.

_SCENES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENES_SHIPPED="$_SCENES_LIB_DIR/scenes.json"
SCENES_LOCAL="$_SCENES_LIB_DIR/scenes.local.json"
_SCENES_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
SCENES_CACHE="$_SCENES_STATE/scenes-merged.json"
SCENES_DEFS_CACHE="$_SCENES_STATE/scenes-defs.tsv"
SCENES_SUMMARY_CACHE="$_SCENES_STATE/scenes-summary.tsv"

scenes_cache_clear() { rm -f "$SCENES_CACHE" "$SCENES_DEFS_CACHE" "$SCENES_SUMMARY_CACHE"; }

# Rebuild both caches unless they are newer than everything they derive from.
_scenes_refresh() {
  [ -s "$SCENES_CACHE" ] && [ -f "$SCENES_DEFS_CACHE" ] && [ -f "$SCENES_SUMMARY_CACHE" ] \
    && [ ! "$SCENES_SHIPPED" -nt "$SCENES_CACHE" ] \
    && [ ! "$SCENES_LOCAL"   -nt "$SCENES_CACHE" ] \
    && [ ! "${BASH_SOURCE[0]}" -nt "$SCENES_CACHE" ] && return 0

  mkdir -p "$_SCENES_STATE"
  local tmp; tmp="$(mktemp)"
  if [ -f "$SCENES_LOCAL" ]; then
    jq -s '.[0] * .[1] | with_entries(select(.value != null))' \
       "$SCENES_SHIPPED" "$SCENES_LOCAL" > "$tmp" 2>/dev/null
  else
    jq '.' "$SCENES_SHIPPED" > "$tmp" 2>/dev/null
  fi
  [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }

  # Two derived views, built here because both are read on latency paths: the
  # bar wants TSV on every workspace switch, and the launcher wants the window
  # summary on every ⌥space. Deriving them now means neither path runs jq.
  local dtmp stmp; dtmp="$(mktemp)"; stmp="$(mktemp)"
  jq -r 'to_entries[] | ["D", .key, (.value.icon // ""), (.value.label // .key),
                         (.value.badge // "BLUE")] | @tsv' "$tmp" > "$dtmp" 2>/dev/null
  jq -r '
    to_entries[]
    | .key + "\t" + ([ .value.windows[]
        # Only a chrome spec holds several space-separated URLs. Trimming an
        # app spec at the first space turned "T3 Code (Alpha)" into "T3".
        | if startswith("app:") then sub("^app:"; "")
          else sub("^chrome(-app)?:https?://(www\\.)?"; "")
               | split(" ")[0] | split("/")[0] end ] | join(" + "))' \
    "$tmp" > "$stmp" 2>/dev/null
  mv "$tmp" "$SCENES_CACHE"; mv "$dtmp" "$SCENES_DEFS_CACHE"; mv "$stmp" "$SCENES_SUMMARY_CACHE"
}

# The merged definitions, as JSON.
scenes_merged() { _scenes_refresh && cat "$SCENES_CACHE" || echo '{}'; }

# The merged definitions as "D<TAB>key<TAB>icon<TAB>label<TAB>badge", which is
# exactly what the bar's single awk pass consumes.
scenes_defs_tsv() { _scenes_refresh && cat "$SCENES_DEFS_CACHE"; }

# "<scene><TAB><what its windows are>", for the launcher's detail column.
scenes_summary_tsv() { _scenes_refresh && cat "$SCENES_SUMMARY_CACHE"; }
