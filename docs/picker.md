# The picker

`config/aerospace/src/picker.swift`, compiled by `install.sh` to
`config/aerospace/bin/picker` (gitignored — it's a build artefact).

A standalone AppKit chooser: auto-focused search field, fuzzy filter, arrows,
enter, esc. Styled to match the bar — same palette, same Berkeley Mono, 16pt
outer radius with concentric 8pt rows.

## It reads the theme

The palette is **not** compiled in. At launch the picker parses
`~/.config/sketchybar/colors.sh` — the same symlink into the active theme that
the bar reads — so it can't be on a different palette than the surface it
appears over. It held Catppuccin Latte as literals until there was more than
one theme to be wrong about.

The parser is deliberately narrow: `export NAME=0xaarrggbb`, plus
`export NAME=$OTHER`, because the roles are defined by reference
(`WS_ACTIVE_BG=$PINK`). Trailing comments are stripped, the alpha byte is
dropped, and anything else is ignored. Every colour falls back to its old Latte
value, so a missing or malformed file degrades to the previous look rather than
to an unreadable window.

| Picker | Theme key |
|---|---|
| panel background | `BASE` |
| footer bar | `MANTLE` |
| label text | `TEXT` |
| header | `SUBTEXT` |
| border, rule | `SURFACE0` |
| dimmed detail, hint | `OVERLAY0` |
| **selected row** | `WS_ACTIVE_BG` / `WS_ACTIVE_FG` |

The selected row deliberately uses the same pair as the bar's focused workspace
pill, so "this is the one" is a single colour wherever it shows up — pill,
window outline, picker row.

A theme change needs no rebuild: the picker is launched fresh each time and
reads the file on the way up.

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
