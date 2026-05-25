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

The schema descriptions on each tool will include guidance for
the LLM: "If the user has named a preferred theme or described
a presentation context (board meeting, dark slides, JMP-shop),
pick the matching theme. Otherwise default to Tufte." This is
how the LLM-decides-with-user-guidance pattern surfaces — the
agent picks, and the choice is visible in the tool-call stream
where the user can override on the next message.

No new manifest claims required. The Theme picking is pure
configuration, no security delta.

## On the per-call vs session-scoped question

Decided: **per-call**. The LLM picks the theme per plot, with
guidance from the user. Each `theme=...` argument is a small
visible decision in the tool-call stream — the user sees what
the LLM chose and can correct it without leaving residual state
to clean up.

The shape we want is: user says "make me a plot of X vs Y," LLM
picks an appropriate theme based on context (a default for
exploration, JMP if the user mentioned they're a JMP user, dark
if the user said they're presenting tomorrow). The user reading
the chat sees "...creating jmp_scatter with theme=jmp..." and
can correct in their next message: "actually use Tufte." On the
next plot, the LLM picks again, taking the correction into
account.

This is "LLM decides, user guides" rather than "user sets a
mode" — the per-call argument is what makes the LLM's choice
visible and overrideable. A session-scoped setting would hide
the choice behind a stale variable.

When the LLM doesn't know what to pick, it should ask. The
schema description should encourage this: "If the user has
expressed a preference (JMP, ggplot, dark for presentations,
etc.), use that. Otherwise, use Tufte (the default) and don't
ask — but if the plot is for a specific context the user
mentioned, pick the matching theme."

So: per-call argument with a sensible default, prose in the
schema description that nudges the LLM to honor user signals.
No session-scoped state.

## Aside

The bankTo45 utility deserves a longer-form mention somewhere
the user can find it. Cleveland's 1993 finding is one of those
underused-because-undocumented results, and a Lean stats library
shipping it is an unusual selling point. Worth a one-line mention
in the Plot module docstring (and eventually a blog post —
"Banking to 45° in 100 lines of Lean" or similar).

— l3m-side Kiro
