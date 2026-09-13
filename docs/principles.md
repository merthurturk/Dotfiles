# Principles

Not aspirations. Each of these is either enforced by a check, or was paid for by
a bug that is named here so the reasoning survives the person who hit it.

---

## One thing, one place

A capability is **one file that describes itself**. That descriptor is the only
registration — the ⌥space palette, `dot help`, `dot capabilities --json` and the
validator all read it. Adding a capability makes it appear everywhere it should;
removing one removes it everywhere.

The same rule elsewhere: scenes are data in `scenes.json`, themes are
directories under `themes/`, keybinding hints are read out of `aerospace.toml`
rather than typed a second time.

**What it cost to learn.** The palette used to be a hand-written list, with
`check-launcher.sh` existing purely to catch drift between it and the real
bindings. Both are gone: the drift can't happen when there's nothing to drift
from. And every scene once claimed the keybinding `⌥⇧space`, including scenes
with no binding at all, because the hints were hardcoded.

## Verify against the world, not the exit code

Exit codes here are not evidence.

AeroSpace returns `0` and does nothing, routinely. It reported *"already
tiling"* for a window its own `resize` then refused as floating. A SketchyBar
font string that doesn't resolve falls back silently and looks perfectly fine.

So capabilities that mutate declare a **`verify`** command — something that
proves the change landed — and factual claims get measured. The bar's 16pt
corner radius came from decoding a screenshot and fitting a superellipse, and
the method was validated against a control whose answer was already known before
being trusted on the unknown.

## Destructive actions need a ledger, not a prompt

`dot scene close` refuses any workspace it didn't open, and records **which
windows** it opened so it closes only those.

**What it cost to learn.** Twice. The first version asked for confirmation and
closed the wrong window anyway, because a dialog is easy to click through and
focus drifts on its own. The second recorded only the workspace and pruned the
entry once that workspace was empty — so a stale entry survived if the scene's
windows had gone but you'd since put your own there, and `close` destroyed them.
That is not hypothetical; it happened during testing.

`--force` still exists, for when clearing the whole workspace is what you mean.

## Never trust focus

Activating an app moves focus, and an empty workspace has no window to hold it —
AeroSpace falls back to the previously focused window. So a window opened "onto"
an empty workspace is born somewhere else entirely.

Capture the target **before** opening anything, move windows **by id**, and
assert the destination again at the end. This caused three separate bugs —
scenes opening on the wrong workspace, `dot ai` doing the same, `chrome-split`
waiting for a window on a workspace it was no longer on — before it became a
rule. The menu now exports `DOT_ORIG_WS`/`DOT_ORIG_WID`, captured before the
picker takes focus, because even asking is a race.

## Measured, not chosen

Every colour a theme puts text on is computed and gated by `bin/check-themes.sh`
in the pre-commit hook.

This is not fussiness. Both palettes worth borrowing shipped accents that fail
outright as a filled chip: Catppuccin Latte's peach reads **2.64:1** under white
text *and* **2.68:1** under dark — neither direction passes. Rosé Pine Dawn's
gold is **2.05:1**. They are beautiful as syntax highlighting, where the colour
is the text, and unusable as a background behind a label.

## Repetitive is not the same as complex

Eight capabilities share a dozen near-identical lines. A helper to collapse them
was written, measured and **reverted**: three of them carry hand-written details
the helper could only express by overriding its own output, and it needed two
escaping fixes before it worked at all.

Fewer lines is not the goal. Twelve obvious lines you can read top to bottom beat
a six-positional API with `--` separators and JSON-merge semantics.

## Discoverable by construction

⌥space is the entire onboarding. You remember one chord, and every entry shows
its own keybinding — so the palette teaches the shortcuts as a side effect of
being used. Because it renders *from* the capabilities rather than alongside
them, it cannot fall behind.

## Latency is a feature

Anything on a path you watch gets measured, not assumed.

Switching workspace was 270ms of visible lag; the cause was ~70 subprocess spawns
in the bar repaint, not the work itself. Opening the palette was 580ms, almost
all of it two `jq` invocations per capability in the assembly. `fonts.sh` cost
70ms *per source* because it asked AppKit whether a font existed — on every
repaint.

The fixes were the same shape each time: gather once, batch the round-trips,
cache what cannot change. Scenes now switch to the destination *before* opening
anything, so windows appear where you are looking instead of being seen to fly
across.

## Honest about the boundary

macOS will not let a script grant Accessibility, and offers no CLI for the
light/dark appearance. Rather than pretend, `dot doctor` names exactly what is
missing and where to click.

The corollary is that a feature which *needs* an unautomatable prop is suspect.
The Focus indicator required Full Disk Access to read state and a hand-made
Shortcuts shortcut to change it — two of five manual install steps for one chip.
Removing it took the install to three steps and left nothing needing Full Disk
Access at all.

## Outlines, not shadows

Nothing floats above anything else. The bar draws a 1px border with its shadow
off, chips outline themselves when they mean something, and window borders use
the same accent as the focused workspace pill — so "where am I" is one colour
wherever you look.

macOS's own window shadow is the exception, and only because it can be read but
not written: three separate SkyLight calls report success and change nothing.
Removing it needs yabai's scripting addition and a partially disabled SIP.
