---
name: dot
description: Control this macOS setup (AeroSpace tiling, SketchyBar, scenes, themes, Focus) through the `dot` command. Use whenever the request is to change, inspect or troubleshoot the window manager, the bar, a scene, the theme, or macOS Focus.
---

# dot

`dot` is the single entry point for everything this machine's setup can do.
**Never edit config files directly to make a change that `dot` can make** — the
command is the supported surface, it audits what it does, and it declares what
is destructive.

## Discover before acting

```sh
dot capabilities --json
```

Returns every capability with its `id`, `summary`, `args`, `destructive` flag,
`guard`, and a `verify` command. Read this rather than grepping the scripts.

## Verify, don't trust exit codes

Several tools in this stack report success while doing nothing — AeroSpace in
particular will accept `layout tiling` and not move a window. Whenever a
capability declares `verify`, run it and check the world changed:

```sh
dot scene open chill && dot scene list --json
dot theme set rose-pine-dawn && dot theme list --json
```

## Destructive capabilities

Anything with `"destructive": true` also declares a `guard`. Respect it:
`dot scene close` deliberately refuses workspaces it didn't open, because focus
drifts and "close the focused workspace" will eventually fire at the wrong one.
`--force` exists; using it without the user asking is not appropriate.

## What `dot` cannot do

TCC permissions — Full Disk Access, Accessibility, Automation — cannot be
granted by any process. `dot doctor` reports what is missing and exactly where
to click; surface that to the user rather than trying to work around it.

macOS also has no CLI for changing Focus; `dot focus toggle` runs a Shortcuts
shortcut, which the user must have created.

## Health

```sh
dot doctor                    # symlinks, packages, fonts, services, permissions
bin/check-capabilities.sh     # every capability describes itself correctly
```

## Adding a capability

Create `libexec/dot/<group>-<verb>`, answering `--describe` with a JSON
descriptor. That is the only registration step — the palette, `dot help` and
this manifest all read from it. Add `instances` to make it appear in the ⌥space
palette; omit them for query-only commands.
