#!/usr/bin/env bash
#
# Binding mode indicator
#
# A bar item. Sourced by sketchybarrc from every directory on
# SKETCHY_ITEM_PATH, in name order -- so `10-` draws before `20-`, and your own
# file in ~/.config/dot/sketchybar/items joins them without touching this repo.
#
# Everything is already in scope: $PLUGIN_DIR, the geometry ($PILL_RADIUS,
# $PILL_HEIGHT, $ITEM_PADDING), every colour from colors.sh and every font from
# fonts.sh. To join an existing pill, append your item name to the matching
# BRACKET_<name> variable; sketchybarrc materialises the brackets afterwards.

sketchybar --add item aerospace_mode left \
           --set aerospace_mode drawing=off \
                 icon="󰘳" \
                 icon.color="$BASE" \
                 label.color="$BASE" \
                 label.font="$FONT_BOLD:12.0" \
                 background.color="$MAROON" \
                 background.border_color="$MAROON"
