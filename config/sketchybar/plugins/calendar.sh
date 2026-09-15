#!/usr/bin/env bash
#
# What's next, in the bar.
#
# Draws only when there is something within the horizon -- an empty afternoon
# should be an empty bar, not the word "nothing". Same rule as the now-playing
# chip beside it.
#
# The helper reads EventKit, which is the local store macOS Calendar syncs into,
# so a Google account added under Internet Accounts shows up with no OAuth and
# no secret in this repo. AppleScript to Calendar.app would need neither, but it
# takes five seconds per query; see config/aerospace/src/calendar.swift.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"

if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --animate sin 8 --set "$NAME" background.border_color="$BLUE"
  exit 0
fi

CAL="$HOME/.config/aerospace/bin/DotCalendar.app/Contents/MacOS/DotCalendar"
NEXT_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/next-event"

hide() { : > "$NEXT_FILE" 2>/dev/null; sketchybar --set "$NAME" drawing=off; exit 0; }

[ -x "$CAL" ] || hide
mkdir -p "$(dirname "$NEXT_FILE")"

# <start epoch>\t<end epoch>\t<all-day>\t<calendar>\t<title>, or nothing at all.
ROW="$("$CAL" next --within 240 2>/dev/null)"
[ -n "$ROW" ] || hide

IFS=$'\t' read -r START _END _ALLDAY _CAL TITLE <<<"$ROW"
[ -n "${TITLE:-}" ] || hide

NOW="$(date +%s)"
MINS=$(( (START - NOW + 59) / 60 ))

# Three states, because "starts in 40 minutes" and "you are late" want
# different colours far more than they want different words.
if [ "$NOW" -ge "$START" ]; then
  WHEN="now"; ICON_COLOR="$GREEN"; FG="$TEXT"
elif [ "$MINS" -le 5 ]; then
  WHEN="${MINS}m"; ICON_COLOR="$PEACH"; FG="$TEXT"
else
  if [ "$MINS" -ge 60 ]; then WHEN="$(date -r "$START" '+%H:%M')"; else WHEN="${MINS}m"; fi
  ICON_COLOR="$BLUE"; FG="$SUBTEXT"
fi

# Remaining minutes, for anything that wants the same answer without paying for
# the helper again -- the launcher reads this.
printf '%s\t%s\t%s\n' "$START" "$WHEN" "$TITLE" > "$NEXT_FILE"

MAX=26
LABEL="$WHEN · $TITLE"
[ ${#LABEL} -gt $MAX ] && LABEL="$(printf '%.*s' $((MAX - 1)) "$LABEL")…"

sketchybar --set "$NAME" drawing=on \
                         icon="󰃰" \
                         icon.color="$ICON_COLOR" \
                         label="$LABEL" \
                         label.color="$FG" \
                         background.border_color="$GROUP_BORDER"
