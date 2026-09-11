# The bar

SketchyBar, configured by `config/sketchybar/sketchybarrc`. Plugins live in
`config/sketchybar/plugins/`.

## Items, left to right

| Item | Plugin | Notes |
|---|---|---|
| `scene` | `scene_click.sh` | ☕ launcher. Left click opens a scene, right click closes one |
| `space.<N>` | `aerospace.sh` | one per workspace, drawn only when occupied or focused |
| `spaces_watcher` | `aerospace.sh` | hidden driver; repaints every pill in one batched call |
| `aerospace_mode` | `mode.sh` | binding-mode badge |
| `separator` | — | thin divider |
| `front_app` | `front_app.sh` | focused app, with its glyph |
| `music` | `music.sh` / `music_click.sh` | now playing; hidden when Music isn't running |
| `status` | — | bracket grouping volume, battery, clock |
| `focus` | `focus.sh` / `focus_click.sh` | macOS Focus chip |

## One script repaints all the pills

`spaces_watcher` is a hidden item whose script is `aerospace.sh`. It rebuilds
every `space.*` pill in **one** batched `sketchybar --set` call, from a single
`aerospace list-windows` query. Individual pills have no update logic.

It runs on `aerospace_workspace_change` (fired by the event bridge),
`front_app_switched`, `space_windows_change`, `display_change`, and a 5s poll.

## Geometry is derived, not hardcoded

```
BAR_HEIGHT=36   BAR_RADIUS=16
PILL_HEIGHT=26  PILL_INSET=(36-26)/2=5   PILL_RADIUS=16-5=11
ITEM_PADDING=4  BAR_PADDING=PILL_INSET-ITEM_PADDING=1
```

Two rules produced those numbers:

**Concentric rounding.** A nested radius is the outer radius minus the gap
between the edges, so the curves stay parallel.

**The inset must be uniform.** Chips originally sat 5pt from the top and 12pt
from the sides, which broke the concentric relationship and read as wrong. A
chip's distance from the bar edge is `bar padding + item padding`, so the bar's
own padding is whatever is left after the per-item padding that spaces chips
from each other.

16pt was measured off a real macOS 26 window, not guessed — see
[macos.md](macos.md#window-corners-are-squircles).

## Fonts

`config/sketchybar/fonts.sh`, shared with the plugins that set fonts themselves.

- **Text** is Berkeley Mono — bar labels, picker, terminal.
- **Icon glyphs** are Hack Nerd Font, because Berkeley Mono has no Nerd glyphs.
- **App glyphs** in the pills are `sketchybar-app-font`, via `icon_map.sh`.

The trap: every Berkeley Mono weight installs as its **own family** with style
`Regular`. `Berkeley Mono:Bold:13.0` silently falls back to the system font —
it looks fine and renders no Berkeley at all. Weight comes from the family name:
`Berkeley Mono Bold SemiCondensed:Regular`.

Berkeley Mono is commercial and can't ship here, so `fonts.sh` probes for it and
falls back to Hack.

## Colour

`config/sketchybar/colors.sh` is a **symlink into the active theme** — see
[themes.md](themes.md). Semantic names (`WS_ACTIVE_BG`, `GROUP_BG`,
`BADGE_PEACH_DEEP`) are separate from raw palette values, so plugins never name
a colour directly.

## Hover

`hover.sh` gives clickable items a blue ring on `mouse.entered`. It changes
**only the border**, never the fill: these items have state-driven backgrounds,
so a ring reads correctly over all of them without knowing which state it is
interrupting. On exit the item's own updater re-runs, restoring the right state
colour rather than a hardcoded one.

SketchyBar has no cursor property — the pointer can't become a hand.
