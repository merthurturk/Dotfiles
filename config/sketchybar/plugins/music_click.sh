#!/usr/bin/env bash
#
# Focus the Apple Music window. Going through AeroSpace rather than `open -a`
# means it also switches to whichever workspace the window lives on.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.config/aerospace/logging.sh"

WID="$(aerospace list-windows --all --format '%{window-id}|%{app-name}' \
        | awk -F'|' '$2 == "Music" { print $1; exit }')"

if [ -n "$WID" ]; then
  aerospace focus --window-id "$WID"
else
  open -a Music
fi
