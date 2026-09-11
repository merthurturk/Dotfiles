# Architecture

Four moving parts, plus a repo that owns all of their config.

```
        AeroSpace  ──events──▶  event-bridge  ──triggers──▶  SketchyBar
      (tiling WM)                (launchd)                    (the bar)
           ▲                                                      │
           │ commands                                    scripts   │ publishes
           │                                                      ▼
          dot  ◀──── palette / keys / bar buttons ────  ~/.local/state/aerospace/
     (the surface)                                          (focus, scenes, …)
```

## Who owns what

| Part | Role |
|---|---|
| **AeroSpace** | tiles windows, owns workspaces and keybindings |
| **event-bridge** | a launchd agent translating AeroSpace events into bar triggers |
| **SketchyBar** | draws the bar; its plugins are the only things with Full Disk Access |
| **dot** | the command surface everything else calls into |

## Why the bridge exists

`aerospace.toml` used to carry ~40 copies of
`exec-and-forget sketchybar --trigger …` — one on every workspace-move binding,
plus the workspace-change callback, plus one per service-mode binding. Every new
binding had to remember to bolt one on.

`config/aerospace/event-bridge.sh` subscribes to AeroSpace's event stream once
and does it centrally. It also catches `window-detected`, which no binding could
provide: a window opening without its app becoming frontmost was invisible.

**AeroSpace's complete event list** — there is nothing else to subscribe to:

```
focus-changed   focused-monitor-changed   focused-workspace-changed
mode-changed    window-detected           binding-triggered
```

Note what's missing: **no window-closed, no window-moved**. Moving the *focused*
window emits `focus-changed` as a side effect, which covers the common case, but
closing a window and moving one by id from a script emit nothing at all. That's
why `spaces_watcher` in `sketchybarrc` also polls every 5s. The poll is the
backstop, not the mechanism.

The agent runs under launchd with `KeepAlive`, because the event stream ends
whenever AeroSpace restarts.

## State, and who writes it

Everything lives in `~/.local/state/aerospace/` — none of it is in the repo.

| File | Written by | Read by |
|---|---|---|
| `focus` | `plugins/focus.sh` | `dot focus status`, the palette |
| `scenes` | `scene.sh` | `dot scene list/close`, the workspace pills |
| `theme` | `dot theme set` | `dot theme list`, `doctor` |
| `log` | `logging.sh` | you, `doctor` |
| `audit.log` | `dot` capabilities | you |
| `picker-*.history` | the picker | the picker (frecency) |

`focus` deserves a note: **only SketchyBar has Full Disk Access**, so it is the
only process that can read the TCC-protected Focus database. It publishes what
it reads to that file, and everything else — including anything running under
AeroSpace, which has no FDA — reads the file instead. One process holds the
permission; the rest consume its output.

## Symlinks

`install.sh` links the repo into place, so editing either path edits one file:

```
aerospace.toml              -> ~/.aerospace.toml
config/<name>/              -> ~/.config/<name>/
bin/dot                     -> ~/.local/bin/dot
launchd/*.plist             -> ~/Library/LaunchAgents/   (copied, $HOME substituted)
```

Within the repo, two more point at the active theme:

```
config/sketchybar/colors.sh -> themes/<active>/colors.sh
config/ghostty/theme.conf   -> themes/<active>/ghostty.conf
```

## Read next

- [capabilities.md](capabilities.md) — the `dot` surface and how to extend it
- [bar.md](bar.md) — SketchyBar items, plugins and events
- [scenes.md](scenes.md) · [themes.md](themes.md) · [picker.md](picker.md)
- [macos.md](macos.md) — the platform constraints that shaped all of this
- [troubleshooting.md](troubleshooting.md)
