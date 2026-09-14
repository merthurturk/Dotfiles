# Backlog

Ideas, not commitments. Ordered by how much they'd change an ordinary day, not
by how interesting they are to build.

Each says roughly what it costs and — where it matters — what makes it safe.
Items are removed from this list when they ship, not ticked off: `dot scene
save`, `dot window send` and `dot window pin` were all here.

---

## Daily convenience

The bar is: *does this remove a decision, a keystroke, or a trip into a config
file?*

### Theme follows the time of day

Light while it's light, dark after sunset. The themes already declare
`appearance` and `dot theme set` already switches macOS with it; this is a
schedule and a preference for which light and which dark theme.

*Small. A launchd agent, or the existing bridge on a timer.*

### Restore the scenes you had

After a reboot, put back the workspaces you were using. The ledger already
records which scene is on which workspace — this is that, persisted across a
restart and replayed.

*Medium, and it needs care: replaying should be opt-in, and never clobber
windows that are already open.*

### Last-scene toggle

`⌥tab` for workspaces exists. The equivalent for scenes — bounce between the two
you're actually using — is one more small capability.

*Small.*

---

## Getting it into other people's hands

### Screenshots and a short recording

Still the largest adoption gap. Everything here is documented carefully and
shown not at all, for a project whose entire point is how it looks.

*Small, but only you can take them.*

### `dot theme new <name>`

Scaffold from an existing theme, then let `check-themes.sh` grade the result.
Copying a directory and hand-editing forty colours is the one place where adding
something isn't pleasant.

*Small.*

### A bar-only install path

For people who already tile and don't want your keybindings. `install.sh` backs
their config up rather than merging, which is safe but all-or-nothing.

*Medium — mostly deciding what the seams are.*

### Make the browser configurable

`dot window split` is built around Chrome's profile picker. `dot window summon`
covers other browsers but has no profile concept.

*Small-to-medium.*

### A Homebrew tap

`brew install merthurturk/tap/dot` instead of clone-and-run.

*Small once there's something to version.*

---

## Platform

### An MCP server over `dot capabilities`

The manifest is already an MCP tool list in all but protocol: ids, arguments,
`destructive`, `guard`, `verify`. A thin adapter would let Claude Desktop — or
anything speaking MCP — drive the machine with those guard rails intact, instead
of only a terminal session.

This is the one with the most leverage, and it's small *because* the design work
is done. The rule to keep: expose `verify` as part of each tool's description so
a client can check the world rather than trust a return value.

*Small-to-medium.*

### Extract the pattern

Self-describing capabilities, declared blast radius, verify-don't-trust,
ledgers rather than prompts — none of that is macOS-specific, and all of it was
learned the hard way. It could be a small framework rather than a folder in one
person's dotfiles.

*Large, and only worth it if someone else wants it.*

---

## Deliberately not doing

**Adding capabilities because we can.** The palette works because it's sixteen
rows you can scan. At forty it becomes a search box you must already know the
answer to.

**Anything that needs an unautomatable prop.** The Focus indicator wanted Full
Disk Access to read and a hand-made Shortcut to write — two of five manual
install steps for one chip. Removing it took the install to three steps and left
nothing needing Full Disk Access at all. A capability that can't state a clean
`guard` and `verify` probably shouldn't exist.
