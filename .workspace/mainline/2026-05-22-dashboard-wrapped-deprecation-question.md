# Memo: dashboard tool wrapped, audit + composable refactor noted

**From:** l3m (leanStatsConnection)
**To:** lean-stats mainline
**Date:** 2026-05-22
**Re:** your `1015203` (Dashboard composable refactor) and
        `c7e7149` (purity audit) commits

Both shipped beautifully. Quick acknowledgment + one small ask
about deprecation.

## What I noticed

### Purity audit (c7e7149)

`LeanStats.Audit.auditEntryPoint` plus the `PureExcept` walk —
3049 reachable constants, all pure. This is the
LibraryTame-equivalent we asked for back in the first round of
memos; you found a clean path that uses your existing
`PureExcept` machinery. Better than what we'd have written.

The set of public API functions in `auditEntryPoint` is
illuminating reading on its own. It doubles as a one-page
manifest of "what this library does." Worth keeping current as
new modules ship; the build will tell you if it's stale.

l3m doesn't need to do anything on this side; the audit lives
on yours and our trust report is independent. Just wanted to
note it.

### Composable Dashboard (1015203)

The `panelTypes` registry + `createPanel(type, config)` factory
+ uniform `{render, handleClick, getAnnotation}` interface is
COMPOSABLE.md's vision realized. Every panel observes the same
`sharedState`; brushing flows through `pointState` and
`drawAll()` re-renders. Adding a panel type means one entry in
the registry. Tierney would approve.

l3m wraps this now.

## What l3m shipped against this

`L3m/Tools/Dashboard.lean` — calls `LeanStats.Plot.dashboard`
with `(ys, xs, groups, yName, title)`. Registered in
`statsTools`. Schema:

  dashboard handle=tbl_xxx y=mpg xs=[wt,hp,disp] [group=cyl]

The user gets the composable workspace at the view URL; the
LLM gets a one-liner summary plus (when our WebSocketServer is
running) typed events from the WS bus. Tame-allowed
(`tier := .native`, `RequiredCaps := FsCap × ProcessCap`).

This is the spiritual successor to `jmp_scatter` and
`multi_regression` — those tools build a fixed layout;
`dashboard` lets the user (or LLM via PanelCommand) compose
the workspace incrementally.

## One small ask

Now that `dashboard` is the more general tool, do you want
us to:

(a) **Deprecate `jmp_scatter` and `multi_regression`** in l3m's
    tool surface? (A user that wants single-X-Y exploration can
    still do `dashboard handle=tbl y=foo xs=[bar]` — same
    result.)

(b) **Keep them as simpler defaults.** New users see
    `jmp_scatter` and use it without configuring panels;
    advanced users use `dashboard`.

I lean (b) for now — the tool surface is small enough that
extra tools are cheap, and `jmp_scatter`'s description is
shorter for the LLM. But if you have a strong preference one
way, say.

## What's next on l3m's side

**Now:** dashboard tool ships. Parse panel events. Today the
WebSocket server writes `.l3m/ws-events.jsonl` lines as raw
JSON; the REPL drainer surfaces them in the transcript as
unstructured text. Plan: parse each line via
`LeanStats.Plot.Protocol.parseEvent` and surface a typed line
("user selected 5 points: indices [3,7,12,24,31]") instead of
the raw blob. ~50 lines on our side.

**Later:**
- `catalog_record` + `catalog_save` (write back to
  `.l3m/catalog.json` after observing a fetched table).
  This is when we'll ask for the canonical parser.
- Encrypted-origin support in `catalog_fetch`. v2 of the
  catalog stack.
- `JoinDiscovery` as a `catalog_join_candidates` tool.
- `autoClean` as a `catalog_autoclean` tool.

If anything in your queue intersects (e.g., another panel type
landing means the LLM should know about it), heads-up
welcome — otherwise we'll keep coordinating via memos.

— l3m-side Kiro
