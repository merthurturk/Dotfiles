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

# --- Compiled helpers -----------------------------------------------------

if command -v swiftc >/dev/null 2>&1; then
  log "Building picker"
  mkdir -p "$DOTFILES/config/aerospace/bin"
  swiftc -O -o "$DOTFILES/config/aerospace/bin/picker" \
              "$DOTFILES/config/aerospace/src/picker.swift" -framework AppKit
else
  warn "swiftc missing - run 'xcode-select --install' then re-run this script."
  warn "Until then the Chrome profile prompt falls back to a plain AppleScript list."
fi

# --- Services -------------------------------------------------------------

log "Starting sketchybar"
brew services restart sketchybar >/dev/null

log "Starting AeroSpace"
open -a AeroSpace 2>/dev/null || warn "Could not open AeroSpace - launch it once by hand."

cat <<'STEPS'

────────────────────────────────────────────────────────────────────────
Manual steps -- these need a GUI and cannot be scripted
────────────────────────────────────────────────────────────────────────

1. AeroSpace accessibility
   It prompts on first launch. System Settings > Privacy & Security >
   Accessibility > enable AeroSpace. Required for window management.

2. Full Disk Access for sketchybar          (the Focus chip needs it)
   System Settings > Privacy & Security > Full Disk Access > + > press
   Cmd-Shift-G and paste the output of:  which sketchybar
   Then: brew services restart sketchybar
   Focus state lives in ~/Library/DoNotDisturb/DB, which is TCC-protected.
   Without this the chip reads "Grant FDA" instead of your Focus state.

3. Two Shortcuts, for the Focus toggle
   macOS has no CLI for changing Focus; Shortcuts' "Set Focus" action is the
   only supported route. In Shortcuts.app create, with one action each:
       "Focus On"   ->  Set Focus / Turn Do Not Disturb On
       "Focus Off"  ->  Set Focus / Turn Do Not Disturb Off
   Names must match exactly. The bar reads the live state and picks which to
   run, so no Toggle option is needed.

4. Auto-hide the macOS menu bar
   System Settings > Control Center > "Automatically hide and show the menu
   bar" > Always. The bar draws in that space.

5. Automation permission for Music
   Prompts by itself the first time the now-playing chip polls Music. Allow it.

────────────────────────────────────────────────────────────────────────
STEPS
