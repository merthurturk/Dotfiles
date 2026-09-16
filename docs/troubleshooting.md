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

## A scene's split is wrong after changing display

`resize width` takes **absolute points**, so a split computed on a 1710pt laptop
is wrong on a 2560pt monitor — typically the side window ends up a sliver.

```sh
dot window reflow
```

re-applies each open scene's declared ratio, and runs automatically on
`display_change`.

It can only fix a workspace **you are looking at**. AeroSpace gives a hidden one
no geometry at all — its windows sit parked off-screen at whatever size they
last had — so a resize aimed at one lands on nothing. The rest are checked as
you arrive on them, which is the first moment their layout is real.

To see rather than guess:

```sh
dot window geometry --workspace 5
```

A `·` means the workspace is hidden, and its width is parked rather than laid
out. `⌥⇧\` (balance) also fixes an overlap, but equalises the windows and
throws the ratio away.

## A scene opens on the wrong workspace

Shouldn't happen — `scene.sh` moves windows by id rather than trusting focus.
If it does, check that the ledger isn't stale:

```sh
dot scene list --json
cat ~/.local/state/aerospace/scenes
```

## The next event isn't showing in the bar

Three things have to be true, in this order:

```sh
dot doctor | grep -i calendar
```

1. **The calendar is in macOS.** EventKit reads what *System Settings > Internet
   Accounts* syncs. If Google is not there, there is nothing to read — and
   macOS will not even prompt for permission while no account exists. It
   returns "denied" with no error, which looks like a refusal and is a question
   never asked.
2. **The helper has Calendars access.** *Privacy & Security > Calendars*, `dot
   calendar` set to Full Access. Note the pane has **no "+" button**: an app
   only appears there once it has asked, which is why the helper is a `.app`
   with an identity of its own.
3. **The agent is running.** It publishes the files the bar reads:

```sh
launchctl print gui/$(id -u)/sh.dotfiles.calendar | grep state
cat ~/.local/state/aerospace/next-event.tsv
```

An empty `next-event.tsv` with a populated `agenda.tsv` is not a fault: nothing
is left today, so the chip draws nothing.

## The leader key does nothing

`⌥⇧space` enters a mode rather than running something, so the bar should show
`DOT` and the next letter acts. If it does not:

```sh
dot keys | sed -n '/Leader/,/back out/p'   # what the letters are
aerospace reload-config                    # after editing aerospace.toml
```

`esc` always returns to the main mode.

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
