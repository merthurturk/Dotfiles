#!/usr/bin/env bash
#
# Opal White — the pale one.
#
# Milky surfaces with a little blue and violet in them, and colour kept for
# the things that carry meaning. The palette derives from Catppuccin Latte;
# `ghostty_theme` in meta.json still names the upstream, because that is what
# Ghostty ships and knows how to load. Everything else here has moved on from
# it: accents darkened to pass contrast, badge triplets added, and the bar
# given no surface at all.
#
# This is the root of the Opal family. A variant copies this directory and
# changes colours -- not scripts.

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
#
# No surface of its own: the bar draws nothing, and the chips on it float
# directly over the wallpaper. The wallpaper is generated from this same file,
# so the thing behind the chips is a known quantity rather than whatever
# happened to be on screen.
export BAR_COLOR=$TRANSPARENT
export BAR_BORDER_COLOR=$TRANSPARENT

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
# _EDGE is the tint darkened 8%: enough to define the chip's shape without the
# saturated outline that made scene pills read as outlined buttons next to the
# filled workspace pills.
export BADGE_PEACH_TINT=0xfffbe3d2
export BADGE_PEACH_EDGE=0xffe6d0c1
export BADGE_PEACH_DEEP=0xff9a3412
export BADGE_TEAL_TINT=0xffd6f0ee
export BADGE_TEAL_EDGE=0xffc4dcda
export BADGE_TEAL_DEEP=0xff0f6d68
export BADGE_MAUVE_TINT=0xffe9dcfb
export BADGE_MAUVE_EDGE=0xffd6cae6
export BADGE_MAUVE_DEEP=0xff6b21a8
export BADGE_BLUE_TINT=0xffdbe6fd
export BADGE_BLUE_EDGE=0xffc9d3e8
export BADGE_BLUE_DEEP=0xff1e40af
export BADGE_GREEN_TINT=0xffdcefd6
export BADGE_GREEN_EDGE=0xffcadbc4
export BADGE_GREEN_DEEP=0xff2d6a1f

# Window outlines (JankyBorders).
#
# This theme draws edges, not shadows: the focused window gets the same blue as
# the focused workspace pill, so "where am I" is one colour everywhere. The
# unfocused outline is SURFACE1 -- the same value the bar uses for its own
# borders, and light enough to separate a window from the wallpaper without
# ruling a line around everything on screen.
export WINDOW_BORDER_ACTIVE=$BLUE
export WINDOW_BORDER_INACTIVE=$SURFACE1
