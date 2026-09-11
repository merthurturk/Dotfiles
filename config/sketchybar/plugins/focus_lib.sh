#!/usr/bin/env bash
#
# Shared helpers for the Focus indicator and its popup menu.
#
# Reads ~/Library/DoNotDisturb/DB, which is TCC-protected: the sketchybar
# binary needs Full Disk Access. Scripts it spawns inherit that grant.
#
# Schema note: modeConfigurations is an object *keyed by mode identifier*, so
# lookups match on the key rather than a field inside .mode.

DND_DB="$HOME/Library/DoNotDisturb/DB"
FOCUS_ASSERTIONS="$DND_DB/Assertions.json"
FOCUS_MODES="$DND_DB/ModeConfigurations.json"

focus_db_readable() { [ -r "$FOCUS_ASSERTIONS" ] && [ -r "$FOCUS_MODES" ]; }

# "<mode-id>\t<name>" per configured Focus, sorted by display name.
focus_list_modes() {
  jq -r '
    .data[]?.modeConfigurations // {}
    | to_entries[]
    | [.key, (.value.mode.name // .key)] | @tsv
  ' "$FOCUS_MODES" 2>/dev/null | sort -t$'\t' -k2,2
}

# Active mode identifier, or nothing when Focus is off.
# storeInvalidationRecords holds *ended* assertions and must be ignored.
focus_active_id() {
  jq -r '
    [ .data[]?.storeAssertionRecords[]?.assertionDetails.assertionDetailsModeIdentifier ]
    | map(select(. != null)) | first // empty
  ' "$FOCUS_ASSERTIONS" 2>/dev/null
}

focus_name_for() {
  jq -r --arg id "$1" '
    .data[]?.modeConfigurations // {} | to_entries[]
    | select(.key == $id) | .value.mode.name // $id
  ' "$FOCUS_MODES" 2>/dev/null | head -1
}

# Nerd Font glyph per mode. Every codepoint below was verified present in
# HackNerdFont before use, so none of these render as tofu.
focus_glyph() {
  case "$1" in
    *sleep*)          echo "󰒲" ;;
    *workout*)        echo "󰑮" ;;
    *work*)           echo "󰃍" ;;
    *mindfulness*)    echo "󱅻" ;;
    *personal*)       echo "󰀄" ;;
    *reduce*|*default*) echo "󰖔" ;;
    *)                echo "󰂛" ;;
  esac
}

focus_item_name() { echo "focus.m.$(echo "$1" | tr '.' '_')"; }
