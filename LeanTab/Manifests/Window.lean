import DeanLean.Basic
import LeanTab.Window
import LeanStats.Manifests.Util

set_option autoImplicit false

namespace LeanTab.Manifests.Window
open LeanTab

/-- lag preserves array length. -/
theorem lag_preserves_length_proof :
  (lag #[Cell.float 1, Cell.float 2, Cell.float 3] 1).size = 3 := by native_decide

UnitTest lag_preserves_length :
  (lag #[Cell.float 1, Cell.float 2, Cell.float 3] 1).size = 3

/-- lead preserves array length. -/
theorem lead_preserves_length_proof :
  (lead #[Cell.float 1, Cell.float 2, Cell.float 3] 1).size = 3 := by native_decide

UnitTest lead_preserves_length :
  (lead #[Cell.float 1, Cell.float 2, Cell.float 3] 1).size = 3

/-- cumSum computes running sum. -/
theorem cumsum_correct_proof :
  cumSum #[1.0, 2.0, 3.0] = #[1.0, 3.0, 6.0] := by native_decide

UnitTest cumsum_correct :
  cumSum #[1.0, 2.0, 3.0] = #[1.0, 3.0, 6.0]

/-- rowNumber produces correct size. -/
theorem row_number_size_proof :
  (rowNumber 3).size = 3 := by native_decide

UnitTest row_number_size :
  (rowNumber 3).size = 3

/-- cumSum last element equals total. -/
theorem cumsum_last_proof :
  (cumSum #[1.0, 2.0, 3.0]).getD 2 0 = 6.0 := by native_decide

UnitTest cumsum_last :
  (cumSum #[1.0, 2.0, 3.0]).getD 2 0 = 6.0

end LeanTab.Manifests.Window
