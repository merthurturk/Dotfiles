#!/usr/bin/env bash
#
# Scene launcher
#
# A bar item. Sourced by sketchybarrc from every directory on
# SKETCHY_ITEM_PATH, in name order -- so `10-` draws before `20-`, and your own
# file in ~/.config/dot/sketchybar/items joins them without touching this repo.
#
# Everything is already in scope: $PLUGIN_DIR, the geometry ($PILL_RADIUS,
# $PILL_HEIGHT, $ITEM_PADDING), every colour from colors.sh and every font from
# fonts.sh. To join an existing pill, append your item name to the matching
# BRACKET_<name> variable; sketchybarrc materialises the brackets afterwards.

# Leftmost so it reads as a launcher. Left click opens a named window layout on
# an empty workspace; right click closes it. See ~/.config/aerospace/scene.sh

sketchybar --add item scene left \
           --set scene icon="󰅶" \
                 icon.font="$ICON_FONT:Bold:16.0" \
                 icon.color="$PEACH" \
                 icon.padding_left=10 \
                 icon.padding_right=10 \
                 label.drawing=off \
                 background.color="$GROUP_BG" \
                 background.border_color="$GROUP_BORDER" \
                 script="$PLUGIN_DIR/hover.sh" \
                 click_script="$PLUGIN_DIR/scene_click.sh" \
           --subscribe scene mouse.entered mouse.exited
