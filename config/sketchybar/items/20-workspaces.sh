#!/usr/bin/env bash
#
# AeroSpace workspaces
#
# A bar item. Sourced by sketchybarrc from every directory on
# SKETCHY_ITEM_PATH, in name order -- so `10-` draws before `20-`, and your own
# file in ~/.config/dot/sketchybar/items joins them without touching this repo.
#
# Everything is already in scope: $PLUGIN_DIR, the geometry ($PILL_RADIUS,
# $PILL_HEIGHT, $ITEM_PADDING), every colour from colors.sh and every font from
# fonts.sh. To join an existing pill, append your item name to the matching
# BRACKET_<name> variable; sketchybarrc materialises the brackets afterwards.

sketchybar --add event aerospace_workspace_change

for ws in $(aerospace list-workspaces --all); do
  sketchybar --add item space."$ws" left \
             --set space."$ws" \
                   icon="$ws" \
                   icon.font="$FONT_BOLD:14.0" \
                   icon.padding_left=9 \
                   icon.padding_right=5 \
                   label.font="$APP_FONT" \
                   label.padding_right=9 \
                   label.y_offset=-1 \
                   background.color="$WS_OCCUPIED_BG" \
                   background.border_color="$WS_OCCUPIED_BORDER" \
                   drawing=off \
                   script="$PLUGIN_DIR/hover.sh" \
                   click_script="aerospace workspace $ws" \
             --subscribe space."$ws" mouse.entered mouse.exited
done

# Hidden driver item: one script call repaints every pill above.
#
# The event-bridge agent covers the fast paths (workspace switches, new windows,
# focus moves -- including the focus change that follows moving the focused
# window to another workspace). AeroSpace emits no event at all for a window
# being closed, or for one moved by id from a script, so a slow poll backstops
# those rather than leaving the bar stale.
sketchybar --add item spaces_watcher left \
           --set spaces_watcher drawing=off \
                 update_freq=5 \
                 script="$PLUGIN_DIR/aerospace.sh" \
           --subscribe spaces_watcher aerospace_workspace_change \
                                      front_app_switched \
                                      space_windows_change \
                                      display_change
