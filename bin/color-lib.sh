#!/usr/bin/env bash
#
# Colour arithmetic: WCAG contrast, and moving a colour until it passes.
#
# Sourced, not executed. `bin/check-themes.sh` grades a theme with it and
# `dot theme new` uses it to darken an accent you picked into one that is
# actually legible -- which is the same sum, and so has to be the same code.
# "Accents are darkened until text on them clears 4.5:1" was a thing this repo
# did by hand in a comment; now it is a function.
#
# Colours are 0xaarrggbb or 0xrrggbb throughout, because that is what
# SketchyBar wants and so what the themes are written in.

# contrast <colour> <colour> -> "4.53"
contrast() {
  # macOS awk is the one-true-awk, not gawk: no strtonum, so hex is parsed by
  # hand. Same class of surprise as /bin/bash being 3.2.
  awk -v a="$1" -v b="$2" '
    function hex2(s,   i, c, n, d) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        c = tolower(substr(s, i, 1))
        d = index("0123456789abcdef", c) - 1
        if (d < 0) d = 0
        n = n * 16 + d
      }
      return n
    }
    function chan(v) { v = v / 255; return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
    function lum(hex,   r, g, b) {
      hex = substr(hex, length(hex) - 5)
      r = hex2(substr(hex, 1, 2))
      g = hex2(substr(hex, 3, 2))
      b = hex2(substr(hex, 5, 2))
      return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)
    }
    BEGIN {
      la = lum(a); lb = lum(b)
      hi = (la > lb) ? la : lb; lo = (la > lb) ? lb : la
      printf "%.2f", (hi + 0.05) / (lo + 0.05)
    }'
}

# passes <colour> <colour> [target] -> exit 0 if the pair clears the ratio
passes() {
  awk -v r="$(contrast "$1" "$2")" -v t="${3:-4.5}" 'BEGIN { exit (r >= t) ? 0 : 1 }'
}

# luminance_of <colour> -> 0.0 .. 1.0, for deciding which way to move
luminance_of() {
  awk -v a="$1" '
    function hex2(s,   i, c, n, d) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        c = tolower(substr(s, i, 1)); d = index("0123456789abcdef", c) - 1
        if (d < 0) d = 0
        n = n * 16 + d
      }
      return n
    }
    function chan(v) { v = v / 255; return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
    BEGIN {
      h = substr(a, length(a) - 5)
      printf "%.4f", 0.2126 * chan(hex2(substr(h,1,2))) + 0.7152 * chan(hex2(substr(h,3,2))) \
                   + 0.0722 * chan(hex2(substr(h,5,2)))
    }'
}

# shade <colour> <factor> -> the colour scaled toward black (<1) or white (>1),
# keeping the alpha byte it came with.
shade() {
  awk -v a="$1" -v f="$2" '
    function hex2(s,   i, c, n, d) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        c = tolower(substr(s, i, 1)); d = index("0123456789abcdef", c) - 1
        if (d < 0) d = 0
        n = n * 16 + d
      }
      return n
    }
    function clamp(v) { return (v < 0) ? 0 : ((v > 255) ? 255 : int(v + 0.5)) }
    BEGIN {
      body = substr(a, length(a) - 5)
      alpha = (length(a) >= 10) ? substr(a, 3, 2) : "ff"
      r = hex2(substr(body,1,2)); g = hex2(substr(body,3,2)); b = hex2(substr(body,5,2))
      if (f <= 1) { r = r * f; g = g * f; b = b * f }
      else        { r = r + (255 - r) * (f - 1); g = g + (255 - g) * (f - 1); b = b + (255 - b) * (f - 1) }
      printf "0x%s%02x%02x%02x", alpha, clamp(r), clamp(g), clamp(b)
    }'
}

# fit_contrast <colour> <against> [target] -> the nearest version of <colour>
# that clears the ratio against <against>, moved away from it in luminance.
#
# Returns the input untouched when it already passes, and gives up rather than
# looping forever -- an accent that cannot reach 4.5:1 against its own
# foreground is a choice the person should see fail, not one this quietly
# turns into black.
fit_contrast() {
  local c="$1" against="$2" target="${3:-4.5}" i=0 dir
  passes "$c" "$against" "$target" && { printf '%s' "$c"; return 0; }
  # Move away from the foreground: darken under light text, lighten under dark.
  if awk -v l="$(luminance_of "$against")" 'BEGIN { exit (l > 0.5) ? 0 : 1 }'
  then dir=0.94; else dir=1.06; fi
  while [ "$i" -lt 40 ]; do
    c="$(shade "$c" "$dir")"
    passes "$c" "$against" "$target" && { printf '%s' "$c"; return 0; }
    i=$((i + 1))
  done
  printf '%s' "$c"
  return 1
}
