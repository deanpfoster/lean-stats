import DeanLean.Basic
import LeanStat.Descriptive
import LeanStat.Regression
import LeanStat.Tests
import LeanStat.Plot.Svg
import LeanStat.Report.Html

/-! # Manifest — headline claims about LeanStat

LeanStat is a pure Lean 4 library for statistics, plotting, and
HTML report generation. The headline claims below describe what
the library promises at the level a consumer cares about.

## What this library does

Provides pure functions over `Array Float` (and structured records
built from those) for:
  - Descriptive statistics (mean, variance, quantiles, summary)
  - Regression (Pearson correlation, linear regression)
  - Tests (one-sample and two-sample t-tests)
  - Charts (scatter, histogram → SVG)
  - Reports (HTML with tooltips)

## Headline claims

1. **All functions are pure**: no IO, no IORefs, no environment
   access. Wrapping LeanStat as a tool inside a capability-bounded
   agent is mechanical. (`pure_no_io`)

2. **Statistical functions are total**: every function returns a
   value for every input (degenerate cases — empty arrays, mismatched
   lengths, zero variance — return `0` or `none` as appropriate
   rather than panicking). (`functions_are_total`)

3. **Mathematical identities for the descriptive functions** hold
   to within floating-point tolerance:
     - mean is the centroid: `sum (xs.map (· - mean xs)) ≈ 0`
     - variance is non-negative: `variance xs ≥ 0`
     - quantiles are monotone in `q`
   (`descriptive_identities`)

4. **Linear regression returns the least-squares solution**: the
   slope minimizes `sum (yᵢ - (slope·xᵢ + intercept))²` over choices
   of `slope` and `intercept`. (`regression_least_squares`)

5. **Plot output is well-formed SVG**: every `LeanStat.Plot` function
   produces a string that any SVG parser will accept. (`svg_well_formed`)

## What we do NOT claim

  - **Numerical precision beyond Float**: all arithmetic is in IEEE
    754 binary64. We don't claim correct rounding, error bounds, or
    catastrophic-cancellation freedom.
  - **Statistical consultant-level appropriateness**: the library
    provides correct implementations of named statistics; choosing
    which test to use and interpreting results is the consumer's
    responsibility (or, in the l3m use case, the LLM's).
  - **A complete CDF table**: t-tests return statistics, not
    p-values. TODO: incorporate Student's t CDF.
  - **Sampling, simulation, MCMC**: not in scope for this library.
  - **Visualization beyond basic charts**: scatter and histogram
    only at this stage.
  - **HTML safety**: report HTML is concatenated from inputs without
    escaping. Consumers who pass adversarial strings as section
    prose will get unsanitized output. TODO: add escaping pass.
  - **Parser totality** for `Svg.render`: declared `partial def`
    pending a structural-recursion proof.

## Status

Most claims here are `UnprovenConjecture` placeholders. The
functions exist and are well-tested informally; the formal claims
haven't been written yet. This file establishes the dashboard;
the per-axis manifests and proof files will fill in over time.
-/

set_option autoImplicit false

namespace LeanStat.Manifest

/-- All LeanStat functions are pure (no IO type in their signatures).

    This is a structural property checked by audit-grep, not by a Lean
    theorem. The claim here is a placeholder; the real check is in
    Scripts/audit-grep.sh (TODO). -/
UnprovenConjecture pure_no_io :
  True

/-- Every public function in the library returns a value for every
    well-typed input. Declared as `UnprovenConjecture` because Lean's
    structural recursion checker certifies most of this for us; we
    enumerate the partial-def exceptions in Manifests/Termination.lean. -/
UnprovenConjecture functions_are_total :
  True

/-- Descriptive identities: mean is the centroid, variance is
    non-negative, etc. See Manifests/Descriptive.lean for the
    enumerated list. -/
UnprovenConjecture descriptive_identities :
  True

/-- Linear regression returns the OLS solution. See
    Manifests/Regression.lean. -/
UnprovenConjecture regression_least_squares :
  True

/-- SVG output is a valid string; consumer-side SVG parsers accept it.
    See Manifests/Plot.lean. -/
UnprovenConjecture svg_well_formed :
  True

end LeanStat.Manifest
