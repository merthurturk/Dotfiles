#!/usr/bin/env bash
#
# Routes stderr to a log file. Source this near the top of anything invoked by
# AeroSpace's exec-and-forget or by a SketchyBar click_script: both discard
# stderr entirely, so a failing script is otherwise completely silent. A whole
# class of bug in this repo was only found by accident for exactly that reason.
#
# Successful runs write nothing, so the log stays quiet and readable.

DOTFILES_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace/log"
mkdir -p "$(dirname "$DOTFILES_LOG")"

# Keep it bounded; this is a breadcrumb trail, not an archive.
if [ -f "$DOTFILES_LOG" ] && [ "$(wc -c < "$DOTFILES_LOG")" -gt 1048576 ]; then
  tail -c 262144 "$DOTFILES_LOG" > "$DOTFILES_LOG.tmp" && mv "$DOTFILES_LOG.tmp" "$DOTFILES_LOG"
fi

# Only divert when there's no terminal attached. Run by hand you still see your
# errors; run by exec-and-forget or a click_script -- where stderr would be
# thrown away -- they land in the log instead.
[ -t 2 ] || exec 2>>"$DOTFILES_LOG"

_dotfiles_log_exit() {
  local rc=$?
  [ "$rc" -ne 0 ] && printf '%s  %s(%s) exited %s\n' \
    "$(date '+%F %T')" "${0##*/}" "$$" "$rc" >> "$DOTFILES_LOG"
  return 0
}
trap _dotfiles_log_exit EXIT
