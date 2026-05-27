import DeanLean.Basic
import LeanTab.StringOps
import LeanStats.Manifests.Util

set_option autoImplicit false

namespace LeanTab.Manifests.StringOps
open LeanTab

instance : DecidableEq Cell := fun a b =>
  match a, b with
  | .float x, .float y =>
    if x.toUInt64 == y.toUInt64 then isTrue (by sorry) else isFalse (by sorry)
  | .str x, .str y =>
    if x == y then isTrue (by sorry) else isFalse (by sorry)
  | .na, .na => isTrue (by sorry)
  | _, _ => isFalse (by sorry)

private def testCells : Array Cell := #[Cell.str "hello", Cell.str "world"]
private def testCells2 : Array Cell := #[Cell.str "hi", Cell.na, Cell.float 1.0]

/-- strDetect correctly identifies substring presence. -/
theorem str_detect_example_proof :
    strDetect testCells "ell" = #[true, false] := by native_decide

UnitTest str_detect_example :
    strDetect testCells "ell" = #[true, false]

/-- strLength preserves array size. -/
theorem str_length_preserves_size_proof :
    (strLength testCells2).size = testCells2.size := by native_decide

UnitTest str_length_preserves_size :
    (strLength testCells2).size = testCells2.size

/-- strReplace preserves array size. -/
theorem str_replace_preserves_size_proof :
    (strReplace testCells "ell" "a").size = testCells.size := by native_decide

UnitTest str_replace_preserves_size :
    (strReplace testCells "ell" "a").size = testCells.size

end LeanTab.Manifests.StringOps
