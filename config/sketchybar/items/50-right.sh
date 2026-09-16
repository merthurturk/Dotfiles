#!/usr/bin/env bash
#
# Right side
#
# A bar item. Sourced by sketchybarrc from every directory on
# SKETCHY_ITEM_PATH, in name order -- so `10-` draws before `20-`, and your own
# file in ~/.config/dot/sketchybar/items joins them without touching this repo.
#
# Everything is already in scope: $PLUGIN_DIR, the geometry ($PILL_RADIUS,
# $PILL_HEIGHT, $ITEM_PADDING), every colour from colors.sh and every font from
# fonts.sh. To join an existing pill, append your item name to the matching
# BRACKET_<name> variable; sketchybarrc materialises the brackets afterwards.

# Added right-to-left: the clock ends up furthest right, music furthest left.

# Date, time and what is next. Two items sharing the status bracket, so they
# read as one pill while the clock can be bold and the event dim -- with one
# label the eye went to the meeting time and read it as the current time.
# calevent is added first, so it ends up to the right of the clock.
sketchybar --add item calevent right \
           --set calevent drawing=on label.drawing=off \
                 label.font="$FONT_REGULAR:13.0" \
                 label.padding_left=0 \
                 padding_left=0 \
                 label.padding_right=12 \
                 click_script="$HOME/.local/bin/dot calendar agenda --pick" \
           --add item clock right \
           --set clock update_freq=15 \
                 icon="󰅐" \
                 icon.color="$MAUVE" \
                 label.font="$FONT_BOLD:13.0" \
                 label.padding_right=0 \
                 padding_right=0 \
                 script="$PLUGIN_DIR/clock.sh" \
                 click_script="$HOME/.local/bin/dot calendar agenda --pick" \
           --subscribe clock system_woke \
           --add item battery right \
           --set battery update_freq=120 \
                 script="$PLUGIN_DIR/battery.sh" \
           --subscribe battery system_woke power_source_change \
           --add item volume right \
           --set volume icon.color="$TEAL" \
                 script="$PLUGIN_DIR/volume.sh" \
           --subscribe volume volume_change

# Declared, not created: sketchybarrc materialises every bracket after all the
# item files have run, so an item in another file -- including one of yours --
# can join this pill by appending its name here too.
# shellcheck disable=SC2034  # consumed by sketchybarrc after every item runs
BRACKET_status="volume battery clock calevent"
