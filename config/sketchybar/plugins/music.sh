#!/usr/bin/env bash
#
# Now-playing chip for Apple Music.
#
# Read over AppleScript rather than sketchybar's media_change event: macOS 15.4
# restricted the MediaRemote APIs that event is built on, so it can't be relied
# on here. media_change is still subscribed as a bonus instant trigger.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"

hide() { sketchybar --set "$NAME" drawing=off; exit 0; }

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

sketchybar --set "$NAME" drawing=on \
                         icon="$ICON" \
                         icon.color="$ICON_COLOR" \
                         label="$LABEL" \
                         label.color="$FG"
