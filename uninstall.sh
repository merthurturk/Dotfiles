#!/usr/bin/env bash
#
# Undoes what install.sh did, in the reverse order.
#
# Symlinks are removed rather than deleted-through, services stopped, the
# launchd agent unloaded, and the one global macOS setting install.sh changed is
# put back. Whatever install.sh backed up is left in ~/.dotfiles-backup for you
# to restore by hand -- moving it back automatically could overwrite something
# you have since changed.
#
#   ./uninstall.sh          say what would happen
#   ./uninstall.sh --yes    actually do it

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Every agent the repo installs -- install.sh does two and `dot theme auto`
# installs the third itself. Naming one left the other two respawning every
# thirty seconds against paths this script had just deleted.
AGENTS="sh.dotfiles.aerospace-bridge sh.dotfiles.calendar sh.dotfiles.theme-auto"
DRY=1
[ "${1:-}" = "--yes" ] && DRY=0

run() {
  if [ "$DRY" -eq 1 ]; then printf '  would: %s\n' "$*"
  else printf '  %s\n' "$*"; eval "$*"; fi
}

[ "$DRY" -eq 1 ] && printf 'Dry run. Re-run with --yes to apply.\n\n'

printf 'Services\n'
run "brew services stop sketchybar >/dev/null 2>&1 || true"
run "brew services stop borders >/dev/null 2>&1 || true"
for AGENT in $AGENTS; do
  run "launchctl bootout gui/$(id -u)/$AGENT 2>/dev/null || true"
  run "rm -f \"$HOME/Library/LaunchAgents/$AGENT.plist\""
done
run "osascript -e 'tell application \"AeroSpace\" to quit' 2>/dev/null || true"

printf '\nSymlinks\n'
for link in "$HOME/.aerospace.toml" "$HOME/.local/bin/dot"; do
  [ -L "$link" ] && run "rm -f \"$link\""
done
for dir in "$DOTFILES"/config/*/; do
  target="$HOME/.config/$(basename "$dir")"
  [ -L "$target" ] && run "rm -f \"$target\""
done

printf '\nmacOS settings install.sh changed\n'
run "defaults delete com.apple.screencapture disable-shadow 2>/dev/null || true"
run "killall SystemUIServer 2>/dev/null || true"

printf '\nWallpaper\n'
if [ -x "$DOTFILES/libexec/dot/theme-wallpaper" ]; then
  run "DOT_ROOT=\"$DOTFILES\" \"$DOTFILES/libexec/dot/theme-wallpaper\" --restore 2>/dev/null || true"
fi

cat <<NOTE

Left alone on purpose:
  ~/.dotfiles-backup/     whatever install.sh replaced -- restore by hand
  ~/.local/state/aerospace/   scene ledger, theme, logs
  Homebrew packages       'brew bundle cleanup --file=Brewfile' if you want them gone
  This repo               delete it yourself when you're happy

Permissions you granted (Accessibility, Automation, Calendars) have to be removed in
System Settings; nothing can revoke them for you.
NOTE
