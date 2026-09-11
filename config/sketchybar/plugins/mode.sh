#!/usr/bin/env bash
#
# Shows an indicator while AeroSpace is in a non-main binding mode.
# Invoked from ~/.aerospace.toml as: mode.sh <mode-name>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

MODE="${1:-main}"

if [ "$MODE" = "main" ]; then
  sketchybar --set aerospace_mode drawing=off
else
  sketchybar --set aerospace_mode drawing=on \
                                  label="$(echo "$MODE" | tr '[:lower:]' '[:upper:]')"
fi
