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
apart — but they can restate the same colour twice, and once did. See
"The terminal half" below.

`config/ghostty/config` ends with `config-file = theme.conf`, which **must stay
last**: later keys win. That file holds **no colours at all** — a colour there
outlives every theme change, and `dot doctor` fails if one appears.

### The terminal half

A theme's `ghostty.conf` either points at an upstream palette Ghostty ships
(`theme = Catppuccin Latte`, which is what Opal White does) or sets
`background`, `foreground` and all 16 palette entries itself, which is what
Fire and Black do because they have no upstream.

The inline form restates numbers that `colors.sh` already holds, and that
duplication bit immediately: Fire's palette was rewritten and its `ghostty.conf`
kept the old background for an hour. `bin/check-themes.sh` now compares the two
and fails if they disagree.

### Repainting Ghostty

Ghostty reads its config once and offers no way to be told to read it again:
no IPC on macOS (`+new-window` answers "not supported on this platform"), and
no reload action in the CLI. `reload_config` exists only as a keybind.

But Ghostty is a terminal, and a terminal repaints itself when you write **OSC
escape sequences** to its tty. `dot theme set` writes them straight to each
open pane:

| Sequence | Sets |
|---|---|
| `OSC 10` | foreground |
| `OSC 11` | background |
| `OSC 12` | cursor |
| `OSC 4;N` | palette entry N |

No keystroke, no permission, no focus change, and it works whether Ghostty is
frontmost, buried, or on another workspace. The panes are found as the ttys of
the Ghostty process's children.

The colours come from `ghostty +show-config` — Ghostty's own resolved view of
the active `theme.conf` — so a theme pointing at an upstream palette works
exactly like one that spells every colour out.

A repaint changes the panes but not the window chrome, which only a real config
reload updates. When Ghostty happens to be frontmost, `dot theme set` sends its
built-in ⌘⇧, as well, since a keystroke costs nothing there and cannot miss.

An earlier version of this registered `reload_config` as a global hotkey and
pressed it from outside. It was removed: it burned a global chord, and it could
not bootstrap — a running Ghostty only knows the keybinds it launched with, so
the chord did nothing until Ghostty had already been reloaded by hand.

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

**Which composition** is the theme's decision, via `WALLPAPER_STYLE`:

| Style | |
|---|---|
| `glow` (default) | four accent glows over `BASE`; stays out of the way |
| `grid` | sun, horizon and perspective grid — what `synthwave` uses |

A style is *code*, because a composition is code: `grid` draws its sun clipped
to the horizon, its grid as a wide dim stroke under a narrow bright one, and
its stars from a fixed seed so re-rendering doesn't produce a different image.
What the theme supplies is which colours to build it from.

**Which accents** is likewise the theme's, via `WALLPAPER_ACCENTS`:

```sh
export WALLPAPER_ACCENTS="PEACH MAROON YELLOW ROSEWATER"   # Opal Fire
export WALLPAPER_ACCENTS="YELLOW PINK SKY MAUVE"           # Synthwave
```

For `glow` the order is just paint. For `grid` it is positional — sun top, sun
bottom, grid, sky — which is the price of a composition having parts.

That used to be a fixed list in the script, starting `BLUE MAUVE`. Every theme
therefore got a blue-and-violet wallpaper, and the warm variant came out as the
pale one with a single warm corner — the palettes differed and the wallpapers
didn't. A wallpaper is most of what a variant looks like, so the list belongs
to the theme.

A theme that declares nothing falls back to the old order. Duplicates are
skipped either way: themes alias freely (Rosé Pine Dawn maps `BLUE`, `GREEN`
and pine to one colour) and two glows of the same colour collapse into one.

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

Measure, don't eyeball — with a command, not by hand:

```sh
bin/check-themes.sh
```

It sources every theme, checks that no required key is missing, and measures
every pair that carries text against WCAG's 4.5:1. Edges are printed but never
failed: an unfocused outline is *meant* to be quiet, and `WINDOW_BORDER_INACTIVE`
sits around 1.6:1 on purpose.

This exists because hand-checking wasn't enough. When it was first run against
the palette this repo had been shipping, it found `WS_ACTIVE_FG` on
`WS_ACTIVE_BG` — the focused workspace pill, the most-read chip in the bar — at
**4.34:1**, and `SUBTEXT` failing in both themes. Both are fixed; the checker
is what stops it happening to the next variant.

## The Opal family

**Opal White** is the root. Variants are `opal-<variety>`, named after real
opal varieties so a variant never needs an invented suffix:

| Directory | | |
|---|---|---|
| `opal-white/` | light | pale, blue and violet play |
| `opal-fire/` | light | warm surfaces, terracotta accent |
| `opal-black/` | **dark** | near-black with vivid flashes |

All three share the structure, the transparent bar and the outlines. They
differ only in `colors.sh`, `ghostty.conf` and `meta.json` — no script knows
which one is active.

A variant is a **copy of `themes/opal-white/` with different colours**. If a
variant needs a script changed, that change belongs in the script for every
theme, not in the variant — the whole point of the layout is that adding a look
never means adding a branch. The two places that make this work are already
data: every colour the bar draws comes from `colors.sh`, and the wallpaper is
rendered from those same values.

`ghostty_theme` is the exception to "it's all ours": it names a palette Ghostty
ships and knows how to load. Opal White points at Catppuccin Latte that way;
Fire and Black have no upstream, so they set `background`, `foreground` and all
16 palette entries inline instead. Either is fine — there just has to be a
terminal palette that matches the bar.

### Appearance is theme data

`meta.json`'s `appearance` is not a label. `dot theme set` reads it and
switches the macOS light/dark setting to match, so Opal Black takes the system
dark and switching back to White or Fire returns it to light. Without that, the
bar is themed and every unthemed window — Finder, System Settings, every dialog
— disagrees with it.

macOS has no CLI for this; System Events over AppleScript is the supported
route, and it needs Automation permission the first time. The result is read
back rather than assumed, and `dot doctor` reports the two drifting apart.

### Dark variants invert the badges

`_TINT` is described above as "pale fill" and `_DEEP` as the saturated colour
on top of it. On a dark theme both flip: `_TINT` is a dark wash, `_DEEP` is the
bright accent that sits on it, and `_EDGE` is the tint stepped *away* from the
background rather than darker than it. The rule that survives either way is the
relationship — `_EDGE` defines the chip's shape without an outline, and `_DEEP`
has to be legible both on the tint and under `BASE` when the scene is focused.

Themes outside the family — `rose-pine-dawn`, `synthwave` — are whole other
palettes, not Opal variants, and are free to make different choices. They still
have to define the same keys.

`synthwave` is the useful example of how far that goes. It breaks two family
rules on purpose, and says so at the top of its `colors.sh`:

- **It gives the bar a surface again.** Floating chips work over a quiet wash;
  over a sunset and a glowing grid, the items with no background of their own
  (the app name, the separator) would sit straight on top of the picture.
- **Its wallpaper is a composition, not a wash** — `WALLPAPER_STYLE=grid`.

Neither needed a change to a script, which is the point of the layout.

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
