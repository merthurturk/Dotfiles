#!/usr/bin/env bash
#
# Now-playing chip for Apple Music.
#
# Read over AppleScript rather than sketchybar's media_change event: macOS 15.4
# restricted the MediaRemote APIs that event is built on, so it can't be relied
# on here. media_change is still subscribed as a bonus instant trigger.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"


# Hover: only the border changes, so the state-driven fill below is untouched.
# mouse.exited deliberately falls through to the normal repaint, which restores
# the correct border for whatever state the item is in.
if [ "$SENDER" = "mouse.entered" ]; then
  sketchybar --animate sin 8 --set "$NAME" background.border_color="$BLUE"
  exit 0
fi

# What is playing, for anything that wants it without paying for the
# AppleScript round-trip again. `dot music focus --describe` was doing its own,
# on every ⌥space: ~130ms, the single most expensive thing on that path, for an
# answer this plugin already has and refreshes every 5s.
NOW_PLAYING="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/now-playing"
publish() { mkdir -p "$(dirname "$NOW_PLAYING")"; printf '%s\n' "$1" > "$NOW_PLAYING"; }

hide() { publish ""; sketchybar --set "$NAME" drawing=off; exit 0; }

# Never launch Music just to ask what it's playing.
pgrep -x Music >/dev/null 2>&1 || hide

# Unit separator: track and artist names can legitimately contain "|" or "-".
SEP=$'\x1f'
RAW="$(osascript -e '
tell application "Music"
  set s to player state as text
  if s is "playing" or s is "paused" then
    return s & (ASCII character 31) & (artist of current track) & (ASCII character 31) & (name of current track)
  else
    return s & (ASCII character 31) & (ASCII character 31)
  end if
end tell' 2>/dev/null)"

[ -z "$RAW" ] && hide

STATE="${RAW%%${SEP}*}"
REST="${RAW#*${SEP}}"
ARTIST="${REST%%${SEP}*}"
TRACK="${REST#*${SEP}}"

# Same music glyph either way; play/pause is carried by colour so the chip
# always reads as "music" at a glance.
ICON="󰝚"
case "$STATE" in
  playing) ICON_COLOR="$GREEN"    FG="$TEXT" ;;
  paused)  ICON_COLOR="$OVERLAY1" FG="$SUBTEXT" ;;
  *)       hide ;;
esac

[ -z "$TRACK" ] && hide

LABEL="$TRACK"
[ -n "$ARTIST" ] && LABEL="$ARTIST — $TRACK"

# Keep the chip from crowding out the workspace pills on a long title.
MAX=28
if [ ${#LABEL} -gt $MAX ]; then
  LABEL="$(printf '%.*s' $((MAX - 1)) "$LABEL")…"
fi

publish "$ARTIST — $TRACK"

# border_color is set here too, so a mouse.exited repaint clears the hover ring.
sketchybar --set "$NAME" drawing=on \
                         icon="$ICON" \
                         icon.color="$ICON_COLOR" \
                         label="$LABEL" \
                         label.color="$FG" \
                         background.border_color="$GROUP_BORDER"
