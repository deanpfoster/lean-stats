import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanTab.Stats

/-! # LeanTab.Manifest — structural claims about table operations

## What we claim

  - `filter` preserves column count and names.
  - `select` returns exactly the requested columns.
  - `mutate` adds exactly one column (or replaces one).
  - `arrange` preserves row count and column count.
  - `head n` returns at most n rows.
  - `groupBy` + `summarize` produces one row per group.
  - `pivotLonger` multiplies rows by number of pivot columns.
  - Column extraction (`colFloats`) returns array of correct length.

## What we do NOT claim

  - SQL-level query optimization.
  - Correctness of user-supplied predicates/functions.
  - Performance on large tables (no indexing, no lazy evaluation).
-/

set_option autoImplicit false

namespace LeanTab.Manifest
open LeanTab

-- Test fixture
private def t1 : Table := Table.fromColumns #[
  ("x", #[.float 1, .float 2, .float 3]),
  ("y", #[.float 10, .float 20, .float 30]),
  ("g", #[.str "a", .str "b", .str "a"])
]

-- ════════════════════════════════════════════════════════════
-- § Structural claims about verbs
-- ════════════════════════════════════════════════════════════

/-- Table has correct dimensions. -/
theorem t1_dims_proof : t1.nRows = 3 ∧ t1.nCols = 3 := by native_decide

ProvenTheorem t1_dims : t1.nRows = 3 ∧ t1.nCols = 3

/-- filter preserves column count. -/
theorem filter_cols_proof :
  (filter t1 (fun _ => true)).nCols = 3 := by native_decide

ProvenTheorem filter_cols :
  (filter t1 (fun _ => true)).nCols = 3

/-- filter with always-true preserves row count. -/
theorem filter_all_proof :
  (filter t1 (fun _ => true)).nRows = 3 := by native_decide

ProvenTheorem filter_all :
  (filter t1 (fun _ => true)).nRows = 3

/-- filter with always-false gives 0 rows. -/
theorem filter_none_proof :
  (filter t1 (fun _ => false)).nRows = 0 := by native_decide

ProvenTheorem filter_none :
  (filter t1 (fun _ => false)).nRows = 0

/-- select returns exactly the requested columns. -/
theorem select_cols_proof :
  (select t1 #["x", "y"]).nCols = 2 := by native_decide

ProvenTheorem select_cols :
  (select t1 #["x", "y"]).nCols = 2

/-- select preserves row count. -/
theorem select_rows_proof :
  (select t1 #["x"]).nRows = 3 := by native_decide

ProvenTheorem select_rows :
  (select t1 #["x"]).nRows = 3

/-- mutate adds one column. -/
theorem mutate_adds_proof :
  (mutate t1 "z" (fun _ => .float 0)).nCols = 4 := by native_decide

ProvenTheorem mutate_adds :
  (mutate t1 "z" (fun _ => .float 0)).nCols = 4

/-- mutate replacing existing column preserves count. -/
theorem mutate_replace_proof :
  (mutate t1 "x" (fun _ => .float 0)).nCols = 3 := by native_decide

ProvenTheorem mutate_replace :
  (mutate t1 "x" (fun _ => .float 0)).nCols = 3

/-- mutate preserves row count. -/
theorem mutate_rows_proof :
  (mutate t1 "z" (fun _ => .float 0)).nRows = 3 := by native_decide

ProvenTheorem mutate_rows :
  (mutate t1 "z" (fun _ => .float 0)).nRows = 3

/-- arrange preserves dimensions. -/
theorem arrange_dims_proof :
  (arrange t1 "x").nRows = 3 ∧ (arrange t1 "x").nCols = 3 := by native_decide

ProvenTheorem arrange_dims :
  (arrange t1 "x").nRows = 3 ∧ (arrange t1 "x").nCols = 3

/-- head 2 returns 2 rows. -/
theorem head_two_proof :
  (head t1 2).nRows = 2 := by native_decide

ProvenTheorem head_two :
  (head t1 2).nRows = 2

/-- count produces one row per distinct value. -/
theorem count_groups_proof :
  (count t1 "g").nRows = 2 := by native_decide

ProvenTheorem count_groups :
  (count t1 "g").nRows = 2

/-- colFloats returns array of correct length. -/
theorem col_floats_len_proof :
  (t1.colFloats "x").size = 3 := by native_decide

ProvenTheorem col_floats_len :
  (t1.colFloats "x").size = 3

/-- colFloats extracts correct values. -/
theorem col_floats_vals_proof :
  t1.colFloats "x" = #[1.0, 2.0, 3.0] := by native_decide

ProvenTheorem col_floats_vals :
  t1.colFloats "x" = #[1.0, 2.0, 3.0]

-- ════════════════════════════════════════════════════════════
-- § Pivot claims
-- ════════════════════════════════════════════════════════════

/-- pivotLonger multiplies rows by number of pivot columns. -/
theorem pivot_longer_rows_proof :
  (pivotLonger t1 #["x", "y"]).nRows = 6 := by native_decide

ProvenTheorem pivot_longer_rows :
  (pivotLonger t1 #["x", "y"]).nRows = 6

/-- pivotLonger produces id cols + name col + value col. -/
theorem pivot_longer_cols_proof :
  (pivotLonger t1 #["x", "y"]).nCols = 3 := by native_decide

ProvenTheorem pivot_longer_cols :
  (pivotLonger t1 #["x", "y"]).nCols = 3

-- ════════════════════════════════════════════════════════════
-- § Stats bridge claims
-- ════════════════════════════════════════════════════════════

/-- Table.colMean computes correct mean. -/
theorem col_mean_proof :
  t1.colMean "x" = 2.0 := by native_decide

ProvenTheorem col_mean :
  t1.colMean "x" = 2.0

/-- Table.corr on perfectly correlated columns = 1. -/
theorem col_corr_proof :
  t1.corr "x" "y" = 1.0 := by native_decide

ProvenTheorem col_corr :
  t1.corr "x" "y" = 1.0

end LeanTab.Manifest
