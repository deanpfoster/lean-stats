# lean-stat

Pure Lean 4 statistics, plotting, and HTML reporting. Designed to
be wrapped by capability-bounded agents (e.g.
[l3m](https://github.com/...)) that handle data ingestion and
output, while this library handles correctness.

## Status

**Initial extraction (2026-05-17).** Functions ported from l3m's
experimental `Plot/Stats/Report` directories. Manifest skeleton in
place; most formal claims are `UnprovenConjecture` placeholders
that need real propositions. See `CLAIMS.md` for the dashboard.

## Layout

```
LeanStat/
  Descriptive.lean      — mean, variance, quantiles, summary
  Regression.lean       — Pearson correlation, OLS linear regression
  Tests.lean            — one-sample and Welch two-sample t-tests
  Plot/
    Svg.lean            — pure SVG model + renderer
    Scale.lean          — domain → range affine scaling
    Axes.lean           — axis drawing with ticks
    Scatter.lean        — scatter plot
    Histogram.lean      — histogram
  Report/
    Tooltip.lean        — interactive tooltip CSS/JS
    Html.lean           — HTML report generation
  Manifest.lean         — headline claims
  Manifests/
    Descriptive.lean    — per-function descriptive claims
    Regression.lean     — regression claims
    Plot.lean           — plot well-formedness + known gaps
    Report.lean         — report structure + known gaps
```

## Building

```bash
~/.elan/bin/lake build
```

Requires `lean-toolchain` `leanprover/lean4:v4.16.0`. Path-dep on
`../lean-manifests` (which provides `dean_lean` / `DeanLean`).

## Usage

```lean
import LeanStat

open LeanStat
open LeanStat.Plot

def example : IO Unit := do
  let xs := #[1.0, 2.0, 3.0, 4.0, 5.0]
  let ys := #[2.1, 4.0, 5.9, 8.1, 10.0]
  IO.println s!"mean(xs) = {mean xs}"
  IO.println s!"correlation = {correlation xs ys}"
  match linearRegression xs ys with
  | some fit => IO.println s!"slope = {fit.slope}, R² = {fit.r2}"
  | none => IO.println "(degenerate input)"
  let chart := scatterPlot (xs.zip ys)
  IO.println (svgDoc 600 400 chart)
```

## Design

**Pure all the way down.** No IO, no IORefs, no `partial def`
except `Svg.render` (which is documented and the totality is
backed by manifest claims). This makes `lean-stat` cleanly
wrappable as tool functions inside an agent: the agent provides
capability tokens for file IO, network, etc., and `lean-stat`
provides correctness for the math.

**Manifest-driven.** Every function eventually has a manifest
claim describing what it promises. See `CLAIMS.md` for the
dashboard. Most claims today are placeholders awaiting real
formal statements; the discipline is: never ship a function
without a manifest entry.

## Known gaps

  - Most manifest claims are `UnprovenConjecture` placeholders.
  - No HTML escaping in `Report.Html` (consumers sanitize).
  - No SVG attribute-value escaping in `Plot.Svg` (same).
  - No CDF / p-value tables for `Tests` (returns t-statistic only).
  - No sampling / simulation / Bayesian / GLM / time-series.
  - Numerical precision is whatever Float (IEEE 754 binary64) gives;
    no claim about catastrophic cancellation freedom.

## Roadmap

Near term:
  - Replace placeholder claims with real propositions
  - Add `decide` / `native_decide` proofs where applicable
  - HTML/SVG escaping pass + claim about no script survival

Medium term:
  - Student's t CDF / p-value table
  - Robust statistics (MAD, trimmed means)
  - Weighted statistics

Long term:
  - Multivariate regression, GLMs
  - Bayesian primitives (priors, likelihoods, MAP)
  - More chart types (line, box, violin, heatmap)

## License

TBD. The original code was extracted from l3m; this library inherits
the same license once l3m's is finalized.
