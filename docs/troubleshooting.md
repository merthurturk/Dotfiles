# Troubleshooting

Start here:

```sh
dot doctor                          # symlinks, packages, fonts, services, permissions
tail ~/.local/state/aerospace/log   # anything that failed silently
tail ~/.local/state/aerospace/audit.log
```

`exec-and-forget` and SketchyBar `click_script`s both discard stderr, so a
broken script is otherwise invisible — which is exactly how one bug survived
until logging existed. `logging.sh` diverts stderr to the log **only when no
terminal is attached**, so running a script by hand still shows its errors
normally.

## The bar isn't updating

The event bridge is the mechanism, not the keybindings.

```sh
launchctl print gui/$(id -u)/sh.dotfiles.aerospace-bridge | grep state
tail ~/.local/state/aerospace/bridge.err
```

It exits whenever AeroSpace restarts and launchd respawns it; that's normal and
appears in the log. If it's not loaded, run `install.sh`.

## Windows overlap / nothing tiles

Check what AeroSpace actually thinks, not what its commands report:

```sh
dot window list --json | jq '.[] | {id, layout, app}'
aerospace list-windows --all --format '%{window-id} %{window-layout} %{workspace-root-container-layout}'
```

`layout=floating` or `root=h_accordion` means `resize` will refuse. Per-window
`layout tiling` sometimes reports "already tiling" while the workspace is still
wrong — restarting AeroSpace re-adopts every window and clears it:

```sh
killall AeroSpace && sleep 2 && open -a AeroSpace
```

That pulls all windows onto one workspace; redistribute afterwards. **Snapshot
first**: `aerospace list-windows --all --format '%{workspace}|%{window-id}|%{app-name}'`.

## A scene opens on the wrong workspace

Shouldn't happen — `scene.sh` moves windows by id rather than trusting focus.
If it does, check that the ledger isn't stale:

```sh
dot scene list --json
cat ~/.local/state/aerospace/scenes
```

## A font looks wrong

A font string that doesn't resolve **silently falls back** and looks like it
worked. Compare widths rather than eyeballing:

```sh
sketchybar --set clock label.font="Berkeley Mono:Bold:13.0"   # falls back!
sketchybar --query clock | jq '.bounding_rects["display-1"].size[0]'
```

Weight comes from the family name, not the style field — see
[bar.md](bar.md#fonts).

## The palette is missing something

It renders from the capability surface, so a missing entry means a missing or
malformed descriptor:

```sh
bin/check-capabilities.sh
dot menu --dry-run
libexec/dot/<name> --describe | jq .
```

Remember: a capability with no `instances` is deliberately CLI-only.
