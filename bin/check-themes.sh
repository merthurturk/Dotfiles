#!/usr/bin/env bash
#
# Measures every theme's contrast, so "measure, don't eyeball" is something the
# repo does rather than something a doc asks for.
#
# Both upstream palettes this setup started from shipped accents that fail
# badly as a filled chip -- Latte's peach reads 2.64:1 under white text. That
# was caught by hand once. With a family of variants coming, it needs to be
# caught by a command.
#
# WCAG contrast: text needs 4.5:1. Borders and other non-text edges are
# reported but never fail, because an unfocused outline is *meant* to be quiet.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Every key a plugin will dereference. Missing WS_* or TEXT breaks the bar;
# missing BADGE_* only degrades a pill, but a variant should still be complete.
REQUIRED="BASE MANTLE CRUST SURFACE0 SURFACE1 SURFACE2 OVERLAY0 OVERLAY1
          TEXT SUBTEXT ROSEWATER FLAMINGO PINK MAUVE RED MAROON PEACH YELLOW
          GREEN TEAL SKY SAPPHIRE BLUE LAVENDER TRANSPARENT
          BAR_COLOR BAR_BORDER_COLOR GROUP_BG GROUP_BORDER
          WS_ACTIVE_BG WS_ACTIVE_FG WS_ACTIVE_BORDER
          WS_OCCUPIED_BG WS_OCCUPIED_FG WS_OCCUPIED_BORDER
          WINDOW_BORDER_ACTIVE WINDOW_BORDER_INACTIVE"
for c in PEACH TEAL MAUVE BLUE GREEN; do
  REQUIRED="$REQUIRED BADGE_${c}_TINT BADGE_${c}_EDGE BADGE_${c}_DEEP"
done

# fg:bg pairs that carry text, and must clear 4.5:1.
TEXT_PAIRS="TEXT:BASE TEXT:GROUP_BG SUBTEXT:BASE SUBTEXT:GROUP_BG
            WS_ACTIVE_FG:WS_ACTIVE_BG WS_OCCUPIED_FG:WS_OCCUPIED_BG"
for c in PEACH TEAL MAUVE BLUE GREEN; do
  # _DEEP carries text on the pale tint, and becomes the fill when the scene is
  # focused -- at which point aerospace.sh draws BASE on top of it. Both ways
  # round have to be legible.
  TEXT_PAIRS="$TEXT_PAIRS BADGE_${c}_DEEP:BADGE_${c}_TINT BASE:BADGE_${c}_DEEP"
done
# Reported, never failed: edges are meant to be subtle.
EDGE_PAIRS="WINDOW_BORDER_INACTIVE:BASE WINDOW_BORDER_ACTIVE:BASE GROUP_BORDER:GROUP_BG"

# 0xaarrggbb / 0xrrggbb -> "r g b", then WCAG relative luminance and ratio.
ratio() {
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

fail=0
for dir in "$REPO"/themes/*/; do
  theme="$(basename "$dir")"
  printf '\n\033[1m%s\033[0m\n' "$theme"

  missing="$( ( set +u; source "$dir/colors.sh"
                for k in $REQUIRED; do [ -n "${!k:-}" ] || echo "$k"; done ) )"
  if [ -n "$missing" ]; then
    printf '  \033[31m✗\033[0m missing: %s\n' "$(echo "$missing" | tr '\n' ' ')"
    fail=1
  fi

  while IFS="$(printf '\t')" read -r kind fg bg fgv bgv; do
    [ -n "${fgv:-}" ] && [ -n "${bgv:-}" ] || continue
    # A transparent background means the chip has no fill of its own; the
    # thing behind it is the wallpaper, which is generated from BASE.
    r="$(ratio "$fgv" "$bgv")"
    if [ "$kind" = edge ]; then
      printf '  \033[2m·\033[0m %-42s %s:1\n' "$fg on $bg" "$r"
    elif awk -v r="$r" 'BEGIN { exit (r >= 4.5) ? 0 : 1 }'; then
      printf '  \033[32m✓\033[0m %-42s %s:1\n' "$fg on $bg" "$r"
    else
      printf '  \033[31m✗\033[0m %-42s %s:1  (needs 4.5)\n' "$fg on $bg" "$r"
      fail=1
    fi
  done < <( ( set +u; source "$dir/colors.sh"
              for p in $TEXT_PAIRS; do
                fg="${p%%:*}"; bg="${p##*:}"
                v_bg="${!bg:-}"
                [ "$v_bg" = "${TRANSPARENT:-}" ] && v_bg="$BASE"
                printf 'text\t%s\t%s\t%s\t%s\n' "$fg" "$bg" "${!fg:-}" "$v_bg"
              done
              for p in $EDGE_PAIRS; do
                fg="${p%%:*}"; bg="${p##*:}"
                v_bg="${!bg:-}"
                [ "$v_bg" = "${TRANSPARENT:-}" ] && v_bg="$BASE"
                printf 'edge\t%s\t%s\t%s\t%s\n' "$fg" "$bg" "${!fg:-}" "$v_bg"
              done ) )

  # The terminal half of a theme restates colours that colors.sh already has.
  # Two files holding the same number is how a palette drifts -- opal-fire's
  # ghostty.conf kept an older background for an hour after the palette moved,
  # and nothing noticed. A theme pointing at an upstream `theme =` has nothing
  # to compare.
  gconf="$dir/ghostty.conf"
  if [ -f "$gconf" ] && grep -q '^background' "$gconf"; then
    ( set +u; source "$dir/colors.sh"
      for pair in "background:$BASE" "foreground:$TEXT"; do
        key="${pair%%:*}"; want="#${pair##*:}"; want="${want/\#0xff/#}"
        got="$(awk -v k="$key" '$1 == k { print $3; exit }' "$gconf")"
        if [ "$got" != "$want" ]; then
          printf '  \033[31m✗\033[0m ghostty.conf %s is %s, colors.sh says %s\n' \
                 "$key" "${got:-unset}" "$want"
          exit 1
        fi
      done ) || fail=1
  fi
done

echo
[ "$fail" -eq 0 ] && echo "ok: every theme's text clears 4.5:1, terminal matches bar"
exit "$fail"
