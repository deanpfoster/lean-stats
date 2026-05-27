import DeanLean.Basic
import LeanTab.Join

set_option autoImplicit false

namespace LeanTab.Manifests.Join
open LeanTab

-- Test fixtures
private def t1 : Table := Table.fromColumns #[
  ("id", #[.float 1, .float 2, .float 3]),
  ("x",  #[.float 10, .float 20, .float 30])
]

private def t2 : Table := Table.fromColumns #[
  ("id", #[.float 1, .float 3, .float 4]),
  ("y",  #[.float 100, .float 300, .float 400])
]

/-- Inner join gives 2 rows (matching ids 1 and 3). -/
theorem innerJoin_row_bound_proof :
  (innerJoin t1 t2 "id").nRows = 2 := by native_decide

UnitTest innerJoin_row_bound :
  (innerJoin t1 t2 "id").nRows = 2

/-- Left join preserves all 3 left rows. -/
theorem leftJoin_preserves_left_proof :
  (leftJoin t1 t2 "id").nRows = 3 := by native_decide

UnitTest leftJoin_preserves_left :
  (leftJoin t1 t2 "id").nRows = 3

/-- Cross join gives 9 rows (3 × 3). -/
theorem crossJoin_row_count_proof :
  (crossJoin t1 t2).nRows = 9 := by native_decide

UnitTest crossJoin_row_count :
  (crossJoin t1 t2).nRows = 9

/-- Inner join has 3 columns (id, x, y — key merged). -/
theorem innerJoin_col_count_proof :
  (innerJoin t1 t2 "id").nCols = 3 := by native_decide

UnitTest innerJoin_col_count :
  (innerJoin t1 t2 "id").nCols = 3

end LeanTab.Manifests.Join
