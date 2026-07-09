import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanStats.Transform

/-! # Manifests/Transform — claims about variable transformations

## User-facing

  - Transforms handle edge cases (log of ≤ 0, sqrt of < 0, 1/0) → 0.
  - Identity transform returns input unchanged.
  - bestResponseTransform returns a valid TransformKind.

## Internal

  - log(e) = 1 (sanity check on Float.log).
  - sqrt(4) = 2.
  - reciprocal(2) = 0.5.
-/
-- Implementation: LeanStats/Transform.lean

set_option autoImplicit false

namespace LeanStats.Manifests.Transform
open LeanStats

-- ════════════════════════════════════════════════════════════
-- § User-facing claims
-- ════════════════════════════════════════════════════════════

/-- Log of non-positive values returns 0 (no crash). -/
theorem log_nonpositive_test :
  LeanStats.Manifests.floatArrayBitsEq (logTransform #[0.0, -1.0]) #[0.0, 0.0] = true := by native_decide

TestedConjecture log_nonpositive : logTransform #[0.0, -1.0] = #[0.0, 0.0]

/-- Sqrt of negative values returns 0. -/
theorem sqrt_negative_test :
  LeanStats.Manifests.floatArrayBitsEq (sqrtTransform #[-4.0]) #[0.0] = true := by native_decide

TestedConjecture sqrt_negative : sqrtTransform #[-4.0] = #[0.0]

/-- Reciprocal of zero returns 0. -/
theorem recip_zero_test :
  LeanStats.Manifests.floatArrayBitsEq (recipTransform #[0.0]) #[0.0] = true := by native_decide

TestedConjecture recip_zero : recipTransform #[0.0] = #[0.0]

/-- Identity transform returns input unchanged. -/
theorem identity_unchanged_test :
  LeanStats.Manifests.floatArrayBitsEq (applyTransform #[1.0, 2.0, 3.0] .identity) #[1.0, 2.0, 3.0] = true := by native_decide

TestedConjecture identity_unchanged : applyTransform #[1.0, 2.0, 3.0] .identity = #[1.0, 2.0, 3.0]

-- ════════════════════════════════════════════════════════════
-- § Internal claims
-- ════════════════════════════════════════════════════════════

/-- sqrt(4) = 2. -/
theorem sqrt_four_test :
  LeanStats.Manifests.floatArrayBitsEq (sqrtTransform #[4.0]) #[2.0] = true := by native_decide

TestedConjecture sqrt_four : sqrtTransform #[4.0] = #[2.0]

/-- reciprocal(2) = 0.5. -/
theorem recip_two_test :
  LeanStats.Manifests.floatArrayBitsEq (recipTransform #[2.0]) #[0.5] = true := by native_decide

TestedConjecture recip_two : recipTransform #[2.0] = #[0.5]

/-- square transform: 3² = 9. -/
theorem square_three_test :
  LeanStats.Manifests.floatArrayBitsEq (applyTransform #[3.0] .square) #[9.0] = true := by native_decide

TestedConjecture square_three : applyTransform #[3.0] .square = #[9.0]

end LeanStats.Manifests.Transform
