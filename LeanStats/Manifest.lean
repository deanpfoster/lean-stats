import DeanLean.Basic
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
import LeanStats.Manifests.NewFunctions
import LeanTab.Manifests.Summarize

/-! # LeanStats + LeanTab — Manifest

A pure Lean 4 library for statistics, data manipulation, and
interactive visualization. 10,000+ lines. Zero IO.

## What this library promises

### 1. Purity (structurally verified)

Every public function is pure. No IO, no IORefs, no network,
no file system. Verified by `PureExcept` walking 3,049 reachable
constants from the public API — zero violations.

See: `LeanStats/Audit.lean`

### 2. Safety on degenerate inputs (proven)

Empty arrays, singletons, mismatched lengths — every function
returns a documented default (0, none, empty table) rather than
panicking. Proven on concrete fixtures via `native_decide`.

### 3. Correctness on known data (proven)

160+ ProvenTheorems on concrete fixtures: mean, variance,
regression slope/intercept/R², t-test sign conventions, quantile
bounds, ANOVA, chi-squared, VIF, OLS, dummy coding.

### 4. Conformance with R (validated)

VIF-Regression (Lin, Foster, Ungar 2011) validated against CRAN's
VIF package: R was run, output captured, Lean proven to match.
Framework in place for systematic CRAN conformance testing.

### 5. Bounded output (proven)

`tableSummary` output ≤ 1,201 characters regardless of input
table size. Proven at budgets 80/200/400/1200. Enables l3m to
classify summary tools as tame (bounded context consumption).

### 6. Interactive visualization (structural claims)

SVG output starts with valid namespace declaration. Data-id
attributes count matches observation count. Cross-panel selection
protocol typed via `LeanStats.Plot.Protocol` inductive.

## What this library does NOT promise

- Numerical precision beyond IEEE 754 binary64
- NaN/Inf robustness (undefined behavior)
- HTML/SVG escaping (known gap, documented)
- Statistical consulting (which test to use)
- CDF / p-value tables (t-tests return statistics only)
- Termination of Svg.render (partial def)
- GPU acceleration (interface ready, backend not yet wired)

## Inventory

### Statistics (LeanStats/)
- Descriptive: mean, variance, stdDev, median, quantile, iqr, summary
- Regression: correlation, linearRegression, regressionDiag, confint, predict
- Tests: one-sample t, two-sample t, paired t, ANOVA, chi-squared, proportions
- Transforms: log, sqrt, reciprocal, power, bestResponseTransform
- Diagnostics: residuals, leverage, Cook's D, Durbin-Watson, outlier detection
- Feature selection: alpha-investing, VIF-Regression (streaming, mFDR control)
- Linear algebra: matmul, solve, OLS, batchedOLS (GPU-ready interface)

### Tables (LeanTab/)
- Core: column-oriented Table with Cell (Float|String|NA)
- Verbs: filter, select, mutate, arrange, join, groupBy, pivot, window
- SQL: AST + evaluator + expression parser + filterByExpr
- Data quality: assessQuality, autoClean, schemaValidation
- Catalog: data source registry with provenance, sociology, encrypted secrets
- IO bridge: parseCsv, renderCsv, prettyPrint, tableSummary

### Visualization (LeanStats/Plot/)
- Interactive HTML: JMP scatter, binary/logistic, multiple regression,
  scatterplot matrix, dashboard, explorer (all self-contained, no deps)
- Terminal: braille scatter, block histogram, sparkline, dotplot, boxplot
- Text descriptions: moment-based summaries for LLM consumption
- Protocol: typed WebSocket messages for bidirectional LLM co-piloting

### Reproducibility (LeanStats/Report/)
- Provenance: Document/Block types, renderDocument (HTML with recipes)
- Literate: parseLiterate/renderLiterate (.lmd format)
- Conformance: R/numpy/SQL/spec-fixture testing framework
-/

set_option autoImplicit false

namespace LeanStats.Manifest
open LeanStats

-- ════════════════════════════════════════════════════════════
-- § Proven: degenerate inputs are safe
-- ════════════════════════════════════════════════════════════

/-- Every core function returns safe defaults on empty input. -/
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
-- § Proven: correctness on known data
-- ════════════════════════════════════════════════════════════

-- Descriptive
Restate mean_empty
Restate mean_singleton
Restate variance_constant
Restate quantile_zero
Restate quantile_one
Restate summary_n_general

-- Regression
Restate regression_slope
Restate regression_intercept
Restate regression_r2_perfect

-- T-tests
Restate ttest_one_positive
Restate ttest_one_negative
Restate ttest_one_null

-- ════════════════════════════════════════════════════════════
-- § Proven: output structure
-- ════════════════════════════════════════════════════════════

Restate svgdoc_prefix
Restate report_doctype
Restate summary_default_bound

-- ════════════════════════════════════════════════════════════
-- § Conformance: validated against R
-- ════════════════════════════════════════════════════════════

Restate vif_regression_conforms_r

-- ════════════════════════════════════════════════════════════
-- § Structural: purity
-- ════════════════════════════════════════════════════════════

/-- Library is pure: 3,049 constants reachable from public API, zero IO.
    Verified by PureExcept in LeanStats/Audit.lean. -/
Sketch pure_library

end LeanStats.Manifest
