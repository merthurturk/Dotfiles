#!/usr/bin/env bash
#
# Checks that this setup is actually working, including the GUI-only steps
# install.sh can only print instructions for.
#
# install.sh can only print the GUI-only steps and has no way to know whether
# you did them. This does.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"

pass=0; warn=0; fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; pass=$((pass+1)); }
no()   { printf '  \033[31m✗\033[0m %s\n' "$*"; fail=$((fail+1)); }
meh()  { printf '  \033[33m!\033[0m %s\n' "$*"; warn=$((warn+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

head_ "Symlinks"
check_link() {
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then ok "${2/#$HOME/~}"
  elif [ -e "$2" ]; then no "${2/#$HOME/~} exists but isn't linked to the repo"
  else no "${2/#$HOME/~} missing - run install.sh"; fi
}
check_link "$REPO/aerospace.toml" "$HOME/.aerospace.toml"
for d in "$REPO"/config/*/; do
  check_link "${d%/}" "$HOME/.config/$(basename "$d")"
done

head_ "Packages"
command -v sketchybar >/dev/null && ok "sketchybar" || no "sketchybar missing - brew bundle"
command -v borders >/dev/null && ok "borders (window outlines)" || no "borders missing - brew bundle"
[ -d /Applications/AeroSpace.app ] && ok "AeroSpace.app" || no "AeroSpace.app missing"

head_ "Fonts"
font_present() {
  osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSFont.fontWithNameSize(\$('$1'), 12).isNil() ? 'no' : 'yes'" 2>/dev/null
}
# Note the PostScript name is HackNF-Regular, not HackNerdFont-* as the
# filename suggests.
[ "$(font_present HackNF-Regular)" = yes ] \
  && ok "Hack Nerd Font (bar icons)" || no "Hack Nerd Font missing - brew bundle"
[ -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ] \
  && ok "sketchybar-app-font (per-app glyphs)" || no "sketchybar-app-font missing - brew bundle"
[ "$(font_present BerkeleyMono-SemiCondensed)" = yes ] \
  && ok "Berkeley Mono (text)" \
  || meh "Berkeley Mono not installed - falling back to Hack. It's commercial, so it can't ship here."

head_ "Services"
pgrep -x sketchybar >/dev/null && ok "sketchybar running" || no "sketchybar not running - brew services start sketchybar"
pgrep -x borders >/dev/null && ok "borders running" || no "borders not running - brew services start borders"
if ! pgrep -f "AeroSpace.app" >/dev/null; then
  no "AeroSpace not running - open -a AeroSpace"
elif [ "$(aerospace list-windows --monitor all --count 2>/dev/null || echo 0)" -gt 0 ]; then
  ok "AeroSpace running and managing windows"
else
  # Running but seeing nothing is what a missing Accessibility grant looks
  # like: every command returns 0 and moves nothing. Checking the process
  # table would call that healthy, which is the exact failure CLAUDE.md's
  # "verify against the world" rule was written about.
  no "AeroSpace sees no windows - System Settings > Privacy & Security > Accessibility > AeroSpace"
fi
if launchctl print "gui/$(id -u)/sh.dotfiles.aerospace-bridge" >/dev/null 2>&1; then
  ok "event bridge agent loaded"
else
  no "event bridge not loaded - run install.sh (the bar won't update by itself)"
fi

head_ "Permissions"
[ "$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null)" = "1" ] \
  && ok "menu bar auto-hides" \
  || meh "menu bar doesn't auto-hide - the bar draws in that space (Control Centre settings)"

head_ "Built artefacts"
[ -x "$REPO/config/aerospace/bin/picker" ] \
  && ok "picker built" \
  || no "picker not built - swiftc -O -o config/aerospace/bin/picker config/aerospace/src/picker.swift -framework AppKit"
[ -x "$REPO/config/aerospace/bin/wallpaper" ] \
  && ok "wallpaper helper built" \
  || no "wallpaper helper not built - swiftc -O -o config/aerospace/bin/wallpaper config/aerospace/src/wallpaper.swift -framework AppKit"
[ -x "$REPO/config/aerospace/bin/geometry" ] \
  && ok "geometry helper built" \
  || no "geometry helper not built - swiftc -O -o config/aerospace/bin/geometry config/aerospace/src/geometry.swift -framework AppKit"

if ! [ -x "$REPO/config/aerospace/bin/DotCalendar.app/Contents/MacOS/DotCalendar" ]; then
  no "calendar helper not built - run install.sh"
elif ! launchctl print "gui/$(id -u)/sh.dotfiles.calendar" >/dev/null 2>&1; then
  no "calendar helper not running - launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/sh.dotfiles.calendar.plist"
elif [ -f "$STATE/agenda.tsv" ]; then
  n="$(grep -c . "$STATE/agenda.tsv" 2>/dev/null || echo 0)"
  ok "calendar helper is publishing ($n event(s) today)"
else
  # Not a failure: the bar simply does not draw the chip. But it is the one
  # setup step that cannot be done from here, and the Calendars pane has no
  # "+" button, so say exactly where to go.
  meh "calendar: no Calendars access yet - System Settings > Privacy & Security > Calendars, allow 'dot calendar'"
fi

for agent in sh.dotfiles.aerospace-bridge sh.dotfiles.calendar sh.dotfiles.theme-auto; do
  if ! [ -f "$HOME/Library/LaunchAgents/$agent.plist" ]; then
    case "$agent" in
      *theme-auto) ok "$agent not installed (dot theme auto on)" ;;
      *) no "$agent not installed - run install.sh" ;;
    esac
  elif ! launchctl print "gui/$(id -u)/$agent" >/dev/null 2>&1; then
    no "$agent not loaded - launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$agent.plist"
  else
    err="$STATE/${agent#sh.dotfiles.}.err"
    err="${err/aerospace-bridge.err/bridge.err}"
    # An agent that crash-loops keeps `launchctl print` happy every 30
    # seconds, so the only evidence is the file nothing was reading.
    if [ -s "$err" ]; then
      meh "$agent is running but $err is not empty - tail it"
    else
      ok "$agent running"
    fi
  fi
done

head_ "Capabilities"
if "$REPO/bin/check-capabilities.sh" >/dev/null 2>&1; then
  n="$(DOT_ROOT="$REPO" "$REPO/bin/dot" capabilities --json | jq 'length')"
  ok "$n capabilities valid, palette renders"
else
  no "capability surface is broken - run bin/check-capabilities.sh"
fi
[ -L "$HOME/.local/bin/dot" ] && ok "dot on PATH" || no "$HOME/.local/bin/dot missing - run install.sh"
theme="$(cat "$STATE/theme" 2>/dev/null)"
[ -n "$theme" ] && ok "theme: $theme" || meh "no theme recorded - run dot theme set <name>"

# A dark theme with macOS still in light mode means every unthemed window
# disagrees with the bar. dot theme set drives this; it can drift if the
# appearance is changed by hand afterwards.
if [ -n "$theme" ] && [ -f "$REPO/themes/$theme/meta.json" ]; then
  want="$(jq -r '.appearance // "light"' "$REPO/themes/$theme/meta.json")"
  is_dark="$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null)"
  case "$is_dark" in
    true)  now=dark ;;
    false) now=light ;;
    *)     now="" ;;
  esac
  if [ -z "$now" ]; then
    meh "cannot read the macOS appearance - grant Automation for System Events, then: dot theme set $theme"
  elif [ "$now" = "$want" ]; then
    ok "macOS appearance is $now, matching $theme"
  else
    meh "macOS is in $now mode but $theme is a $want theme - run dot theme set $theme"
  fi
fi

# The desktop picture and the screen saver are the two surfaces the bar can't
# repaint itself, so they are the ones that quietly fall behind the theme.
if [ -n "$theme" ] && [ -x "$REPO/config/aerospace/bin/wallpaper" ]; then
  want="$STATE/wallpaper/$theme-$("$REPO/config/aerospace/bin/wallpaper" size).png"
  if [ ! -f "$want" ]; then
    meh "no wallpaper rendered for $theme - run dot theme wallpaper"
  else
    "$REPO/config/aerospace/bin/wallpaper" store \
      | awk -F'\t' -v want="$want" '
          { seen++; if ($4 != want) stale++ }
          END { exit (seen > 0 && !stale) ? 0 : 1 }' \
      && ok "desktop picture and screen saver match $theme" \
      || meh "desktop picture or screen saver is off-theme - run dot theme wallpaper"
  fi
fi

head_ "Keybindings"
# A capability can declare its own chord, but nothing writes it to the config
# on its behalf -- a `dot` command that rewrote the window manager's config as
# a side effect of being asked a question would be a worse trade than this
# check. So the drift is real, and this is what notices it.
"$REPO/bin/dot" keys --check >/dev/null 2>&1; rc=$?
if   [ "$rc" -eq 0 ]; then ok "declared chords are applied"
elif [ "$rc" -eq 2 ]; then meh "aerospace.toml has no declared-keys block - see docs/capabilities.md"
else meh "a capability declares a chord aerospace.toml doesn't have - run dot keys --apply"
fi

head_ "Reachable from the launcher"
# Anything AeroSpace execs gets the [exec] PATH table from aerospace.toml, not
# a login shell's PATH. Three separate bugs have come from assuming otherwise:
# `dot` itself, and Ghostty's CLI twice. A tool that a terminal finds instantly
# can be invisible to the palette.
EXEC_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
for tool in jq sketchybar osascript borders; do
  if env -i PATH="$EXEC_PATH" command -v "$tool" >/dev/null 2>&1; then
    ok "$tool"
  else
    no "$tool is not on the launcher's PATH - the palette can't run it"
  fi
done
# These two are deliberately resolved by path rather than found on PATH.
[ -x "$HOME/.local/bin/dot" ] && ok "dot (by path)" || no "$HOME/.local/bin/dot missing"

head_ "Ghostty"
# Ghostty has no IPC on macOS, so `dot theme set` reloads it by pressing a
# global hotkey Ghostty itself registers. If that binding stops resolving, the
# terminal quietly keeps the old palette and nothing says why.
# Resolved the same way the capabilities do: PATH is not enough, because the
# launcher does not have Ghostty's CLI on it.
GHOSTTY="$(command -v ghostty 2>/dev/null)"
[ -n "$GHOSTTY" ] || GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
if [ -x "$GHOSTTY" ]; then
  # Open panes are repainted over their ttys, so what matters is that Ghostty
  # can resolve the active theme at all.
  if "$GHOSTTY" +show-config 2>/dev/null | grep -q '^background '; then
    ok "resolves the active theme ($("$GHOSTTY" +show-config 2>/dev/null | awk '$1=="background"{print $3}'))"
  else
    no "ghostty cannot resolve a background colour - check config/ghostty/theme.conf"
  fi
  # The colours have to come from the theme, never from the base config.
  if grep -qE '^(theme|background|foreground|palette|cursor-color) ' "$REPO/config/ghostty/config"; then
    no "config/ghostty/config sets colours - they belong in the theme's ghostty.conf"
  else
    ok "no colours outside the theme"
  fi
fi

head_ "Shadows"
# This setup separates surfaces with outlines. The bar's own shadow is off in
# sketchybarrc; the one other shadow we can reach is the one macOS bakes into
# window screenshots.
[ "$(sketchybar --query bar 2>/dev/null | jq -r '.shadow')" = "off" ] \
  && ok "the bar casts no shadow" \
  || meh "the bar still has a shadow - sketchybar --reload"
if [ "$(defaults read com.apple.screencapture disable-shadow 2>/dev/null)" = "1" ]; then
  ok "window screenshots have no shadow"
else
  meh "window screenshots still carry a shadow - defaults write com.apple.screencapture disable-shadow -bool true && killall SystemUIServer"
fi

head_ "Recent errors"
if [ -s "$STATE/log" ]; then
  n="$(wc -l < "$STATE/log" | tr -d ' ')"
  meh "$n line(s) in $STATE/log - tail it if something feels broken"
  tail -3 "$STATE/log" | sed 's/^/      /'
else
  ok "no errors logged"
fi

printf '\n%s passed, %s warning(s), %s failure(s)\n' "$pass" "$warn" "$fail"
[ "$fail" -eq 0 ]
