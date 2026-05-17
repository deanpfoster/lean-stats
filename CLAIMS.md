# Claims

Human-readable index of every formal claim in lean-stat. Source of
truth is `LeanStat/Manifests/<topic>.lean`; this is the dashboard.

## Status snapshot

  Library status: **Initial extraction** (2026-05-17). Functions
  ported from l3m's `L3m/{Plot,Stats,Report}` directories; manifest
  skeleton in place; **most claims are UnprovenConjecture
  placeholders** — the formal claims haven't been written yet.

  Lines of Lean: ~440 (across 11 source files + 5 manifest files)
  ProvenTheorem count: **0**
  TestedConjecture count: **0**
  FailingConjecture count: **0**
  UnprovenConjecture count: **~15** (placeholders)

  Next work: write actual formal claims (mostly `decide` /
  `native_decide` on small fixtures) and promote.

## Headline (`LeanStat/Manifest.lean`)

| Claim | Evidence | Statement |
|-------|----------|-----------|
| `pure_no_io` | ○ | All functions are pure (no IO type in signatures). Check via audit-grep. |
| `functions_are_total` | ○ | Every public function returns a value for every well-typed input. |
| `descriptive_identities` | ○ | Mean is centroid; variance non-negative; etc. See `Manifests/Descriptive`. |
| `regression_least_squares` | ○ | OLS returns the slope minimizing sum of squared residuals. |
| `svg_well_formed` | ○ | Plot output is a valid SVG string. |

## Per-axis manifests

  - `LeanStat.Manifests.Descriptive` — mean/variance/median identities
  - `LeanStat.Manifests.Regression` — degenerate-input behavior; OLS
    optimality (TODO)
  - `LeanStat.Manifests.Plot` — SVG well-formedness; scale monotonicity;
    KNOWN GAP: attribute-value escaping
  - `LeanStat.Manifests.Report` — HTML document structure; KNOWN GAP:
    HTML escaping

## What we do NOT claim

  - **Numerical precision beyond Float**: IEEE 754 binary64 only.
  - **Statistical-consultant judgment**: we provide implementations,
    not advice on which test to use.
  - **CDF / p-value tables**: t-tests return statistics; consumers
    look up p-values.
  - **HTML/SVG escaping**: known gap; consumers sanitize.
  - **Sampling, Bayesian, GLM, time-series, ML**: not in scope.

## Lifecycle

  1. Initial extraction (this).
  2. Write actual claims (replace `True`-shaped placeholders with
     real propositions, `decide` / `native_decide` proofs where
     possible).
  3. Add testable claims via `registerTestResults` for empirical
     properties (correlation bounds, OLS residual orthogonality on
     a corpus of synthetic data).
  4. Add the missing escaping pass + claim about no script-tag
     survival.
  5. Wire as l3m tools (in l3m's repo, not here).
