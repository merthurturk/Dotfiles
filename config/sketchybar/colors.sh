#!/usr/bin/env bash
#
# Catppuccin Latte — light theme.
# Accents are the Latte variants, which are darkened relative to Mocha so they
# stay legible on an off-white bar.

# Surfaces, lightest to darkest
export BASE=0xffeff1f5      # bar background
export MANTLE=0xffe6e9ef    # grouped-item background
export CRUST=0xffdce0e8
export SURFACE0=0xffccd0da  # inactive pill
export SURFACE1=0xffbcc0cc  # borders
export SURFACE2=0xffacb0be
export OVERLAY0=0xff9ca0b0
export OVERLAY1=0xff8c8fa1

# Foregrounds
export TEXT=0xff4c4f69
export SUBTEXT=0xff6c6f85

# Accents
export ROSEWATER=0xffdc8a78
export FLAMINGO=0xffdd7878
export PINK=0xffea76cb
export MAUVE=0xff8839ef
export RED=0xffd20f39
export MAROON=0xffe64553
export PEACH=0xfffe640b
export YELLOW=0xffdf8e1d
export GREEN=0xff40a02b
export TEAL=0xff179299
export SKY=0xff04a5e5
export SAPPHIRE=0xff209fb5
export BLUE=0xff1e66f5
export LAVENDER=0xff7287fd

export TRANSPARENT=0x00000000

# Bar
export BAR_COLOR=$BASE
export BAR_BORDER_COLOR=0xffbcc0cc

# Grouped status items on the right
export GROUP_BG=$MANTLE
export GROUP_BORDER=0xffccd0da

# Workspace pill states
export WS_ACTIVE_BG=$BLUE
export WS_ACTIVE_FG=0xffeff1f5
export WS_ACTIVE_BORDER=0xff1e66f5
export WS_OCCUPIED_BG=0xffdce0e8
export WS_OCCUPIED_FG=$TEXT
export WS_OCCUPIED_BORDER=0xffccd0da

# Scene badges.
#
# Latte's peach is unusable as a solid fill: white text lands at 2.64:1 on it
# and dark text at 2.68:1 -- neither passes. So a scene pill uses a pale tint
# with a deep, saturated foreground instead, and only flips to the deep colour
# as a fill when focused. Every pair below was measured at >= 4.5:1.
export BADGE_PEACH_TINT=0xfffbe3d2
export BADGE_PEACH_DEEP=0xff9a3412
export BADGE_TEAL_TINT=0xffd6f0ee
export BADGE_TEAL_DEEP=0xff0f6d68
export BADGE_MAUVE_TINT=0xffe9dcfb
export BADGE_MAUVE_DEEP=0xff6b21a8
export BADGE_BLUE_TINT=0xffdbe6fd
export BADGE_BLUE_DEEP=0xff1e40af
export BADGE_GREEN_TINT=0xffdcefd6
export BADGE_GREEN_DEEP=0xff2d6a1f
