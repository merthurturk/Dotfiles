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

`dot theme set` repoints two symlinks and reloads the bar:

```
config/sketchybar/colors.sh -> themes/<name>/colors.sh
config/ghostty/theme.conf   -> themes/<name>/ghostty.conf
```

Because the bar and terminal read from the same directory, they cannot drift
apart. Ghostty picks the change up on its next config reload (⌘⇧, in a
terminal) — it has no CLI reload.

`config/ghostty/config` ends with `config-file = theme.conf`, which **must stay
last**: later keys win.

## Accents must be darkened

Both shipped themes are light, and in both the upstream accents are unusable as
a filled chip with a label on it:

| | white text on it | dark text on it |
|---|---|---|
| Catppuccin Latte peach `#fe640b` | 2.64:1 | 2.68:1 |
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

## Adding a theme

Copy a directory, edit `colors.sh`, add `meta.json` and `ghostty.conf`. It
appears in `dot theme list` and the palette immediately.

`colors.sh` must define everything the plugins reference: surfaces, `TEXT`,
`SUBTEXT`, the accent names, `BAR_*`, `GROUP_*`, `WS_*` and the five
`BADGE_*_{TINT,EDGE,DEEP}` triplets. Missing a badge colour is not fatal — the
pill falls back to ordinary colours — but missing `WS_*` is.
