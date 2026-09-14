# Backlog

Ideas, not commitments. Ordered by how much they'd change an ordinary day, not
by how interesting they are to build.

Each says roughly what it costs and — where it matters — what makes it safe.
Items are removed from this list when they ship, not ticked off.

**The Daily convenience section is empty**, which is the point of having had
one. `dot scene save`, `dot scene edit`, `dot scene move`, `dot scene last`,
`dot scene restore`, `dot window send`, `dot window pin`, `dot window geometry`
and `dot theme auto` were all in it.

What is left is engineering depth, distribution and platform work. Worth doing;
none of it changes your Tuesday.

---

## Found by review, not yet done

A four-angle review of the scene/window work (reuse, simplification,
efficiency, altitude) produced three commits of fixes. These are the findings
that were **deliberately left** — each is a redesign rather than a cleanup, and
each changes behaviour, so none belonged in a tidy-up pass.

### Let the reflow queue go, and measure instead

`dot window reflow` writes `~/.local/state/aerospace/reflow-pending` for the
workspaces it cannot resize yet, and the bar drains it on arrival. But that
file carries nothing the system doesn't already have: its contents are exactly
*(ledger workspaces) ∖ (visible)*, and reflow reads both. Worse, the queue goes
stale in ways the ledger doesn't — a queued workspace can be closed, or moved
by `dot scene move` (the ledger row follows, the queue entry doesn't).

`dot window geometry` now makes the better version possible: on arrival, ask
whether this workspace's split *actually* matches its declared ratio and fix it
only if not. That is self-healing, needs no file, and is the repo's own
"verify against the world" rule applied to the one place still keeping a note
instead of looking.

*Medium. It also removes the bar plugin's knowledge of reflow's queue path,
file format and private `--now` flag.*

### ~~One window snapshot for the whole palette~~ — measured, not worth it

The estimate behind this was wrong. It is not thirty descriptors opening their
own connection; it is **nine calls in the worst case**, from five capabilities,
at about 7ms each and running in parallel. Deduplicating them would buy perhaps
5ms of a 163ms open, in exchange for threading a snapshot through an interface
this project promises to keep simple.

Left here as a record of the measurement, so nobody re-derives the same wrong
estimate from the same plausible reasoning.

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
