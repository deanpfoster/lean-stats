import DeanLean.Basic
import LeanStats.Manifests.Util

/-! # Manifests/Regression — claims about correlation and linear regression

## User-facing (what an agent calling `correlation`/`linearRegression` can trust)

  - Degenerate inputs (empty, singleton, mismatched lengths) return
    safe defaults (0 for correlation, none for regression).
  - Zero-variance x-data returns none (slope undefined).
  - Perfect linear data yields R² = 1.

## Internal (implementation correctness)

  - Correlation of identical arrays is 1.
  - Regression on y = 2x + 1 recovers slope=2, intercept=1.
  - Regression records correct sample size.

## What we do NOT claim

  - Correlation bounded in [-1, 1] for all Float inputs (NaN/Inf break this).
  - Numerical stability for near-collinear data.
  - Multivariate regression (not implemented).
-/

set_option autoImplicit false

namespace LeanStats.Manifests.Regression
open LeanStats

-- Helper extractors for Option LinearFit fields (avoids match Decidable issues)
private def getSlope (xs ys : Array Float) : Option Float :=
  (linearRegression xs ys).map (·.slope)

private def getIntercept (xs ys : Array Float) : Option Float :=
  (linearRegression xs ys).map (·.intercept)

private def getR2 (xs ys : Array Float) : Option Float :=
  (linearRegression xs ys).map (·.r2)

private def getN (xs ys : Array Float) : Option Nat :=
  (linearRegression xs ys).map (·.n)

-- ════════════════════════════════════════════════════════════
-- § User-facing claims
-- ════════════════════════════════════════════════════════════

/-- Correlation of empty arrays is 0. -/
theorem correlation_empty_proof : correlation #[] #[] = 0 := by native_decide

ProvenTheorem correlation_empty : correlation #[] #[] = 0

/-- Correlation of singleton arrays is 0 (need ≥ 2 points). -/
theorem correlation_singleton_proof : correlation #[1.0] #[2.0] = 0 := by native_decide

ProvenTheorem correlation_singleton : correlation #[1.0] #[2.0] = 0

/-- Mismatched-length arrays: correlation is 0. -/
theorem correlation_mismatched_proof : correlation #[1.0, 2.0] #[1.0] = 0 := by native_decide

ProvenTheorem correlation_mismatched : correlation #[1.0, 2.0] #[1.0] = 0

/-- Regression on empty arrays returns none. -/
theorem regression_empty_proof : linearRegression #[] #[] = none := by native_decide

ProvenTheorem regression_empty : linearRegression #[] #[] = none

/-- Regression on mismatched lengths returns none. -/
theorem regression_mismatched_proof : linearRegression #[1.0] #[1.0, 2.0] = none := by native_decide

ProvenTheorem regression_mismatched : linearRegression #[1.0] #[1.0, 2.0] = none

/-- Regression on zero-variance x returns none (slope undefined). -/
theorem regression_zero_var_proof : linearRegression #[1.0, 1.0, 1.0] #[1.0, 2.0, 3.0] = none := by native_decide

ProvenTheorem regression_zero_var : linearRegression #[1.0, 1.0, 1.0] #[1.0, 2.0, 3.0] = none

/-- Regression on a single point returns none (need ≥ 2). -/
theorem regression_singleton_proof : linearRegression #[1.0] #[2.0] = none := by native_decide

ProvenTheorem regression_singleton : linearRegression #[1.0] #[2.0] = none

-- ════════════════════════════════════════════════════════════
-- § Internal claims
-- ════════════════════════════════════════════════════════════

/-- Correlation of perfectly linear data (y = x) is 1. -/
theorem correlation_perfect_proof :
  correlation #[1.0, 2.0, 3.0] #[1.0, 2.0, 3.0] = 1.0 := by native_decide

ProvenTheorem correlation_perfect :
  correlation #[1.0, 2.0, 3.0] #[1.0, 2.0, 3.0] = 1.0

/-- Regression on y = 2x + 1 returns some (not degenerate). -/
theorem regression_isSome_proof :
  (linearRegression #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0]).isSome = true := by native_decide

ProvenTheorem regression_isSome :
  (linearRegression #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0]).isSome = true

/-- Regression on y = 2x + 1 recovers slope = 2. -/
theorem regression_slope_proof :
  getSlope #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 2.0 := by native_decide

ProvenTheorem regression_slope :
  getSlope #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 2.0

/-- Regression on y = 2x + 1 recovers intercept = 1. -/
theorem regression_intercept_proof :
  getIntercept #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 1.0 := by native_decide

ProvenTheorem regression_intercept :
  getIntercept #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 1.0

/-- Perfect linear data yields R² = 1. -/
theorem regression_r2_perfect_proof :
  getR2 #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 1.0 := by native_decide

ProvenTheorem regression_r2_perfect :
  getR2 #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 1.0

/-- Regression records the correct sample size. -/
theorem regression_n_proof :
  getN #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 3 := by native_decide

ProvenTheorem regression_n :
  getN #[1.0, 2.0, 3.0] #[3.0, 5.0, 7.0] = some 3

-- ════════════════════════════════════════════════════════════
-- § Universally quantified claims
-- ════════════════════════════════════════════════════════════

/-- Correlation is bounded in [-1, 1] for well-behaved inputs.
    Cannot prove over arbitrary Float; would need NaN/Inf exclusion. -/
UnprovenConjecture correlation_bounded :
  ∀ (xs ys : Array Float),
    xs.size = ys.size → xs.size ≥ 2 →
    correlation xs ys ≥ -1 ∧ correlation xs ys ≤ 1

/-- OLS intercept satisfies: intercept = mean(ys) - slope * mean(xs). -/
UnprovenConjecture regression_intercept_identity :
  ∀ (xs ys : Array Float) (fit : LinearFit),
    linearRegression xs ys = some fit →
    fit.intercept = mean ys - fit.slope * mean xs

end LeanStats.Manifests.Regression
