#!/usr/bin/env bash
#
# Font resolution, shared by sketchybarrc and the plugins that need to set a
# font themselves (the workspace pills switch between the app-glyph font and
# the text font depending on whether they're showing a scene).

# Text is Berkeley Mono so the bar matches the terminal; icons stay Hack Nerd
# Font because Berkeley Mono carries no Nerd Font glyphs.
#
# Every Berkeley Mono weight installs as its own *family* with style "Regular",
# so weight is selected by family name. Asking for ":Bold:" silently falls back
# to the system font -- it looks like it worked but renders nothing of Berkeley.
if [ "$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSFont.fontWithNameSize($("BerkeleyMono-SemiCondensed"), 12).isNil() ? "no" : "yes"' 2>/dev/null)" = "yes" ]; then
  export FONT_REGULAR="Berkeley Mono SemiCondensed:Regular"
  export FONT_MEDIUM="Berkeley Mono SemiBold SemiCondensed:Regular"
  export FONT_BOLD="Berkeley Mono Bold SemiCondensed:Regular"
else
  # Berkeley Mono is a commercial font and can't ship in this repo; fall back
  # to Hack so a fresh machine still looks right before it's installed.
  export FONT_REGULAR="Hack Nerd Font:Regular"
  export FONT_MEDIUM="Hack Nerd Font:Semibold"
  export FONT_BOLD="Hack Nerd Font:Bold"
fi

export ICON_FONT="Hack Nerd Font"                    # glyphs only, never text
export APP_FONT="sketchybar-app-font:Regular:16.0"   # per-app glyphs in workspace pills

