#!/usr/bin/env bash
#
# Checks that this setup is actually working, including the GUI-only steps
# install.sh can only print instructions for.
#
# install.sh tells you to grant Full Disk Access and create two Shortcuts, then
# has no way to know whether you did. This does.

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
pgrep -f "AeroSpace.app" >/dev/null && ok "AeroSpace running" || no "AeroSpace not running - open -a AeroSpace"
if launchctl print "gui/$(id -u)/sh.dotfiles.aerospace-bridge" >/dev/null 2>&1; then
  ok "event bridge agent loaded"
else
  no "event bridge not loaded - run install.sh (the bar won't update by itself)"
fi

head_ "Permissions"
# The Focus chip says so itself when it can't read the TCC-protected database.
focus_label="$(sketchybar --query focus 2>/dev/null | jq -r '.label.value // ""' 2>/dev/null)"
if [ "$focus_label" = "Grant FDA" ]; then
  no "sketchybar lacks Full Disk Access - the Focus chip can't read your Focus state"
  printf '      System Settings > Privacy & Security > Full Disk Access > + > %s\n' "$(command -v sketchybar)"
elif [ -f "$STATE/focus" ]; then
  ok "sketchybar has Full Disk Access (Focus state readable)"
else
  meh "couldn't confirm Full Disk Access - is sketchybar running?"
fi
[ "$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null)" = "1" ] \
  && ok "menu bar auto-hides" \
  || meh "menu bar doesn't auto-hide - the bar draws in that space (Control Centre settings)"

head_ "Shortcuts (the Focus toggle)"
# Mirror focus_click.sh: directional shortcuts are preferred because they let
# the bar pick the direction from the state it already reads, but a single
# "Toggle Focus" is a perfectly good fallback and the handler uses it.
have() { shortcuts list 2>/dev/null | grep -Fxq "$1"; }
if have "Focus On" && have "Focus Off"; then
  ok "\"Focus On\" + \"Focus Off\" (direction chosen from live state)"
elif have "Toggle Focus"; then
  ok "\"Toggle Focus\" (fallback; works)"
  printf '      Optional: separate "Focus On"/"Focus Off" shortcuts let the bar\n'
  printf '      pick the direction rather than relying on the toggle.\n'
elif have "Focus On" || have "Focus Off"; then
  meh "only one of \"Focus On\"/\"Focus Off\" exists - the other direction won't work"
else
  no "no Focus shortcut - clicking the Focus chip can't toggle"
  printf '      Shortcuts.app > a shortcut named "Toggle Focus" with one Set Focus action\n'
fi

head_ "Built artefacts"
[ -x "$REPO/config/aerospace/bin/picker" ] \
  && ok "picker built" \
  || no "picker not built - swiftc -O -o config/aerospace/bin/picker config/aerospace/src/picker.swift -framework AppKit"

head_ "Launcher"
if "$REPO/bin/check-launcher.sh" >/dev/null 2>&1; then
  ok "every entry point is reachable from ⌥space"
else
  no "some entry points are missing from the launcher - run bin/check-launcher.sh"
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
