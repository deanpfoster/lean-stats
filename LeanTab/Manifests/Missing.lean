import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanTab.Missing

/-! # LeanTab.Manifests.Missing — claims for NA handling -/

set_option autoImplicit false

namespace LeanTab.Manifests.Missing
open LeanTab

instance : DecidableEq Cell := fun a b =>
  match a, b with
  | .float x, .float y =>
    if h : x = y then isTrue (by rw [h]) else isFalse (by intro heq; cases heq; exact h rfl)
  | .str x, .str y =>
    if h : x = y then isTrue (by rw [h]) else isFalse (by intro heq; cases heq; exact h rfl)
  | .na, .na => isTrue rfl
  | .float _, .str _ => isFalse (by intro h; cases h)
  | .float _, .na => isFalse (by intro h; cases h)
  | .str _, .float _ => isFalse (by intro h; cases h)
  | .str _, .na => isFalse (by intro h; cases h)
  | .na, .float _ => isFalse (by intro h; cases h)
  | .na, .str _ => isFalse (by intro h; cases h)

private def xs : Array Cell := #[.float 1, .na, .float 3, .na]

private def tMissing : Table := Table.fromColumns #[
  ("a", #[.float 1, .na, .float 3]),
  ("b", #[.str "x", .str "y", .str "z"])
]

/-- countNa counts exactly the NA values. -/
theorem countNa_claim_proof : countNa xs = 2 := by native_decide

ProvenTheorem countNa_claim : countNa xs = 2

/-- fillForward propagates last non-na value. -/
theorem fillForward_claim_proof :
  fillForward xs = #[.float 1, .float 1, .float 3, .float 3] := by native_decide

ProvenTheorem fillForward_claim :
  fillForward xs = #[.float 1, .float 1, .float 3, .float 3]

/-- dropNa removes exactly the NA rows. -/
theorem dropNa_claim_proof :
  (dropNa tMissing "a").nRows = tMissing.nRows - 1 := by native_decide

ProvenTheorem dropNa_claim :
  (dropNa tMissing "a").nRows = tMissing.nRows - 1

end LeanTab.Manifests.Missing
