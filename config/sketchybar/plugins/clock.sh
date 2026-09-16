#!/usr/bin/env bash
#
# Date, time, and what is next — one label.
#
# These were two chips, and they were cut along the wrong seam: the clock
# carried the date while the calendar chip carried a time. Both are "when".
# Now the whole of "when" is one sentence, and the status group keeps the
# machine's own state (volume, battery) beside it.
#
# Two items, one pill: they share the status bracket, so it still reads as the
# single label it was designed as, but the clock can be bold and the event dim.
# It had to be split -- sketchybar styles an item, not part of a label, and with
# one label the eye went to the *meeting* time and read it as the current time.
#
# Reads what the resident calendar helper published; see
# launchd/sh.dotfiles.calendar. Nothing is queried here, so this stays two
# sketchybar calls on a 15-second timer.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"

NEXT_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/next-event.tsv"
WHEN="$(date '+%a %d %b  %H:%M')"
EVENT=""

# No event: a clock is a clock. The icon is the only thing that changes shape,
# so the pill does not resize just because the day is empty.
ICON="󰅐"; ICON_COLOR="$MAUVE"

if [ -s "$NEXT_FILE" ]; then
  # Every field, including the join URL: `read` gives the remainder of the
  # line to its last variable, so leaving one out put the URL in the title.
  IFS=$'\t' read -r START _END ALLDAY _CAL TITLE _JOIN < "$NEXT_FILE"
  if [ -n "${TITLE:-}" ] && [ "${ALLDAY:-1}" = "0" ]; then
    NOW="$(date +%s)"
    MINS=$(( (START - NOW + 59) / 60 ))

    # Three states. "Starts in four minutes" and "you are already late" want
    # different colours far more than they want different words.
    if [ "$NOW" -ge "$START" ]; then
      AT="now";            ICON="󰃰"; ICON_COLOR="$GREEN"
    elif [ "$MINS" -le 5 ]; then
      AT="${MINS}m";       ICON="󰃰"; ICON_COLOR="$PEACH"
    elif [ "$MINS" -lt 60 ]; then
      AT="${MINS}m";       ICON="󰃰"; ICON_COLOR="$BLUE"
    else
      AT="$(date -r "$START" '+%H:%M')"; ICON="󰃰"; ICON_COLOR="$BLUE"
    fi

    # Truncate the title, never the date or the time: the part that is always
    # true should not be the part that gets cut.
    MAX=34
    [ ${#TITLE} -gt $MAX ] && TITLE="$(printf '%.*s' $((MAX - 1)) "$TITLE")…"
    EVENT="→ $AT $TITLE"
  fi
fi

# The clock is the loud one: full-strength text, bold. The event is context,
# so it sits dimmer and lighter beside it -- which is the whole point of the
# split. A dim label with nothing in it draws nothing and takes no width.
sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR"                          label="$WHEN" label.color="$TEXT"            --set calevent label="$EVENT" label.color="$OVERLAY1"                           label.drawing="$([ -n "$EVENT" ] && echo on || echo off)"
