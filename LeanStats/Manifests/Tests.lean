import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanStats.Tests

/-! # Manifests/Tests — claims about t-test implementations

## User-facing (what an agent calling `tTestOneSample`/`tTestTwoSample` can trust)

  - Degenerate inputs (< 2 elements) return 0 (no crash).
  - When the sample mean equals the hypothesized mean, t = 0.
  - When two identical samples are compared, t = 0.

## Internal (implementation correctness)

  - Sign of t-statistic: if sample mean > μ₀, t > 0.
  - Zero-variance guard: returns 0 rather than dividing by zero.
  - Known data fixtures produce expected t-statistics.

## What we do NOT claim

  - p-values (no CDF table yet).
  - Degrees of freedom for Welch's approximation.
  - Power analysis or sample-size recommendations.
-/
-- Implementation: LeanStats/Tests.lean

set_option autoImplicit false

namespace LeanStats.Manifests.Tests
open LeanStats

-- ════════════════════════════════════════════════════════════
-- § User-facing claims
-- ════════════════════════════════════════════════════════════

/-- One-sample t-test on empty array returns 0. -/
theorem ttest_one_empty_test : LeanStats.Manifests.floatBitsEq (tTestOneSample #[] 0) 0 = true := by native_decide

TestedConjecture ttest_one_empty : tTestOneSample #[] 0 = 0

/-- One-sample t-test on singleton returns 0 (need ≥ 2). -/
theorem ttest_one_singleton_test : LeanStats.Manifests.floatBitsEq (tTestOneSample #[5.0] 3.0) 0 = true := by native_decide

TestedConjecture ttest_one_singleton : tTestOneSample #[5.0] 3.0 = 0

/-- Two-sample t-test with empty first group returns 0. -/
theorem ttest_two_empty_test : LeanStats.Manifests.floatBitsEq (tTestTwoSample #[] #[1.0, 2.0, 3.0]) 0 = true := by native_decide

TestedConjecture ttest_two_empty : tTestTwoSample #[] #[1.0, 2.0, 3.0] = 0

/-- Two-sample t-test with singleton groups returns 0. -/
theorem ttest_two_singleton_test : LeanStats.Manifests.floatBitsEq (tTestTwoSample #[1.0] #[2.0]) 0 = true := by native_decide

TestedConjecture ttest_two_singleton : tTestTwoSample #[1.0] #[2.0] = 0

/-- When sample mean equals hypothesized mean, t = 0. -/
theorem ttest_one_null_test : LeanStats.Manifests.floatBitsEq (tTestOneSample #[2.0, 4.0] 3.0) 0 = true := by native_decide

TestedConjecture ttest_one_null : tTestOneSample #[2.0, 4.0] 3.0 = 0

/-- Two identical samples yield t = 0. -/
theorem ttest_two_identical_test :
  LeanStats.Manifests.floatBitsEq (tTestTwoSample #[1.0, 2.0, 3.0] #[1.0, 2.0, 3.0]) 0 = true := by native_decide

TestedConjecture ttest_two_identical :
  tTestTwoSample #[1.0, 2.0, 3.0] #[1.0, 2.0, 3.0] = 0

/-- Zero-variance sample: t-test returns 0 (se = 0 guard). -/
theorem ttest_one_zero_var_test : LeanStats.Manifests.floatBitsEq (tTestOneSample #[5.0, 5.0, 5.0] 3.0) 0 = true := by native_decide

TestedConjecture ttest_one_zero_var : tTestOneSample #[5.0, 5.0, 5.0] 3.0 = 0

-- ════════════════════════════════════════════════════════════
-- § Internal claims
-- ════════════════════════════════════════════════════════════

/-- When sample mean > μ₀ and variance > 0, t > 0.
    mean([1,2,3,4,5]) = 3 > μ₀ = 0. -/
theorem ttest_one_positive_proof :
  tTestOneSample #[1.0, 2.0, 3.0, 4.0, 5.0] 0 > 0 := by native_decide

ProvenTheorem ttest_one_positive :
  tTestOneSample #[1.0, 2.0, 3.0, 4.0, 5.0] 0 > 0

/-- When sample mean < μ₀, t < 0.
    mean([1,2,3]) = 2 < μ₀ = 10. -/
theorem ttest_one_negative_proof :
  tTestOneSample #[1.0, 2.0, 3.0] 10.0 < 0 := by native_decide

ProvenTheorem ttest_one_negative :
  tTestOneSample #[1.0, 2.0, 3.0] 10.0 < 0

-- ════════════════════════════════════════════════════════════
-- § Universally quantified claims
-- ════════════════════════════════════════════════════════════

/-- Welch's t-test is antisymmetric: swapping groups negates the statistic. -/
UnprovenConjecture ttest_two_antisymmetric :
  ∀ (xs ys : Array Float),
    tTestTwoSample xs ys = -(tTestTwoSample ys xs)

end LeanStats.Manifests.Tests
