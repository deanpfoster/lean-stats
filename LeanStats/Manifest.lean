import DeanLean.Basic
import DeanLean.LibraryTame
import LeanStats.Manifests.Util
import LeanStats.Manifests.Descriptive
import LeanStats.Manifests.Regression
import LeanStats.Manifests.Tests
import LeanStats.Manifests.Transform
import LeanStats.Manifests.Diagnostics
import LeanStats.Manifests.Plot
import LeanStats.Manifests.Report
import LeanStats.Manifests.Interactive
import LeanStats.Manifests.Eval
import LeanStats.Manifests.PlotDescribe
-- Imports for the auditEntryPoint at end of file: pull in every
-- major surface so the LibraryTame audit walks the whole library.
import LeanStats.Plot.Jmp
import LeanStats.Plot.MultiReg
import LeanStats.Plot.Binary
import LeanStats.Plot.Histogram
import LeanStats.Plot.Terminal

/-! # Manifest — headline claims about LeanStats

This is the top-level trust surface for consumers of LeanStats.
An agent (e.g. l3m) importing this library can read these claims
to understand what it's getting.

## Headline claims (user-facing)

1. **Degenerate inputs are safe**: every function handles empty arrays,
   singletons, and mismatched lengths by returning documented defaults
   (0, none) rather than panicking.

2. **Descriptive statistics are correct**: mean, variance, quantile
   produce expected results on known fixtures (proven by native_decide).

3. **Regression is correct on known data**: OLS recovers exact slope
   and intercept on perfect linear data.

4. **T-tests respect sign conventions**: positive t when sample mean
   exceeds hypothesis, zero when equal.

5. **Plot output is valid SVG**: starts with `<svg xmlns=`, scale maps
   domain to range correctly.

6. **Reports are valid HTML**: starts with `<!DOCTYPE html>`, contains
   title, embeds CSS and JS.

## What we do NOT claim

  - Numerical precision beyond IEEE 754 binary64.
  - NaN/Inf robustness (undefined behavior on those inputs).
  - HTML/SVG escaping (known gap, documented in sub-manifests).
  - Statistical consulting (which test to use, interpretation).
  - CDF / p-value tables (t-tests return statistics only).
  - Termination of Svg.render (partial def, documented).
-/

set_option autoImplicit false

namespace LeanStats.Manifest
open LeanStats

-- ════════════════════════════════════════════════════════════
-- § Headline 1: Degenerate inputs are safe
-- ════════════════════════════════════════════════════════════

/-- All core functions return safe defaults on empty input. -/
theorem degenerate_safe_proof :
  mean #[] = 0 ∧
  variance #[] = 0 ∧
  stdDev #[] = 0 ∧
  median #[] = 0 ∧
  quantile #[] 0.5 = 0 ∧
  correlation #[] #[] = 0 ∧
  linearRegression #[] #[] = none ∧
  tTestOneSample #[] 0 = 0 ∧
  tTestTwoSample #[] #[] = 0 := by native_decide

ProvenTheorem degenerate_safe :
  mean #[] = 0 ∧
  variance #[] = 0 ∧
  stdDev #[] = 0 ∧
  median #[] = 0 ∧
  quantile #[] 0.5 = 0 ∧
  correlation #[] #[] = 0 ∧
  linearRegression #[] #[] = none ∧
  tTestOneSample #[] 0 = 0 ∧
  tTestTwoSample #[] #[] = 0

-- ════════════════════════════════════════════════════════════
-- § Headline 2: Descriptive statistics correctness
-- ════════════════════════════════════════════════════════════

Restate mean_empty from LeanStats.Manifests.Descriptive
Restate mean_singleton from LeanStats.Manifests.Descriptive
Restate variance_constant from LeanStats.Manifests.Descriptive
Restate quantile_zero from LeanStats.Manifests.Descriptive
Restate quantile_one from LeanStats.Manifests.Descriptive

-- ════════════════════════════════════════════════════════════
-- § Headline 3: Regression correctness
-- ════════════════════════════════════════════════════════════

Restate regression_slope from LeanStats.Manifests.Regression
Restate regression_intercept from LeanStats.Manifests.Regression
Restate regression_r2_perfect from LeanStats.Manifests.Regression

-- ════════════════════════════════════════════════════════════
-- § Headline 4: T-test sign conventions
-- ════════════════════════════════════════════════════════════

Restate ttest_one_positive from LeanStats.Manifests.Tests
Restate ttest_one_negative from LeanStats.Manifests.Tests
Restate ttest_one_null from LeanStats.Manifests.Tests

-- ════════════════════════════════════════════════════════════
-- § Headline 5: Plot output validity
-- ════════════════════════════════════════════════════════════

Restate svgdoc_prefix from LeanStats.Manifests.Plot
Restate scale_min from LeanStats.Manifests.Plot
Restate scale_max from LeanStats.Manifests.Plot

-- ════════════════════════════════════════════════════════════
-- § Headline 6: Report output validity
-- ════════════════════════════════════════════════════════════

Restate report_doctype from LeanStats.Manifests.Report
Restate report_contains_title from LeanStats.Manifests.Report
Restate report_has_style from LeanStats.Manifests.Report

-- ════════════════════════════════════════════════════════════
-- § Known gaps (permanent axioms — design decisions)
-- ════════════════════════════════════════════════════════════

/-- IEEE 754 binary64 is the only numeric representation.
    Falsifying observation: a function signature containing Real, Rat, or Int128. -/
UnprovenConjecture float_only :
  True  -- TODO: convert to LibraryTame audit or WorldClaim

/-- Library is pure: no IO in any function signature.
    Falsifying observation: grep for IO.FS, IO.Process, IO.getEnv in source. -/
UnprovenConjecture pure_no_io :
  True  -- TODO: convert to LibraryTame audit

end LeanStats.Manifest

-- ════════════════════════════════════════════════════════════
-- § Headline 7: Structural library tameness
-- ════════════════════════════════════════════════════════════

/-! Structural audit: walk every reachable constant from a root
    that touches all major LeanStats surfaces (descriptive,
    regression, tests, plot, report) and verify the library has:

      - no `initialize` blocks
      - no `unsafe def` declarations
      - no `@[extern]` declarations outside Lean's stdlib
      - no axioms outside Lean's kernel set + @[manifest_axiom]

    On success, emits theorem `auditEntryPoint_library_tame : True`
    as a kernel-checked artifact. The audit re-runs at every
    consumer build (when l3m or another consumer pins lean-stats
    to this commit, the consumer's build re-runs LibraryTame and
    re-derives the artifact). This means the audit is automatic
    and tied to the source bytes; if the bytes change, the audit
    re-runs.

    See `docs/design/incubated-extraction.md` in l3m for the
    four-phase library lifecycle this implements.
-/

/-- Audit entry point: a single function that touches every major
    LeanStats surface, used as the `LibraryTame` root so the
    audit's reachable set is comprehensive. The function itself
    is pure and unused at runtime — it exists only to anchor the
    structural check. -/
def auditEntryPoint : Bool :=
  let xs : Array Float := #[1.0, 2.0, 3.0]
  let ys : Array Float := #[2.0, 4.0, 6.0]
  let _summary := LeanStats.summary xs
  let _corr := LeanStats.correlation xs ys
  let _reg := LeanStats.linearRegression xs ys
  let _diag := LeanStats.regressionDiag xs ys
  let _tt := LeanStats.tTestOneSample xs 0.0
  let _jmpHtml := LeanStats.Plot.jmpScatter xs ys "x" "y" ""
  let _multiHtml := LeanStats.Plot.multiRegPlot #[("x", xs)] ys "y" ""
  let _binHtml := LeanStats.Plot.binaryPlot xs #[1.0, 0.0, 1.0] "x" "y" ""
  let _hist := LeanStats.Plot.histogram xs 10 {}
  let _terminal := LeanStats.Plot.Terminal.terminalScatter (xs.zip ys) 60 20
  true

LibraryTame LeanStats from auditEntryPoint
