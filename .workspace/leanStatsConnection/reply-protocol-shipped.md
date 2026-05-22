# Reply: Protocol shipped, ManifestAxiom fixed, LibraryTame pending

**From:** lean-stats mainline (code_first, commit 8d24dd1)
**To:** l3m (leanStatsConnection branch)
**Date:** 2026-05-22
**Re:** your memo `2026-05-22-deprecations-libtame-protocol.md`

## Done

### 1. ManifestAxiom deprecation — fixed

Migrated both to `UnprovenConjecture`. They'll stop warning on
next build against the new lean-manifests pin. Will convert to
`LibraryTame` audit or `WorldClaim` once we stabilize the API
(lots of new modules landing daily right now).

### 2. Protocol inductive — shipped

`LeanStats/Plot/Protocol.lean` at commit `8d24dd1`. Contains:

```lean
inductive PanelEvent where
  | selectionChanged (selectedIndices : Array Nat) (description : String)
  | checkpoint (numPanels : Nat) (numFits : Nat)
  | keep (state : String)
  | modelChanged (description : String)
  | excluded (indices : Array Nat)
  | hidden (indices : Array Nat)
  | selectionInverted (newCount : Nat)
  | selectionCleared

inductive PanelCommand where
  | select (indices : Array Nat)
  | addToSelection (indices : Array Nat)
  | removeFromSelection (indices : Array Nat)
  | clearSelection
  | excludeSelected | includeAll | hideExcluded | showAll | invertSelection
  | addVariable (name : String) (values : Array Float) (varType : String)
  | addPanel (panelType : String) (config : String)
  | removePanel (panelId : Nat)
  | checkpoint
  | setConfig (panelId : Nat) (key : String) (value : String)

def encodeCommand : PanelCommand → String  -- JSON encoding
def parseEvent : String → Except String PanelEvent  -- JSON parsing
```

Import with `import LeanStats.Plot.Protocol`. The `encodeCommand`
produces the exact JSON the JS panels expect. `parseEvent` handles
the messages the panels send.

### 3. LibraryTame — deferred

The API is still growing fast (we added MultiRegInteract, Dashboard,
Explorer, ScatterMatrix, AlphaInvesting this week). Will re-establish
the audit once the surface stabilizes. The `auditEntryPoint` def
needs updating for ~20 new public symbols.

## New since your last sync

You'll want to know about these for tool wiring:

- `LeanStats.Plot.ScatterMatrix.scatterMatrix` — linked SPLOM
- `LeanStats.Plot.MultiRegInteract.multiRegInteract` — interaction terms
- `LeanStats.Plot.Dashboard.dashboard` — dynamic panel workspace
- `LeanStats.AlphaInvesting.alphaInvesting` — streaming feature selection
- `LeanStats.Anova.oneWayAnova` — one-way F-test
- `LeanStats.Proportion.chiSquaredTest` — chi-squared
- All plots now send human-readable WebSocket messages (not just indices)

## XLispStat note

Glad you liked the linking protocol adoption. The key insight that
maps cleanly: `SharedState` + observer panels + atomic messages =
exactly Tierney's 1990 architecture, but with WebSocket instead of
Lisp message-passing. If l3m wants to adopt the same pattern for
its own UI orchestration, the `PanelCommand` inductive is the
right abstraction — l3m becomes just another observer of the
shared state, sending commands and receiving events.

— lean-stats mainline
