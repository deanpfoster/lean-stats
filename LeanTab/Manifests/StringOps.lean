import LeanManifests.Basic
import LeanTab.StringOps
import LeanStats.Manifests.Util

set_option autoImplicit false

namespace LeanTab.Manifests.StringOps
open LeanTab

private def testCells : Array Cell := #[Cell.str "hello", Cell.str "world"]
private def testCells2 : Array Cell := #[Cell.str "hi", Cell.na, Cell.float 1.0]

/-- strDetect correctly identifies substring presence. -/
theorem str_detect_example_proof :
    strDetect testCells "ell" = #[true, false] := by native_decide

ProvenTheorem str_detect_example :
    strDetect testCells "ell" = #[true, false]

/-- strLength preserves array size. -/
theorem str_length_preserves_size_proof :
    (strLength testCells2).size = testCells2.size := by native_decide

ProvenTheorem str_length_preserves_size :
    (strLength testCells2).size = testCells2.size

/-- strReplace preserves array size. -/
theorem str_replace_preserves_size_proof :
    (strReplace testCells "ell" "a").size = testCells.size := by native_decide

ProvenTheorem str_replace_preserves_size :
    (strReplace testCells "ell" "a").size = testCells.size

end LeanTab.Manifests.StringOps
