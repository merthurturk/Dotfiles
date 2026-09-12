#!/usr/bin/env bash
#
# Opal Fire -- the warm one.
#
# Fire opal is a milky stone with orange burning through it: the surfaces are
# cream rather than off-white, and the accent that means "here" is terracotta
# rather than blue. Same family as Opal White -- same structure, same
# transparent bar, same outlines -- but it should never be mistaken for it at
# a glance, which is why the surfaces carry the warmth too and not just the
# accents.

# Surfaces, lightest to darkest
export BASE=0xfffbf0e2
export MANTLE=0xfff4e5d3
export CRUST=0xffead8c2
export SURFACE0=0xffe7d2b9
export SURFACE1=0xffd6ba9a
export SURFACE2=0xffc2a181
export OVERLAY0=0xffa3805d
export OVERLAY1=0xff88684a

# Foregrounds
export TEXT=0xff443328
export SUBTEXT=0xff796251

# Accents
export ROSEWATER=0xffb96f4e
export FLAMINGO=0xffbb5f45
export PINK=0xffb74d76
export MAUVE=0xff8b4fae
export RED=0xffc0301f
export MAROON=0xffab3733
export PEACH=0xffaf5110
export YELLOW=0xffa87a0a
export GREEN=0xff5c7a24
export TEAL=0xff2a7a63
export SKY=0xff2f7d94
export SAPPHIRE=0xff336f8a
export BLUE=0xff3a68b4
export LAVENDER=0xff8878c8

export TRANSPARENT=0x00000000

# Bar
#
# No surface of its own -- an Opal theme lets the chips float on the
# wallpaper. This is the family trait.
export BAR_COLOR=$TRANSPARENT
export BAR_BORDER_COLOR=$TRANSPARENT

# Grouped status items on the right
export GROUP_BG=$MANTLE
export GROUP_BORDER=$SURFACE0

# Workspace pill states
export WS_ACTIVE_BG=$PEACH
export WS_ACTIVE_FG=$BASE
export WS_ACTIVE_BORDER=$PEACH
export WS_OCCUPIED_BG=$CRUST
export WS_OCCUPIED_FG=$TEXT
export WS_OCCUPIED_BORDER=$SURFACE0

# Scene badges. _TINT is the unfocused fill, _EDGE the tint stepped one
# further from the background so the chip has a shape without an outline, and
# _DEEP carries text on the tint -- then becomes the fill when the scene is
# focused, with BASE on top. Measured by bin/check-themes.sh.
export BADGE_PEACH_TINT=0xffefe1d7
export BADGE_PEACH_EDGE=0xffddd2ca
export BADGE_PEACH_DEEP=0xffa24b0f
export BADGE_TEAL_TINT=0xffdceae6
export BADGE_TEAL_EDGE=0xffced9d6
export BADGE_TEAL_DEEP=0xff27725d
export BADGE_MAUVE_TINT=0xffe4dee8
export BADGE_MAUVE_EDGE=0xffd4d0d8
export BADGE_MAUVE_DEEP=0xff824aa3
export BADGE_BLUE_TINT=0xffdce1ea
export BADGE_BLUE_EDGE=0xffced2d9
export BADGE_BLUE_DEEP=0xff3661a8
export BADGE_GREEN_TINT=0xffe5ebdb
export BADGE_GREEN_EDGE=0xffd5dacd
export BADGE_GREEN_DEEP=0xff546f21

# Window outlines. The focused window takes the same accent as the focused
# workspace pill, so "where am I" is one colour everywhere.
export WINDOW_BORDER_ACTIVE=$PEACH
export WINDOW_BORDER_INACTIVE=$SURFACE1

# Wallpaper. Warm only -- no blue, no teal. With the cool accents in here the
# stone came out looking like Opal White with a warm corner.
export WALLPAPER_ACCENTS="PEACH MAROON YELLOW ROSEWATER"
