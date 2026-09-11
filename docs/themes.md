# Themes

```sh
dot theme list
dot theme set rose-pine-dawn
```

A theme is a directory under `themes/`:

```
themes/<name>/
  colors.sh      the bar palette (every colour the plugins use)
  ghostty.conf   the terminal theme
  meta.json      {name, appearance, ghostty_theme, cursor}
```

`dot theme set` repoints two symlinks, reloads the bar, and regenerates the
desktop picture:

```
config/sketchybar/colors.sh -> themes/<name>/colors.sh
config/ghostty/theme.conf   -> themes/<name>/ghostty.conf
```

Because the bar and terminal read from the same directory, they cannot drift
apart. Ghostty picks the change up on its next config reload (⌘⇧, in a
terminal) — it has no CLI reload.

`config/ghostty/config` ends with `config-file = theme.conf`, which **must stay
last**: later keys win.

## The desktop picture and the screen saver

```sh
dot theme wallpaper            # render for the current theme and apply it
dot theme wallpaper --render-only   # render only, print the path
dot theme wallpaper --show     # what the wallpaper store actually holds
dot theme wallpaper --restore  # back to whatever was set before dot touched it
```

There is no wallpaper file in this repo. The image is **rendered from
`colors.sh`** — the same file the bar reads — so it cannot drift from the
theme, and a new theme gets a wallpaper without anyone drawing one.
`dot theme set` runs this itself; the standalone command is for re-rendering
after a palette edit or on a new display.

The composition is code (`config/aerospace/src/wallpaper.swift`), the colours
are data: four accent glows over `BASE`, placed off the diagonal so the middle
of the screen — where the windows are — stays the quietest part of the image.
Accents are taken in the order `BLUE MAUVE PEACH TEAL PINK GREEN LAVENDER
SAPPHIRE`, **skipping duplicates**: themes alias freely (Rosé Pine Dawn maps
`BLUE`, `GREEN` and pine to one colour) and two glows of the same colour just
collapse into one.

Each glow keeps its accent's *hue* and discards its lightness. The accents here
are darkened for legibility on a light bar — pine is `#286983` — and washing
something that dark over a cream background reads as grey, not as pine.

Renders are cached per theme and per display size in
`~/.local/state/aerospace/wallpaper/`, and regenerated when `colors.sh` or the
renderer is newer than the cached file.

## Outlines, not shadows

Surfaces here are separated by drawing their edge, never by lifting them off
the background:

| Surface | Edge |
|---|---|
| the bar | `BAR_COLOR` / `BAR_BORDER_COLOR` — transparent in Opal White, so the chips float on the wallpaper and the bar itself draws nothing |
| chips in the bar | `background.border_width=1`, transparent until they mean something |
| windows | JankyBorders, `config/borders/bordersrc` |
| window screenshots | `com.apple.screencapture disable-shadow`, set by `install.sh` |

A theme therefore has to define two more colours:

```sh
export WINDOW_BORDER_ACTIVE=$BLUE       # same accent as the focused pill
export WINDOW_BORDER_INACTIVE=$SURFACE1 # same line as the bar's own border
```

Focused windows take **the same accent as the focused workspace pill**, so
"where am I" is one colour wherever you look for it.

`bordersrc` sources `~/.config/sketchybar/colors.sh` — the symlink into the
active theme — so the outlines cannot be on a different palette than the bar.
A second `borders` invocation retints the running process instead of starting
another, which is all `dot theme set` has to do.

**macOS's own window shadow stays.** It can be read but not written from an
unprivileged process — three separate SkyLight calls all report success and
change nothing, measured in [macos](macos.md). Turning it off needs yabai's
scripting addition and a partially disabled SIP. The outline is sharp enough to
carry the edge on its own.

## Accents must be darkened

Both shipped themes are light, and in both the upstream accents are unusable as
a filled chip with a label on it:

| | white text on it | dark text on it |
|---|---|---|
| Catppuccin Latte peach `#fe640b` (Opal White's upstream) | 2.64:1 | 2.68:1 |
| Rosé Pine Dawn gold `#ea9d34` | 2.05:1 | — |

Neither direction passes 4.5:1. These palettes are designed for syntax
highlighting — coloured text on a background — not for coloured backgrounds
carrying text.

So accents are **darkened until white text on them clears 4.5:1**, and scene
badges use three values rather than one:

| Role | Use |
|---|---|
| `_TINT` | pale fill for an unfocused badge |
| `_EDGE` | tint darkened 8% — defines the shape without an outline |
| `_DEEP` | text on the tint, and the fill when focused |

Measure, don't eyeball. Every pair in both themes was computed and checked.

## The Opal family

**Opal White** is the root. Variants are `opal-<variety>`, named after real
opal varieties so a variant never needs an invented suffix:

| Directory | What it would be |
|---|---|
| `opal-white/` | the pale one — this is it |
| `opal-fire/` | warm surfaces, amber and rose accents |
| `opal-black/` | the dark one; `appearance` flips to `dark` |

A variant is a **copy of `themes/opal-white/` with different colours**. If a
variant needs a script changed, that change belongs in the script for every
theme, not in the variant — the whole point of the layout is that adding a look
never means adding a branch. The two places that make this work are already
data: every colour the bar draws comes from `colors.sh`, and the wallpaper is
rendered from those same values.

`ghostty_theme` is the exception to "it's all ours": it names a palette Ghostty
ships and knows how to load, so a variant either keeps pointing at an upstream
theme or defines its colours inline in `ghostty.conf`.

Themes outside the family — `rose-pine-dawn` — are whole other palettes, not
Opal variants, and are free to make different choices. They still have to
define the same keys.

## Adding a theme

Copy a directory, edit `colors.sh`, add `meta.json` and `ghostty.conf`. It
appears in `dot theme list` and the palette immediately.

A theme needs no wallpaper of its own — one is rendered from its accents. Look
at the result before committing with

```sh
open "$(dot theme wallpaper <name> --render-only)"
```

which renders without touching what is currently on screen. A palette whose
accents are all one hue produces a flat image.

`colors.sh` must define everything the plugins reference: surfaces, `TEXT`,
`SUBTEXT`, the accent names, `BAR_*`, `GROUP_*`, `WS_*`, `WINDOW_BORDER_*` and
the five `BADGE_*_{TINT,EDGE,DEEP}` triplets. Missing a badge colour is not fatal — the
pill falls back to ordinary colours — but missing `WS_*` is.
