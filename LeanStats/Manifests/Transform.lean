import DeanLean.Basic
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
theorem log_nonpositive_proof : logTransform #[0.0, -1.0] = #[0.0, 0.0] := by native_decide

ProvenTheorem log_nonpositive : logTransform #[0.0, -1.0] = #[0.0, 0.0]

/-- Sqrt of negative values returns 0. -/
theorem sqrt_negative_proof : sqrtTransform #[-4.0] = #[0.0] := by native_decide

ProvenTheorem sqrt_negative : sqrtTransform #[-4.0] = #[0.0]

/-- Reciprocal of zero returns 0. -/
theorem recip_zero_proof : recipTransform #[0.0] = #[0.0] := by native_decide

ProvenTheorem recip_zero : recipTransform #[0.0] = #[0.0]

/-- Identity transform returns input unchanged. -/
theorem identity_unchanged_proof : applyTransform #[1.0, 2.0, 3.0] .identity = #[1.0, 2.0, 3.0] := by native_decide

ProvenTheorem identity_unchanged : applyTransform #[1.0, 2.0, 3.0] .identity = #[1.0, 2.0, 3.0]

-- ════════════════════════════════════════════════════════════
-- § Internal claims
-- ════════════════════════════════════════════════════════════

/-- sqrt(4) = 2. -/
theorem sqrt_four_proof : sqrtTransform #[4.0] = #[2.0] := by native_decide

ProvenTheorem sqrt_four : sqrtTransform #[4.0] = #[2.0]

/-- reciprocal(2) = 0.5. -/
theorem recip_two_proof : recipTransform #[2.0] = #[0.5] := by native_decide

ProvenTheorem recip_two : recipTransform #[2.0] = #[0.5]

/-- square transform: 3² = 9. -/
theorem square_three_proof : applyTransform #[3.0] .square = #[9.0] := by native_decide

ProvenTheorem square_three : applyTransform #[3.0] .square = #[9.0]

end LeanStats.Manifests.Transform
