# Design Decisions — why things are the way they are

This document captures design decisions that aren't obvious from
the code alone. If you're wondering "why did they do it this way?"
— look here.

## Architecture: pure library + IO agent

lean-stats does NO IO. Zero. Verified by PureExcept (3,049
constants, zero violations). All IO lives in l3m:
- File reading → l3m reads, passes String to our `parseCsv`
- Database connections → l3m connects, passes rows to our Table
- File writing → l3m calls our `renderCsv`/`renderDocument`, writes the String
- WebSocket → l3m runs the server, our pages connect to it

Why: clean trust separation. Our manifest is about mathematical
correctness. l3m's manifest is about safety. Mixing them makes
both noisier.

## Two-eyed tools

Every operation should produce output for both partners:
- **Human**: visual (plots, pretty-printed tables, sparklines)
- **LLM**: symbolic (tableSummary, describeScatter, moment ladder)

Neither partner should be blind to what the other sees. The
WebSocket protocol ensures both get the same events. The
`TwoEyedResult` struct bundles both views of every table operation.

Source: blog post "Two-eyed tools: pair programming when one of
you can't see" (~/blog/two-eyed-tools.md).

## Interactive plots: XLispStat linking protocol (1990)

All interactive plots share a `pointState` array. Selection in
one panel highlights in all panels. This is Luke Tierney's 1990
architecture translated to WebSocket + SVG:
- SharedState (points + selection + exclusion)
- Panels as observers (render when state changes)
- Atomic messages (select, exclude, checkpoint)
- Identity baked in (data-id attributes)

Source: COMPOSABLE.md

## Axis-as-control (Tufte-inspired)

The axis label IS the dropdown. Click "wt" → popup with transform
options. No separate widget cluttering the page. The label does
double duty: it shows the current state AND it's the control to
change it. Higher data-ink ratio.

## Centered interactions: (x₁ - x̄₁)(x₂ - x̄₂)

NOT x₁·x₂. Centering before multiplying removes collinearity
between the interaction and the main effects. Result: adding or
removing the interaction term doesn't cause other coefficients to
bounce around. The AV plots are more stable.

## Checkpoint stores fitted values, not coefficients

When you checkpoint in the multiple regression page:
- Y coordinate = slope × eX (the model's prediction for each point)
- X coordinate = current eX (recomputed on every draw)

Why: coefficients only make sense in one coordinate system. Fitted
values are concrete predictions that can be plotted in any system.
When you change a transform, the checkpointed points slide
horizontally (collinearity changes) but stay at the same height
(the prediction was what it was).

## Degree on AV plots = model polynomial, not visual smoothing

When you set degree=2 on predictor X₁, the MODEL adds X₁² to the
design matrix. The AV plot shows the combined contribution of X₁
and X₁². By the properties of added variable plots, fitting a
local polynomial to the AV residuals recovers the same coefficients
as the full model. So the visual IS the model.

Interactions are limited to degree 0/1 (in or out). Higher-degree
interactions would be response surface methodology — a different tool.

## The catalog is sociology

Finding data at a large company is a problem in sociology, not SQL.
The catalog tracks:
- WHO owns the table (not just where it lives)
- WHO to contact when it breaks (oncall rotation, CTI path)
- HOW we learned about it (Slack, email, conversation, inferred)
- WHETHER it's been validated (unverified → drifted → validated)

Secrets never travel during merge. If Bob's catalog has a password
we don't have, the merged entry says "Bob knows the password" —
not the password itself.

## The conformance hierarchy

| Level | Meaning | Promotable? |
|-------|---------|-------------|
| ProvenTheorem | True for ALL inputs, kernel-verified | — (already at top) |
| TestedConjecture | Believed universal, tested on fixtures | → ProvenTheorem |
| ConformanceFixture | Matches reference system on ONE input | Never (standalone) |
| Sketch | Named slot, no Prop yet | → UnprovenConjecture |

ConformanceFixture is NOT a theorem. It's a regression test against
a gold standard (R, numpy, PostgreSQL). It doesn't aspire to
universality. Nothing should depend on it for trust.

## Themes: Tufte default, switchable

5 themes (Tufte/JMP/ggplot/Excel/Dark) control all visual decisions:
colors, weights, fonts, borders, grid, legend placement, point style.
SVG elements use CSS classes; Theme.toCss generates the rules.
Switching themes changes the entire visual appearance.

Default is Tufte: minimal, high data-ink ratio, no chartjunk.

## Budget-aware summaries

`tableSummary` takes a character budget. At 1200 chars: full detail
(8 cols, ranges, means, top values). At 80 chars: one-liner. The
output is PROVEN to fit within the budget (ProvenTheorem on fixtures).
This lets l3m classify summary tools as "tame" (bounded output).

## Alpha-investing for feature selection

NOT classical stepwise (p-value thresholds). Alpha-investing
(Foster & Stine 2008) manages a "wealth" budget:
- Each test costs alpha
- Rejections earn alpha back
- Stop when wealth exhausted

Controls mFDR (marginal false discovery rate). The wealth process
is a supermartingale under the null — this is the e-value / betting
framework avant la lettre.

VIF-Regression (Lin, Foster, Ungar 2011) extends this with
VIF-based test statistics and subsample approximation for speed.

## The CRAN import workflow

1. Read R source (LLM reads from CRAN/GitHub)
2. Translate to Lean (LLM writes pure implementation)
3. Validate against R (run R, capture output, prove Lean matches)
4. Register (add to audit, interface, manifests)

The golden fixture is checked in and compiles without R. The R
script is checked in for reproducibility. The ConformanceFixture
proves the match. See: CRAN_WORKFLOW.md
