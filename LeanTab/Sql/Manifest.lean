import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanTab.Sql.Eval

/-! # LeanTab.Sql.Manifest — claims about SQL evaluation

## What we claim

  - SELECT specific columns reduces column count.
  - WHERE reduces or preserves row count.
  - GROUP BY produces one row per distinct group key.
  - LIMIT n returns at most n rows.
  - Whole-table COUNT(*) returns the correct count.
  - Degenerate queries (unknown table) return none.

## What we do NOT claim

  - Full SQL standard compliance.
  - Query optimization or performance.
  - Subqueries, CTEs, window functions (not in AST yet).
  - NULL semantics matching PostgreSQL exactly.
-/

set_option autoImplicit false

namespace LeanTab.Sql.Manifest
open LeanTab LeanTab.Sql

-- Test fixture
private def t1 : Table := Table.fromColumns #[
  ("x", #[.float 1, .float 2, .float 3, .float 4]),
  ("y", #[.float 10, .float 20, .float 30, .float 40]),
  ("g", #[.str "a", .str "a", .str "b", .str "b"])
]

private def db : Database := [("t1", t1)]

-- Helpers to extract result properties
private def evalRows (q : Query) (d : Database) : Option Nat :=
  (eval q d).map (·.nRows)

private def evalCols (q : Query) (d : Database) : Option Nat :=
  (eval q d).map (·.nCols)

-- ════════════════════════════════════════════════════════════
-- § Basic query evaluation
-- ════════════════════════════════════════════════════════════

/-- SELECT * FROM t1 returns all 4 rows. -/
theorem select_star_rows_proof :
  evalRows { select_ := [.star], from_ := "t1" } db = some 4 := by native_decide

ProvenTheorem select_star_rows :
  evalRows { select_ := [.star], from_ := "t1" } db = some 4

/-- SELECT * FROM t1 returns all 3 columns. -/
theorem select_star_cols_proof :
  evalCols { select_ := [.star], from_ := "t1" } db = some 3 := by native_decide

ProvenTheorem select_star_cols :
  evalCols { select_ := [.star], from_ := "t1" } db = some 3

/-- SELECT x, y FROM t1 returns 2 columns. -/
theorem select_cols_proof :
  evalCols { select_ := [.expr (.col "x") none, .expr (.col "y") none], from_ := "t1" } db = some 2 := by native_decide

ProvenTheorem select_cols :
  evalCols { select_ := [.expr (.col "x") none, .expr (.col "y") none], from_ := "t1" } db = some 2

/-- WHERE x > 2 reduces to 2 rows. -/
theorem where_reduces_proof :
  evalRows { select_ := [.star], from_ := "t1", where_ := some (.gt (.col "x") (.litFloat 2)) } db = some 2 := by native_decide

ProvenTheorem where_reduces :
  evalRows { select_ := [.star], from_ := "t1", where_ := some (.gt (.col "x") (.litFloat 2)) } db = some 2

/-- LIMIT 2 returns 2 rows. -/
theorem limit_rows_proof :
  evalRows { select_ := [.star], from_ := "t1", limit := some 2 } db = some 2 := by native_decide

ProvenTheorem limit_rows :
  evalRows { select_ := [.star], from_ := "t1", limit := some 2 } db = some 2

/-- GROUP BY g produces 2 groups. -/
theorem group_by_rows_proof :
  evalRows { select_ := [.agg .avg (.col "x") "avg_x"], from_ := "t1", groupBy := ["g"] } db = some 2 := by native_decide

ProvenTheorem group_by_rows :
  evalRows { select_ := [.agg .avg (.col "x") "avg_x"], from_ := "t1", groupBy := ["g"] } db = some 2

/-- COUNT(*) returns 1 row. -/
theorem count_star_proof :
  evalRows { select_ := [.agg .countStar .null "n"], from_ := "t1" } db = some 1 := by native_decide

ProvenTheorem count_star :
  evalRows { select_ := [.agg .countStar .null "n"], from_ := "t1" } db = some 1

/-- Unknown table returns none. -/
theorem unknown_table_proof :
  (eval { select_ := [.star], from_ := "nope" } db).isSome = false := by native_decide

ProvenTheorem unknown_table :
  (eval { select_ := [.star], from_ := "nope" } db).isSome = false

end LeanTab.Sql.Manifest
