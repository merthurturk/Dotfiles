#!/usr/bin/env bash
#
# Sets up a fresh Mac from this repo: packages, symlinks, compiled helpers and
# services. Safe to re-run -- existing files are backed up, never overwritten.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ! \033[0m%s\n' "$*"; }

# --- Homebrew -------------------------------------------------------------

if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Apple Silicon and Intel use different prefixes.
if   [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew   ]; then eval "$(/usr/local/bin/brew shellenv)"
fi

log "Installing packages"
brew bundle --file="$DOTFILES/Brewfile"

# --- Symlinks -------------------------------------------------------------

link() {  # link <path-in-repo> <target>
  local src="$1" dst="$2" rel="${2#$HOME/}"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then log "ok       ~/$rel"; return; fi
    rm "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$dst" "$BACKUP/$rel"
    warn "backed up ~/$rel -> $BACKUP/$rel"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  log "linked   ~/$rel"
}

link "$DOTFILES/aerospace.toml" "$HOME/.aerospace.toml"
for dir in "$DOTFILES"/config/*/; do
  link "${dir%/}" "$HOME/.config/$(basename "$dir")"
done

# --- dot on PATH ----------------------------------------------------------

log "Linking dot into ~/.local/bin"
mkdir -p "$HOME/.local/bin"
ln -sfn "$DOTFILES/bin/dot" "$HOME/.local/bin/dot"
# Write it, do not warn about it. ~/.local/bin is never on a stock macOS PATH
# (/etc/paths has no such entry), so every single user hit this warning -- one
# yellow line a third of the way up sixty lines of output -- and then found
# that `dot doctor`, the command the readme tells you to run next, did not
# exist. Homebrew's shellenv has the same problem: its installer prints the
# line and does not write it either.
PROFILE="$HOME/.zprofile"
add_to_profile() {   # <line> <marker>
  [ -f "$PROFILE" ] && grep -qF "$2" "$PROFILE" && return 0
  printf '\n# added by dotfiles install.sh\n%s\n' "$1" >> "$PROFILE"
  log "added to ~/.zprofile: $1"
  PROFILE_CHANGED=1
}
PROFILE_CHANGED=0
[ -x /opt/homebrew/bin/brew ] && add_to_profile 'eval "$(/opt/homebrew/bin/brew shellenv)"' 'brew shellenv'
[ -x /usr/local/bin/brew ] && [ ! -x /opt/homebrew/bin/brew ] \
  && add_to_profile 'eval "$(/usr/local/bin/brew shellenv)"' 'brew shellenv'
add_to_profile 'export PATH="$HOME/.local/bin:$PATH"' '.local/bin'
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# --- Compiled helpers -----------------------------------------------------

# `swiftc -version`, not `command -v swiftc`: /usr/bin/swiftc is a Command Line
# Tools shim that exists on every Mac whether or not the tools do, so
# `command -v` is always true and the helpful else-branch below was dead code.
# Running it is the only way to ask the real question.
if swiftc -version >/dev/null 2>&1; then
  mkdir -p "$DOTFILES/config/aerospace/bin"
  for helper in picker wallpaper geometry; do
    log "Building $helper"
    swiftc -O -o "$DOTFILES/config/aerospace/bin/$helper" \
                "$DOTFILES/config/aerospace/src/$helper.swift" -framework AppKit
  done

  # The calendar helper is a .app rather than a bare binary, because reading
  # Calendars needs a TCC grant and the Calendars pane in System Settings has
  # no "+" button: an app only appears there once it has asked. A bundle gives
  # it a name you can recognise in that list, and an identity of its own rather
  # than inheriting whatever happened to launch it.
  log "Building the calendar helper"
  APP="$DOTFILES/config/aerospace/bin/DotCalendar.app"
  mkdir -p "$APP/Contents/MacOS"
  cp "$DOTFILES/config/aerospace/src/DotCalendar-Info.plist" "$APP/Contents/Info.plist"
  swiftc -O -o "$APP/Contents/MacOS/DotCalendar" \
              "$DOTFILES/config/aerospace/src/calendar.swift" -framework EventKit
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
else
  warn "swiftc missing - run 'xcode-select --install' then re-run this script."
  warn "Until then the Chrome profile prompt falls back to a plain AppleScript list,"
  warn "and the desktop picture can't be generated from the theme."
fi

# --- Theme ----------------------------------------------------------------
# colors.sh and the Ghostty theme are symlinks into themes/<name>/. They are
# NOT tracked -- tracking them committed an absolute /Users/<name>/ path and
# made `dot theme set` dirty the working tree -- so a fresh clone has neither,
# and they must be created here rather than only when no theme is recorded.
if [ ! -e "$DOTFILES/config/sketchybar/colors.sh" ] \
   || [ ! -e "$DOTFILES/config/ghostty/theme.conf" ] \
   || [ ! -e "$HOME/.local/state/aerospace/theme" ]; then
  THEME="$(cat "$HOME/.local/state/aerospace/theme" 2>/dev/null || echo opal-white)"
  [ -d "$DOTFILES/themes/$THEME" ] || THEME=opal-white
  log "Selecting the theme ($THEME)"
  DOT_ROOT="$DOTFILES" "$DOTFILES/libexec/dot/theme-set" "$THEME" >/dev/null
fi

# --- System defaults ------------------------------------------------------
# This setup separates surfaces with outlines rather than shadows, and a window
# screenshot otherwise carries a drop shadow the size of the window.

log "Turning off the screenshot drop shadow"
defaults write com.apple.screencapture disable-shadow -bool true
killall SystemUIServer 2>/dev/null || true

# --- Event bridge ---------------------------------------------------------
# Translates AeroSpace's event stream into SketchyBar triggers. Without it the
# bar does not update at all -- the per-binding triggers it replaced are gone.

log "Installing the AeroSpace event bridge"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.local/state/aerospace"
AGENT="sh.dotfiles.aerospace-bridge"
sed "s|__HOME__|$HOME|g" "$DOTFILES/launchd/$AGENT.plist" \
  > "$HOME/Library/LaunchAgents/$AGENT.plist"
launchctl bootout "gui/$(id -u)/$AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$AGENT.plist" 2>/dev/null \
  || warn "Could not load $AGENT - check with: launchctl print gui/$(id -u)/$AGENT"

# --- Calendar ---------------------------------------------------------------
# Resident so the Calendars permission belongs to one process with one identity;
# it publishes what is next and today into the state directory, and the bar and
# the launcher only read files.
log "Installing the calendar helper"
AGENT="sh.dotfiles.calendar"
sed "s|__HOME__|$HOME|g" "$DOTFILES/launchd/$AGENT.plist" \
  > "$HOME/Library/LaunchAgents/$AGENT.plist"
launchctl bootout "gui/$(id -u)/$AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$AGENT.plist" 2>/dev/null \
  || warn "Could not load $AGENT - check with: launchctl print gui/$(id -u)/$AGENT"
warn "Calendar access is asked for once, the first time the helper runs."
warn "If the chip stays hidden: System Settings > Privacy & Security > Calendars."

# --- Git hooks ------------------------------------------------------------

if [ -d "$DOTFILES/.git" ]; then
  git -C "$DOTFILES" config core.hooksPath githooks
  log "Enabled the pre-commit hook"
fi

# --- Services -------------------------------------------------------------

log "Starting sketchybar"
brew services restart sketchybar >/dev/null

# Window outlines. Configured by config/borders/bordersrc, which is already
# linked into ~/.config above.
log "Starting borders"
brew services restart borders >/dev/null

log "Starting AeroSpace"
open -a AeroSpace 2>/dev/null || warn "Could not open AeroSpace - launch it once by hand."

cat <<'STEPS'

────────────────────────────────────────────────────────────────────────
Manual steps -- these need a GUI and cannot be scripted
Run bin/doctor.sh afterwards; it verifies every one of them.
────────────────────────────────────────────────────────────────────────

1. AeroSpace accessibility
   It prompts on first launch. System Settings > Privacy & Security >
   Accessibility > enable AeroSpace. Required for window management.

2. Auto-hide the macOS menu bar
   System Settings > Control Center > "Automatically hide and show the menu
   bar" > Always. The bar draws in that space.

3. Automation permission for Music and System Events
   Both prompt by themselves -- Music the first time the now-playing chip
   polls it, System Events the first time `dot theme set` switches the macOS
   light/dark appearance to match the theme. Allow both.

Then check your work:

    dot doctor

────────────────────────────────────────────────────────────────────────
STEPS

if [ "$PROFILE_CHANGED" -eq 1 ]; then
  warn "$PROFILE changed. Start a new terminal, or run: exec zsh -l"
  warn "Until you do, dot works only in this shell."
fi
