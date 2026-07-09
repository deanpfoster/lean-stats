import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanTab.Missing

/-! # LeanTab.Manifests.Missing — claims for NA handling -/

set_option autoImplicit false

namespace LeanTab.Manifests.Missing
open LeanTab

private def cellBitsEq : Cell → Cell → Bool
  | .float x, .float y => LeanStats.Manifests.floatBitsEq x y
  | .str x, .str y => x == y
  | .na, .na => true
  | _, _ => false

private def cellListBitsEq : List Cell → List Cell → Bool
  | [], [] => true
  | x :: xs, y :: ys => cellBitsEq x y && cellListBitsEq xs ys
  | _, _ => false

private def cellArrayBitsEq (xs ys : Array Cell) : Bool :=
  cellListBitsEq xs.toList ys.toList

private def xs : Array Cell := #[.float 1, .na, .float 3, .na]

private def tMissing : Table := Table.fromColumns #[
  ("a", #[.float 1, .na, .float 3]),
  ("b", #[.str "x", .str "y", .str "z"])
]

/-- countNa counts exactly the NA values. -/
theorem countNa_claim_proof : countNa xs = 2 := by native_decide

ProvenTheorem countNa_claim : countNa xs = 2

/-- fillForward propagates last non-na value. -/
theorem fillForward_claim_test :
  cellArrayBitsEq (fillForward xs) #[.float 1, .float 1, .float 3, .float 3] = true := by native_decide

TestedConjecture fillForward_claim :
  fillForward xs = #[.float 1, .float 1, .float 3, .float 3]

/-- dropNa removes exactly the NA rows. -/
theorem dropNa_claim_proof :
  (dropNa tMissing "a").nRows = tMissing.nRows - 1 := by native_decide

ProvenTheorem dropNa_claim :
  (dropNa tMissing "a").nRows = tMissing.nRows - 1

end LeanTab.Manifests.Missing
