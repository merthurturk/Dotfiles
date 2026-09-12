#!/usr/bin/env bash
#
# Rosé Pine Dawn (light).
#
# Accents are darkened from the upstream palette until white text on them
# reaches 4.5:1 -- Dawn's own accents sit at 2.0-3.8:1 on its background, which
# is fine for syntax highlighting and unusable for a filled chip with a label.
# Generated, then verified; see themes/README.md.

# Surfaces, lightest to darkest
export BASE=0xfffaf4ed
export MANTLE=0xfff2e9e1
export CRUST=0xffe4dfde
export SURFACE0=0xfff2e9e1
export SURFACE1=0xffdfdad9
export SURFACE2=0xffcecacd
export OVERLAY0=0xff9893a5
export OVERLAY1=0xff797593

# Foregrounds
export TEXT=0xff575279
export SUBTEXT=0xff696582   # darkened: 3.67:1 on GROUP_BG failed

# Accents, darkened for legibility on a light surface
export ROSEWATER=0xff9a5d5a
export FLAMINGO=0xff9a5d5a
export PINK=0xff9a5d5a
export MAUVE=0xff7b6891
export RED=0xffa1596d
export MAROON=0xffa1596d
export PEACH=0xff956421
export YELLOW=0xff956421
export GREEN=0xff286983
export TEAL=0xff44767f
export SKY=0xff44767f
export SAPPHIRE=0xff44767f
export BLUE=0xff286983
export LAVENDER=0xff7b6891

export TRANSPARENT=0x00000000

# Bar
export BAR_COLOR=$BASE
export BAR_BORDER_COLOR=0xffdfdad9
export GROUP_BG=0xfff2e9e1
export GROUP_BORDER=0xffe4dfde

# Workspace pill states
export WS_ACTIVE_BG=$BLUE
export WS_ACTIVE_FG=0xfffaf4ed
export WS_ACTIVE_BORDER=$BLUE
export WS_OCCUPIED_BG=0xffefe7e0
export WS_OCCUPIED_FG=$TEXT
export WS_OCCUPIED_BORDER=0xffe0d8d2

# Scene badges: pale tint, deep foreground, edge = tint darkened 8%.
export BADGE_PEACH_TINT=0xfffcf5ea
export BADGE_PEACH_EDGE=0xffe7e1d7
export BADGE_PEACH_DEEP=0xff8c5e1f
export BADGE_TEAL_TINT=0xffeef4f5
export BADGE_TEAL_EDGE=0xffdae0e1
export BADGE_TEAL_DEEP=0xff417078
export BADGE_MAUVE_TINT=0xfff3f1f6
export BADGE_MAUVE_EDGE=0xffdfdde2
export BADGE_MAUVE_DEEP=0xff736187
export BADGE_BLUE_TINT=0xffe9f0f2
export BADGE_BLUE_EDGE=0xffd6dcde
export BADGE_BLUE_DEEP=0xff286983
export BADGE_GREEN_TINT=0xffe9f0f2
export BADGE_GREEN_EDGE=0xffd6dcde
export BADGE_GREEN_DEEP=0xff286983

# Window outlines (JankyBorders). See the note in opal-white/colors.sh:
# focused windows take the same accent as the focused workspace pill.
export WINDOW_BORDER_ACTIVE=$BLUE
export WINDOW_BORDER_INACTIVE=$SURFACE1
