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
#
# The presence check costs ~70ms because it has to ask AppKit, and this file is
# sourced by every pill repaint -- which is most of the latency when you change
# workspace. So the answer is cached. sketchybarrc clears the cache before
# sourcing, so a reload re-probes and a newly installed font is picked up.

_font_cache="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/fonts"

if [ -s "$_font_cache" ]; then
  # shellcheck source=/dev/null
  . "$_font_cache"
else
  if [ "$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSFont.fontWithNameSize($("BerkeleyMono-SemiCondensed"), 12).isNil() ? "no" : "yes"' 2>/dev/null)" = "yes" ]; then
    _fr="Berkeley Mono SemiCondensed:Regular"
    _fm="Berkeley Mono SemiBold SemiCondensed:Regular"
    _fb="Berkeley Mono Bold SemiCondensed:Regular"
  else
    # Berkeley Mono is a commercial font and can't ship in this repo; fall back
    # to Hack so a fresh machine still looks right before it's installed.
    _fr="Hack Nerd Font:Regular"
    _fm="Hack Nerd Font:Semibold"
    _fb="Hack Nerd Font:Bold"
  fi
  mkdir -p "$(dirname "$_font_cache")"
  {
    printf 'export FONT_REGULAR=%s\n' "\"$_fr\""
    printf 'export FONT_MEDIUM=%s\n'  "\"$_fm\""
    printf 'export FONT_BOLD=%s\n'    "\"$_fb\""
  # Through a rename. sketchybarrc deletes this cache and re-probes on every
  # reload, while the 5-second pill repaint is sourcing it -- a reader landing
  # in a truncate-in-place window gets no font name at all, and sketchybar
  # accepts an empty font string silently.
  } > "$_font_cache.$$" && mv "$_font_cache.$$" "$_font_cache"
  export FONT_REGULAR="$_fr" FONT_MEDIUM="$_fm" FONT_BOLD="$_fb"
fi

export ICON_FONT="Hack Nerd Font"                    # glyphs only, never text
export APP_FONT="sketchybar-app-font:Regular:16.0"   # per-app glyphs in workspace pills

