#!/usr/bin/env bash
#
# Translates AeroSpace's event stream into SketchyBar triggers.
#
# This replaces ~40 hand-wired `exec-and-forget sketchybar --trigger` calls that
# previously had to be repeated on every single binding -- one per workspace
# move, plus the workspace-change callback, plus one per service-mode binding.
#
# It also picks up `window-detected`, which no binding could provide: a window
# opening without its app becoming frontmost was invisible to the bar.
#
# AeroSpace emits no window-closed event (verified), so `focus-changed` is
# subscribed as the proxy for it -- focus always moves when a window goes away.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
LOG="$STATE_DIR/log"
mkdir -p "$STATE_DIR"

log() { printf '%s  bridge: %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# Repaint once up front: --no-send-initial suppresses the synthetic burst, and
# sketchybar may have started before us.
sketchybar --trigger aerospace_workspace_change 2>/dev/null

# --no-send-initial: we repainted above, and don't want a burst of synthetic
# events replaying old state.
# One long-lived jq reformats the whole stream into "<event>\t<workspace>".
# Parsing each line with its own jq meant a process spawn per event, on a path
# that fires every time focus moves.
aerospace subscribe --no-send-initial \
    focused-workspace-changed window-detected focus-changed mode-changed \
    2>>"$LOG" \
  | jq -r --unbuffered '[._event, (.workspace // ""), (.mode // "")] | @tsv' \
    2>>"$LOG" \
  | while IFS=$'\t' read -r event ws mode; do
      [ -n "$event" ] || continue
      case "$event" in
        mode-changed)
          "$HOME/.config/sketchybar/plugins/mode.sh" "${mode:-main}"
          ;;
        *)
          if [ -n "$ws" ]; then
            sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$ws"
          else
            sketchybar --trigger aerospace_workspace_change
          fi
          ;;
      esac
    done

log "event stream ended (aerospace restarted or stopped); launchd will respawn"
