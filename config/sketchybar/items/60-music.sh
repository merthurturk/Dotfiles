#!/usr/bin/env bash
#
# Now playing
#
# A bar item. Sourced by sketchybarrc from every directory on
# SKETCHY_ITEM_PATH, in name order -- so `10-` draws before `20-`, and your own
# file in ~/.config/dot/sketchybar/items joins them without touching this repo.
#
# Everything is already in scope: $PLUGIN_DIR, the geometry ($PILL_RADIUS,
# $PILL_HEIGHT, $ITEM_PADDING), every colour from colors.sh and every font from
# fonts.sh. To join an existing pill, append your item name to the matching
# BRACKET_<name> variable; sketchybarrc materialises the brackets afterwards.

sketchybar --add item music right \
           --set music update_freq=5 \
                 drawing=off \
                 icon.padding_left=10 \
                 label.padding_right=12 \
                 background.color="$GROUP_BG" \
                 background.border_color="$GROUP_BORDER" \
                 script="$PLUGIN_DIR/music.sh" \
                 click_script="$PLUGIN_DIR/music_click.sh" \
           --subscribe music media_change mouse.entered mouse.exited
