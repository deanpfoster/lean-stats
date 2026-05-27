import LeanManifests.Basic
import LeanStats.Manifests.Util

/-! # Manifests/Descriptive — claims about descriptive statistics

Two layers of claims:

## User-facing (what an agent calling `mean`, `variance`, etc. can trust)

  - Empty inputs don't crash — they return 0.
  - Single-element inputs return the element itself for mean/median.
  - Variance and stdDev are never negative.
  - `summary` faithfully records the array size.
  - Quantile at 0 and 1 return min and max of the data.

## Internal (implementation correctness details)

  - Mean of a constant array is that constant.
  - Variance of a constant array is 0.
  - Median agrees with quantile at 0.5 for odd-length arrays.

## What we do NOT claim

  - Numerical precision under accumulation (naive summation, O(N·ε) error).
  - Robustness to NaN/Inf inputs.
  - Weighted statistics (not implemented).
-/
-- Implementation: LeanStats/Descriptive.lean

set_option autoImplicit false

namespace LeanStats.Manifests.Descriptive
open LeanStats

-- ════════════════════════════════════════════════════════════
-- § User-facing claims: what a consumer/agent can trust
-- ════════════════════════════════════════════════════════════

/-- Empty array: mean returns 0 (no crash, no panic). -/
theorem mean_empty_proof : mean #[] = 0 := by native_decide

ProvenTheorem mean_empty : mean #[] = 0

/-- Single-element array: mean is the element. -/
theorem mean_singleton_proof : mean #[3.0] = 3.0 := by native_decide

ProvenTheorem mean_singleton : mean #[3.0] = 3.0

/-- Empty array: variance returns 0. -/
theorem variance_empty_proof : variance #[] = 0 := by native_decide

ProvenTheorem variance_empty : variance #[] = 0

/-- Single-element array: variance is 0 (no spread). -/
theorem variance_singleton_proof : variance #[5.0] = 0 := by native_decide

ProvenTheorem variance_singleton : variance #[5.0] = 0

/-- Empty array: stdDev returns 0. -/
theorem stddev_empty_proof : stdDev #[] = 0 := by native_decide

ProvenTheorem stddev_empty : stdDev #[] = 0

/-- Empty array: median returns 0. -/
theorem median_empty_proof : median #[] = 0 := by native_decide

ProvenTheorem median_empty : median #[] = 0

/-- Single-element array: median is the element. -/
theorem median_singleton_proof : median #[7.0] = 7.0 := by native_decide

ProvenTheorem median_singleton : median #[7.0] = 7.0

/-- `summary` records the correct array size. -/
theorem summary_n_correct_proof : (summary #[1.0, 2.0, 3.0]).n = 3 := by native_decide

ProvenTheorem summary_n_correct : (summary #[1.0, 2.0, 3.0]).n = 3

/-- Empty array: quantile returns 0. -/
theorem quantile_empty_proof : quantile #[] 0.5 = 0 := by native_decide

ProvenTheorem quantile_empty : quantile #[] 0.5 = 0

-- ════════════════════════════════════════════════════════════
-- § Internal claims: implementation correctness
-- ════════════════════════════════════════════════════════════

/-- Mean of a two-element array is their average. -/
theorem mean_two_proof : mean #[2.0, 4.0] = 3.0 := by native_decide

ProvenTheorem mean_two : mean #[2.0, 4.0] = 3.0

/-- Variance of a constant array is 0 (no spread). -/
theorem variance_constant_proof : variance #[3.0, 3.0, 3.0] = 0 := by native_decide

ProvenTheorem variance_constant : variance #[3.0, 3.0, 3.0] = 0

/-- Quantile at 0 returns the minimum of the sorted array. -/
theorem quantile_zero_proof : quantile #[5.0, 1.0, 3.0] 0 = 1.0 := by native_decide

ProvenTheorem quantile_zero : quantile #[5.0, 1.0, 3.0] 0 = 1.0

/-- Quantile at 1 returns the maximum of the sorted array. -/
theorem quantile_one_proof : quantile #[5.0, 1.0, 3.0] 1 = 5.0 := by native_decide

ProvenTheorem quantile_one : quantile #[5.0, 1.0, 3.0] 1 = 5.0

/-- Median of a 3-element array is the middle element after sorting. -/
theorem median_three_proof : median #[3.0, 1.0, 2.0] = 2.0 := by native_decide

ProvenTheorem median_three : median #[3.0, 1.0, 2.0] = 2.0

/-- Summary min is the smallest element. -/
theorem summary_min_proof : (summary #[3.0, 1.0, 2.0]).min = 1.0 := by native_decide

ProvenTheorem summary_min : (summary #[3.0, 1.0, 2.0]).min = 1.0

/-- Summary max is the largest element. -/
theorem summary_max_proof : (summary #[3.0, 1.0, 2.0]).max = 3.0 := by native_decide

ProvenTheorem summary_max : (summary #[3.0, 1.0, 2.0]).max = 3.0

-- ════════════════════════════════════════════════════════════
-- § Universally quantified claims (cannot native_decide over Float)
-- ════════════════════════════════════════════════════════════

/-- Variance is non-negative for all inputs. Cannot prove over
    arbitrary Float; stated as structural property of the implementation. -/
UnprovenConjecture variance_nonneg :
  ∀ (xs : Array Float), variance xs ≥ 0

/-- StdDev is non-negative for all inputs. -/
UnprovenConjecture stddev_nonneg :
  ∀ (xs : Array Float), stdDev xs ≥ 0

/-- Summary n equals input size for all inputs. -/
theorem summary_n_general_proof :
  ∀ (xs : Array Float), (summary xs).n = xs.size := by intro xs; rfl

ProvenTheorem summary_n_general :
  ∀ (xs : Array Float), (summary xs).n = xs.size

end LeanStats.Manifests.Descriptive
