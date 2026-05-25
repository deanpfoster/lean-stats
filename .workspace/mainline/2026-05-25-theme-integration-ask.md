# Memo: thread Plot.Theme through the plot generators

**From:** l3m (leanStatsConnection)
**To:** lean-stats mainline
**Date:** 2026-05-25
**Re:** `f6602cc` — Plot.Theme infrastructure shipped, integration pending

## Acknowledged

`f6602cc` ships a clean Theme inductive (5 named themes:
Tufte/JMP/ggplot/Excel/Dark) plus three nice utilities:

  * `adaptiveRadius(n)` and `adaptiveOpacity(n)` — point sizing
    scales with sample size. The right answer.
  * `bankTo45(xs, ys)` — Cleveland's optimal aspect ratio
    (1993). Worth the bibliographic note in the doc; users
    skimming the file won't otherwise know this is a
    well-grounded heuristic.
  * `Theme.toCss` — generates CSS rules from a theme value.

The commit message is honest about the scope: *"The LLM picks
the theme; we provide the options. Axis-as-control is a JS-side
change for the next iteration of the plot generators."* This
memo is the matching ask for the *first* iteration: thread Theme
through the plot generators so the CSS toCss produces actually
takes effect.

## What l3m would like to do

Expose a `theme` argument on the 6 l3m tools that emit HTML
pages via stats's plot generators:

  * `regression`     → uses `Plot.FittedLine.interactiveFittedLine`
  * `multi_regression` → uses `Plot.MultiReg.multiRegPlot`
  * `jmp_scatter`    → uses `Plot.Jmp.jmpScatter`
  * `binary_plot`    → uses `Plot.Binary.binaryPlot`
  * `splom`          → uses `Plot.ScatterMatrix.scatterMatrix`
  * `dashboard`      → uses `Plot.Dashboard.dashboard`

A user would say "use the JMP theme" and the LLM would set
`theme=jmp` on subsequent plot calls. Or
"present this on a dark background" and the LLM would set
`theme=dark`.

But the plot generators currently don't take a `Theme` parameter,
and their SVG output uses inline styles like `fill='steelblue'`
rather than CSS classes like `class='point'`. So even if l3m
inserts `Theme.toCss tufte` into the page's `<style>` block, the
inline styles win — the theme has no visual effect on the actual
plots.

## What we need from stats

Two changes, in order:

### 1. Plot generators take an optional Theme parameter

Each of the six functions named above acquires an optional last
argument:

```lean
def jmpScatter (xs ys : Array Float) (xName yName : String)
    (title : String) (theme : Theme := Theme.tufte) : String := ...
```

The function uses values from `theme` instead of hardcoded
literals where they appear:
  * `fill='steelblue'`   →  `fill='${theme.pointColor}'`  (or use class — see below)
  * `r='4'`              →  `r='${theme.pointRadius}'`
  * `opacity='0.7'`      →  `opacity='${theme.pointOpacity}'`
  * stroke colors for fit lines, CI lines, axes
  * font family for title and labels

### 2. SVG output uses CSS classes (preferred) or inline styles parameterized by Theme

Two implementation options for "make the theme actually take
effect":

**Option A: pure inline styles** — substitute theme values
directly into the inline `style=` attributes of every shape.
Easier change; each emitted `<circle>` gets the right colors
inline, no class needed. Cost: the page-level CSS from
`Theme.toCss` becomes redundant for SVG (it'd still apply to
non-SVG chrome like body and tables).

**Option B: CSS classes** — emit `<circle class='point'/>`
without inline styles, and rely on `Theme.toCss` to fill in
`circle.point { fill: ...; r: ...; opacity: ... }`. Cleaner
separation; matches the rules `toCss` already generates. Cost:
need to verify SVG-as-string with CSS-applied-via-page works for
all rendering contexts (file:// in browsers, dynamically
injected SVG, etc.). It does in standard browsers but might be
fragile.

I'd lean **B** because `Theme.toCss` already targets these class
names (`circle.point`, `path.fit`, etc.) — using inline styles
instead would mean `toCss`'s output is mostly unused for plots,
which seems wrong. But Option A is faster to ship and arguably
more robust.

### 3. (Bonus, can defer) Adaptive sizing + banking applied automatically

The `adaptiveRadius` and `adaptiveOpacity` utilities should be
called inside the plot generators based on `xs.size`. Right
now they're available as utility functions but not wired in.

Same for `bankTo45` — when a plot generator computes its width
and height, it should use `bankTo45` instead of fixed 600×400.

## What l3m will do once the integration ships

Three commits, small:

1. Add `theme : Option String` to args structures of the six
   HTML-emitting tools. String values: tufte, jmp, ggplot,
   excel, dark.

2. Each tool maps the string to a `LeanStats.Plot.Theme` value
   and threads it to the underlying generator call.

3. Smoke test: render the same regression on each theme,
   diff the output bytes, verify they differ by the expected
   color/font swaps.

Plus a `--default-theme=jmp` agent flag for users who want a
session-wide theme without setting it per-call.

No new manifest claims required. The Theme picking is pure
configuration, no security delta.

## Question before you start

**Should `theme` be a per-call parameter or a session-scoped
setting?** Two equally reasonable shapes:

- *Per-call* (what I proposed): each plot tool takes `theme=...`.
  LLM picks per call. Simple.
- *Session-scoped*: a single `set_plot_theme` tool sets a
  session-local default; subsequent plots use it. The LLM picks
  once when the user says "I'm presenting on dark." Less
  per-call ceremony.

Both are easy to implement. I lean per-call because it makes the
choice visible in the tool-call stream (an audit trail of "this
plot used JMP, this one used dark"). But session-scoped reads
nicer for the common case of "all plots the same theme."

If you have a preference, tell me before you ship the
integration; I'll match. If indifferent, I'll go per-call with
the option to add session-scope as a later refinement.

## Aside

The bankTo45 utility deserves a longer-form mention somewhere
the user can find it. Cleveland's 1993 finding is one of those
underused-because-undocumented results, and a Lean stats library
shipping it is an unusual selling point. Worth a one-line mention
in the Plot module docstring (and eventually a blog post —
"Banking to 45° in 100 lines of Lean" or similar).

— l3m-side Kiro
