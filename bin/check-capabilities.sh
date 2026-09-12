#!/usr/bin/env bash
#
# Validates the capability surface.
#
# This replaces check-launcher.sh, which existed to police drift between the
# palette and the real keybindings. The palette is now rendered from the
# capabilities themselves, so that drift can't happen -- what's left to check is
# that every capability actually describes itself correctly.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBEXEC="$REPO/libexec/dot"
export DOT_ROOT="$REPO"

fail=0
n=0

for cmd in "$LIBEXEC"/*; do
  name="$(basename "$cmd")"
  case "$name" in _*) continue ;; esac
  n=$((n+1))

  [ -x "$cmd" ] || { echo "not executable: $name" >&2; fail=1; continue; }

  d="$("$cmd" --describe 2>/dev/null)"
  if ! printf '%s' "$d" | jq -e . >/dev/null 2>&1; then
    echo "$name: --describe did not produce valid JSON" >&2; fail=1; continue
  fi

  for field in id summary destructive; do
    if ! printf '%s' "$d" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
      echo "$name: descriptor is missing .$field" >&2; fail=1
    fi
  done

  # Destructive capabilities must say how they're guarded -- that convention is
  # the only thing standing between an agent and an irreversible mistake.
  if printf '%s' "$d" | jq -e '.destructive == true' >/dev/null 2>&1; then
    printf '%s' "$d" | jq -e 'has("guard")' >/dev/null 2>&1 || {
      echo "$name: destructive but declares no .guard" >&2; fail=1; }
  fi

  # Menu rows must be runnable: args have to be an array of scalars.
  printf '%s' "$d" | jq -e '
    (.instances // []) | all(has("label") and ((.args // []) | type == "array"))
  ' >/dev/null 2>&1 || { echo "$name: malformed .instances" >&2; fail=1; }
done

# The palette must render without error.
"$REPO/libexec/dot/menu" --dry-run >/dev/null 2>&1 \
  || { echo "menu --dry-run failed" >&2; fail=1; }

# ...and every row it renders must map to a capability that exists. A
# descriptor's `command` is a label ("dot theme set") that the menu turns back
# into a path, so a row can render perfectly while pointing at nothing.
#
# Note what this does *not* cover: whether the resolved command can actually be
# executed in the environment the menu runs in. The launcher once did nothing
# for every theme because `dot` is absent from the PATH AeroSpace execs with,
# and every file involved existed and was executable. That class of failure is
# caught by the menu itself, which refuses to run a command it cannot resolve
# and says so in the log.
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  set -- $cmd                      # "dot theme set" -> dot / theme / set
  shift                            # drop the "dot"
  if   [ $# -ge 2 ] && [ -x "$LIBEXEC/$1-$2" ]; then :
  elif [ $# -ge 1 ] && [ -x "$LIBEXEC/$1" ];     then :
  else
    echo "palette row is not runnable: $cmd" >&2
    fail=1
  fi
done < <(DOT_ROOT="$REPO" "$REPO/bin/dot" capabilities --json \
         | jq -r '.[] | select(((.instances // []) | length) > 0) | .command')

[ "$fail" -eq 0 ] && echo "ok: $n capabilities valid, menu renders"
exit "$fail"
