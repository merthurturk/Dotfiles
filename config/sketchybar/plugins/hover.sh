#!/usr/bin/env bash
#
# Hover feedback for clickable items.
#
# On enter we only change the *border* colour, never the fill: these items have
# state-driven backgrounds (a focused workspace pill is blue, an occupied one
# grey, the Focus chip mauve when on, transparent when off) and a ring reads
# correctly on all of them without having to know which state we're in.
#
# On exit the item's own updater is re-run rather than restoring a hardcoded
# colour, so the correct state colour comes back.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$CONFIG_DIR/colors.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 8 --set "$NAME" background.border_color="$BLUE"
    ;;

  mouse.exited)
    case "$NAME" in
      space.*)
        # Repaints every pill with its correct state colours.
        sketchybar --trigger aerospace_workspace_change
        ;;
      focus)
        sketchybar --trigger focus_change
        ;;
      *)
        sketchybar --animate sin 8 --set "$NAME" background.border_color="$GROUP_BORDER"
        ;;
    esac
    ;;
esac
