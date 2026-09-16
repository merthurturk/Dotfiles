#!/usr/bin/env bash
#
# Front app
#
# A bar item. Sourced by sketchybarrc from every directory on
# SKETCHY_ITEM_PATH, in name order -- so `10-` draws before `20-`, and your own
# file in ~/.config/dot/sketchybar/items joins them without touching this repo.
#
# Everything is already in scope: $PLUGIN_DIR, the geometry ($PILL_RADIUS,
# $PILL_HEIGHT, $ITEM_PADDING), every colour from colors.sh and every font from
# fonts.sh. To join an existing pill, append your item name to the matching
# BRACKET_<name> variable; sketchybarrc materialises the brackets afterwards.

sketchybar --add item separator left \
           --set separator icon="│" \
                 icon.color="$SURFACE2" \
                 icon.font="$FONT_REGULAR:14.0" \
                 label.drawing=off \
                 padding_left=6 \
                 padding_right=6

sketchybar --add item front_app left \
           --set front_app icon.font="$APP_FONT" \
                 icon.color="$MAUVE" \
                 label.font="$FONT_BOLD:13.0" \
                 label.color="$TEXT" \
                 script="$PLUGIN_DIR/front_app.sh" \
           --subscribe front_app front_app_switched
