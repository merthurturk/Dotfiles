#!/usr/bin/env bash
#
# Synthwave -- neon on a night sky.
#
# Not an Opal variant. Opal is quiet by design: pale surfaces, colour kept for
# the things that carry meaning. This is the opposite argument -- the colour
# *is* the point -- so it breaks the family's rules deliberately and says so
# here. Two in particular:
#
#   * the bar gets a surface again -- though still no border. An Opal theme
#     lets its chips float on the wallpaper, which works over a quiet wash and
#     not at all over a sunset and a glowing grid: the items with no background
#     of their own (the app name, the separator) would sit straight on top of
#     it. The fill is what does that work; the outline was redundant.
#   * the wallpaper is a composition, not a wash. WALLPAPER_STYLE picks it.

# Surfaces, darkest to lightest
export BASE=0xff180d2e
export MANTLE=0xff211338
export CRUST=0xff100821
export SURFACE0=0xff2b1a4a
export SURFACE1=0xff3d2666
export SURFACE2=0xff533485
export OVERLAY0=0xff7b5bb0
export OVERLAY1=0xff9d7ed0

# Foregrounds
export TEXT=0xfff2e9ff
export SUBTEXT=0xffc0a8e8

# Accents. Neon, and left bright on purpose -- on a near-black surface the
# contrast problem is the opposite of a light theme's: these are the colours
# text is *made of*, and anything they fill gets dark text on top.
export ROSEWATER=0xffffb3d9
export FLAMINGO=0xffff8fc7
export PINK=0xffff2e97
export MAUVE=0xffb967ff
export RED=0xffff3864
export MAROON=0xffff5470
export PEACH=0xffff8c42
export YELLOW=0xffffd23f
export GREEN=0xff39ff8b
export TEAL=0xff1fe0c4
export SKY=0xff2de2e6
export SAPPHIRE=0xff22c9ee
export BLUE=0xff4d9fff
export LAVENDER=0xffc4a7ff

export TRANSPARENT=0x00000000

# Bar. A surface, unlike the Opal themes -- see the note at the top -- but no
# border on it: against a night sky the fill already separates the bar from the
# wallpaper, and an outline on top of that is one edge too many.
export BAR_COLOR=$MANTLE
export BAR_BORDER_COLOR=$TRANSPARENT

# Grouped status items on the right
export GROUP_BG=$SURFACE0
export GROUP_BORDER=$SURFACE1

# Workspace pill states
export WS_ACTIVE_BG=$PINK
export WS_ACTIVE_FG=$CRUST
export WS_ACTIVE_BORDER=$PINK
export WS_OCCUPIED_BG=$SURFACE0
export WS_OCCUPIED_FG=$TEXT
export WS_OCCUPIED_BORDER=$SURFACE1

# Scene badges. Dark theme, so the triplets invert: _TINT is a dark wash and
# _DEEP is the neon on top of it.
export BADGE_PEACH_TINT=0xff452611
export BADGE_PEACH_EDGE=0xff573b29
export BADGE_PEACH_DEEP=0xffff8c42
export BADGE_TEAL_TINT=0xff183f39
export BADGE_TEAL_EDGE=0xff2f514c
export BADGE_TEAL_DEEP=0xff1fe0c4
export BADGE_MAUVE_TINT=0xff2d1145
export BADGE_MAUVE_EDGE=0xff422957
export BADGE_MAUVE_DEEP=0xffb967ff
export BADGE_BLUE_TINT=0xff112945
export BADGE_BLUE_EDGE=0xff293e57
export BADGE_BLUE_DEEP=0xff4d9fff
export BADGE_GREEN_TINT=0xff114527
export BADGE_GREEN_EDGE=0xff29573c
export BADGE_GREEN_DEEP=0xff39ff8b

# Window outlines. Magenta focused, so the focused window and the focused
# workspace pill are the same colour.
export WINDOW_BORDER_ACTIVE=$PINK
export WINDOW_BORDER_INACTIVE=$SURFACE2

# Wallpaper: the sun, the horizon and the grid. Colours in order --
# sun top, sun bottom, grid, sky glow.
export WALLPAPER_STYLE=grid
export WALLPAPER_ACCENTS="YELLOW PINK SKY MAUVE"
