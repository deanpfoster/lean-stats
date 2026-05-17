import DeanLean.Basic
import LeanStat.Descriptive

/-! # Manifests/Descriptive — claims about descriptive statistics

Per-function structural and mathematical claims. Most are
`UnprovenConjecture` for now; we'll promote as proofs land.

## What we claim

  - `mean_centroid`: `xs.map (· - mean xs)` sums to (approximately) 0
  - `variance_nonneg`: `variance xs ≥ 0`
  - `stddev_nonneg`: `stdDev xs ≥ 0`
  - `summary_n_correct`: `(summary xs).n = xs.size`
  - `quantile_bounds`: `quantile xs 0 = min xs ∧ quantile xs 1 = max xs`
    (when `xs` is non-empty)
  - `median_consistent`: `median xs = quantile xs 0.5`
  - Empty-input behavior: every function returns the documented
    default (0 or 0.0) rather than panicking.

## What we do NOT claim

  - Numerical precision under accumulation (mean of a large array is
    accurate to within ε); the library uses naive summation, which has
    O(N·ε) error in IEEE 754.
  - Robustness to NaN / Inf inputs: TODO. Currently undefined behavior.
-/

set_option autoImplicit false

namespace LeanStat.Manifests.Descriptive
open LeanStat

/-- Empty array: mean is 0. -/
UnprovenConjecture mean_empty :
  mean #[] = 0

/-- Single-element array: mean is the element. -/
UnprovenConjecture mean_singleton :
  ∀ (x : Float), mean #[x] = x

/-- Variance is non-negative. -/
UnprovenConjecture variance_nonneg :
  ∀ (xs : Array Float), variance xs ≥ 0

/-- Standard deviation is non-negative. -/
UnprovenConjecture stddev_nonneg :
  ∀ (xs : Array Float), stdDev xs ≥ 0

/-- `summary` records the size of the input. -/
UnprovenConjecture summary_n_correct :
  ∀ (xs : Array Float), (summary xs).n = xs.size

/-- Median of a single-element array is that element. -/
UnprovenConjecture median_singleton :
  ∀ (x : Float), median #[x] = x

end LeanStat.Manifests.Descriptive
