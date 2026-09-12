#!/usr/bin/env bash
#
# Opal Black -- the dark one.
#
# Black opal has a dark body with blue, green and violet firing out of it.
# Near-black surfaces carrying a little violet, and accents that are vivid
# precisely because there is so little else competing. The badge triplets
# invert: _TINT is a dark wash and _DEEP is the bright colour on top of it.

# Surfaces, darkest to lightest
export BASE=0xff15141d
export MANTLE=0xff1c1a26
export CRUST=0xff100f17
export SURFACE0=0xff262232
export SURFACE1=0xff342f45
export SURFACE2=0xff443e59
export OVERLAY0=0xff6c6488
export OVERLAY1=0xff8f86a9

# Foregrounds
export TEXT=0xffe9e5f4
export SUBTEXT=0xffada5c4

# Accents
export ROSEWATER=0xfff2c9c2
export FLAMINGO=0xfff0b3ae
export PINK=0xffff9ac8
export MAUVE=0xffbd9af8
export RED=0xfff7768e
export MAROON=0xffff7a93
export PEACH=0xffff9e64
export YELLOW=0xffe8b972
export GREEN=0xff9ede6d
export TEAL=0xff4fd6be
export SKY=0xff7dcfff
export SAPPHIRE=0xff35c4dd
export BLUE=0xff7aa2f7
export LAVENDER=0xffa8b2f9

export TRANSPARENT=0x00000000

# Bar
#
# No surface of its own -- an Opal theme lets the chips float on the
# wallpaper. This is the family trait; a variant that wants a bar-shaped
# surface back just gives these two a colour.
export BAR_COLOR=$TRANSPARENT
export BAR_BORDER_COLOR=$TRANSPARENT

# Grouped status items on the right
export GROUP_BG=$MANTLE
export GROUP_BORDER=$SURFACE1

# Workspace pill states
export WS_ACTIVE_BG=$BLUE
export WS_ACTIVE_FG=$CRUST
export WS_ACTIVE_BORDER=$BLUE
export WS_OCCUPIED_BG=$SURFACE0
export WS_OCCUPIED_FG=$TEXT
export WS_OCCUPIED_BORDER=$SURFACE1

# Scene badges.
#
# Three values, not one: _TINT is the unfocused fill, _EDGE is the tint
# stepped one further from the background so the chip has a shape without
# an outline, and _DEEP carries text on the tint -- then becomes the fill
# when the scene is focused, with BASE on top of it. Every pair below was
# computed, not chosen: bin/check-themes.sh measures them.
export BADGE_PEACH_TINT=0xff432514
export BADGE_PEACH_EDGE=0xff4f382b
export BADGE_PEACH_DEEP=0xffff9e64
export BADGE_TEAL_TINT=0xff1d3a35
export BADGE_TEAL_EDGE=0xff324845
export BADGE_TEAL_DEEP=0xff4fd6be
export BADGE_MAUVE_TINT=0xff261740
export BADGE_MAUVE_EDGE=0xff392d4d
export BADGE_MAUVE_DEEP=0xffbd9af8
export BADGE_BLUE_TINT=0xff162440
export BADGE_BLUE_EDGE=0xff2d384e
export BADGE_BLUE_DEEP=0xff7aa2f7
export BADGE_GREEN_TINT=0xff293a1c
export BADGE_GREEN_EDGE=0xff3c4931
export BADGE_GREEN_DEEP=0xff9ede6d

# Window outlines (JankyBorders). The focused window takes the same accent
# as the focused workspace pill, so "where am I" is one colour everywhere.
export WINDOW_BORDER_ACTIVE=$BLUE
export WINDOW_BORDER_INACTIVE=$SURFACE2

# Wallpaper. Black opal's play-of-colour is blue, green and violet against a
# dark body.
export WALLPAPER_ACCENTS="BLUE MAUVE TEAL PINK"
