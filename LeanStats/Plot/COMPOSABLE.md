# Composable Panel Protocol — design for linked interactive graphics

## The XLispStat insight

Every plot is an **observer** of a shared data/state model. When state
changes (point selected, data transformed, variable added), all
observers update. Plots don't know about each other — they only know
about the shared state.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SharedState                        │
│  - points: Array { values, metadata, state }         │
│  - variables: Map<name, Array Float | Array String>  │
│  - selection: Set<index>                             │
│  - excluded: Set<index>                              │
│  - hidden: Set<index>                                │
│  - fits: Array { frozen coefficients, color, ... }   │
└──────────────┬───────────────────────────────────────┘
               │ notify()
    ┌──────────┼──────────┬──────────────┐
    ▼          ▼          ▼              ▼
 Panel 0    Panel 1    Panel 2    ... Panel N
 (scatter)  (histo)    (scatter)      (boxplot)
```

## Panel interface

Every panel implements:

```js
{
  type: "scatter" | "histogram" | "boxplot" | "qq" | "residual",
  config: { x: "wt", y: "mpg", transform: "log", degree: 1, ... },
  svgId: "panel_0",

  // Called when shared state changes
  render(state) → void,

  // Called when user clicks inside this panel
  handleClick(event, state) → stateChange | null,

  // Returns what this panel contributes to the tooltip
  describePoint(index, state) → string,
}
```

## Messages (state changes)

State changes are atomic operations on SharedState:

| Message | Effect |
|---------|--------|
| `select(ids)` | Set selection to exactly these ids |
| `addToSelection(ids)` | Union with current selection |
| `removeFromSelection(ids)` | Subtract from selection |
| `clearSelection()` | Empty the selection |
| `exclude(ids)` | Mark as excluded |
| `include(ids)` | Unmark excluded |
| `hide(ids)` | Mark as hidden |
| `show(ids)` | Unmark hidden |
| `invertSelection()` | Flip selection on visible points |
| `addVariable(name, values, type)` | Add a new variable |
| `addPanel(type, config)` | Create a new panel |
| `removePanel(id)` | Remove a panel |
| `checkpoint()` | Freeze current fit lines |
| `setConfig(panelId, config)` | Update a panel's settings |

After any state change: `panels.forEach(p => p.render(state))`.

## Point as first-class object

Each point (observation) carries:

```js
{
  index: 0,                    // row number
  values: { wt: 2.62, hp: 110, mpg: 21.0, cyl: "6" },
  state: { selected: false, excluded: false, hidden: false },
  label: "Mazda RX4",         // optional row label
  color: null,                // override color (for group coloring)
}
```

When you hover point i in ANY panel, ALL panels highlight point i
and show its label. This is the cross-panel identification that
makes linked plots powerful.

## Scatterplot matrix

A scatterplot matrix is just:

```js
for (let i = 0; i < vars.length; i++)
  for (let j = 0; j < vars.length; j++)
    if (i != j) addPanel("scatter", { x: vars[j], y: vars[i] })
    else addPanel("histogram", { var: vars[i] })
```

All panels share the same SharedState. Selection in one cell
highlights in all cells. The diagonal shows histograms (or
density plots) of each variable.

## How this maps to our Lean code

The Lean function generates the HTML/JS. The JS implements the
protocol. The Lean function's job is:

1. Serialize the data (all variables as JSON arrays)
2. Emit the SharedState initialization
3. Emit the panel factory (createPanel function)
4. Emit the initial panel layout
5. Emit the WebSocket handler (for l3m commands)
6. Emit the CSS grid/flex layout

The panel rendering code is JS. The panel TYPES are defined in JS.
Adding a new panel type means adding a new `case` in the factory.

## Comparison to current Dashboard.lean

Current Dashboard has the right idea but:
- Panel types are hardcoded in the draw function
- No formal panel interface (just if/else on type)
- Point metadata isn't structured
- Cross-panel hover doesn't exist yet

The refactor makes panels truly pluggable and points truly first-class.
