# The picker

`config/aerospace/src/picker.swift`, compiled by `install.sh` to
`config/aerospace/bin/picker` (gitignored — it's a build artefact).

A standalone AppKit chooser: auto-focused search field, fuzzy filter, arrows,
enter, esc. Styled to match the bar — same palette, same Berkeley Mono, 16pt
outer radius with concentric 8pt rows.

## Interface

Reads lines on stdin, prints the choice on stdout. Exit 1 on cancel.

```sh
ls ~/Projects | PICKER_PROMPT="Open project" picker
printf 'api\tgo\nweb\ttypescript\n' | picker      # label <TAB> detail
```

| Variable | Effect |
|---|---|
| `PICKER_PROMPT` | placeholder text |
| `PICKER_MODE=input` | single text field, no list; returns what you typed |
| `PICKER_HEADER` | wrapped text above the field, height measured |
| `PICKER_CONTEXT` | enables frecency, keyed by context |

`input` mode exists so nothing has to fall back to an AppleScript dialog, which
looks like a different program. `dot ai` uses `input` for its prompt and
`HEADER` + two rows for its confirmation.

## Frecency

With `PICKER_CONTEXT` set, choices are recorded in
`~/.local/state/aerospace/picker-<context>.history` and common ones float up.
Contexts are separate so the palette's history and the Chrome profile history
don't contaminate each other.

Match quality still leads when you type; frecency only breaks ties. Recency
decays over a week, so an old favourite yields to a current one without
vanishing.

## Rebuilding

```sh
swiftc -O -o config/aerospace/bin/picker \
          config/aerospace/src/picker.swift -framework AppKit
```

## Things that bit, and why the code looks like it does

**`.nonactivatingPanel` was wrong.** That style mask exists to stop a palette
taking focus — the opposite of what a search field needs. Removed, plus
`becomesKeyOnlyIfNeeded = false`.

**Dismiss-on-blur has to arm late.** A focus bounce during launch fired
`windowDidResignKey` and cancelled the picker before it was usable. It only
arms after the window has held focus once.

**`NSTextField` draws its text at the top of its frame.** Filling the search
band left the placeholder riding high with dead space beneath it; the field is
pinned to the band's centre instead.

**Top-level declaration order matters.** The environment reads were below the
input parsing that used them, so `input` mode always evaluated false and the
picker exited instantly. It compiled fine.
