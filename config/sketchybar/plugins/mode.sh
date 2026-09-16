#!/usr/bin/env bash
#
# Shows an indicator while AeroSpace is in a non-main binding mode.
# Invoked from config/aerospace/event-bridge.sh on a mode-changed event --
# aerospace.toml's on-mode-changed is empty, because the bridge subscribes to
# the event stream once instead of every binding carrying its own trigger.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

MODE="${1:-main}"

if [ "$MODE" = "main" ]; then
  sketchybar --set aerospace_mode drawing=off
else
  sketchybar --set aerospace_mode drawing=on \
                                  label="$(echo "$MODE" | tr '[:lower:]' '[:upper:]')"
fi
