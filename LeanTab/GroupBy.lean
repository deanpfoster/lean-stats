import LeanTab.Verbs

/-! # LeanTab.GroupBy — split-apply-combine

The `group_by` + `summarize` pattern from dplyr:
1. Split the table into groups by one or more columns
2. Apply an aggregation function to each group
3. Combine results into a new table

Also provides `count` (frequency table) as a common special case.
-/

set_option autoImplicit false

namespace LeanTab
open Table

/-- A grouped table: the original table plus group keys. -/
structure Grouped where
  table : Table
  byCol : String
  /-- Distinct group keys in order of first appearance. -/
  keys : Array Cell
  /-- Row indices for each group (parallel to keys). -/
  groups : Array (Array Nat)
  deriving Repr

/-- Group a table by a column. Equivalent to `dplyr::group_by`. -/
def groupBy (t : Table) (colName : String) : Grouped :=
  let data := t.colData colName
  let init : Array Cell × Array (Array Nat) := (#[], #[])
  let (keys, groups) := (Array.range t.nRows).foldl (init := init)
    fun (ks, gs) i =>
      let v := data.getD i .na
      match ks.findIdx? (· == v) with
      | some idx => (ks, gs.modify idx (·.push i))
      | none => (ks.push v, gs.push #[i])
  { table := t, byCol := colName, keys, groups }

/-- Summarize each group with a named aggregation.
    `f` receives the subset of a column's cells for one group.
    Equivalent to `dplyr::summarize`. -/
def summarize (g : Grouped) (resultCol : String)
    (sourceCol : String) (f : Array Cell → Cell) : Table :=
  let groupVals := g.groups.map fun indices =>
    let cells := indices.map fun i =>
      (g.table.colData sourceCol).getD i .na
    f cells
  Table.fromColumns #[
    (g.byCol, g.keys),
    (resultCol, groupVals)
  ]

/-- Summarize with multiple aggregations. Returns a table with the
    group key column plus one column per (name, sourceCol, agg) triple. -/
def summarizeMany (g : Grouped)
    (aggs : Array (String × String × (Array Cell → Cell))) : Table :=
  let aggCols := aggs.map fun (name, src, f) =>
    let vals := g.groups.map fun indices =>
      let cells := indices.map fun i =>
        (g.table.colData src).getD i .na
      f cells
    (name, vals)
  let allCols := #[(g.byCol, g.keys)] ++ aggCols
  Table.fromColumns allCols

/-- Count occurrences of each value in a column.
    Equivalent to `dplyr::count`. -/
def count (t : Table) (colName : String) : Table :=
  let g := groupBy t colName
  let counts := g.groups.map fun indices =>
    Cell.float indices.size.toFloat
  Table.fromColumns #[
    (colName, g.keys),
    ("n", counts)
  ]

-- ════════════════════════════════════════════════════════════
-- § Common aggregation functions (for use with summarize)
-- ════════════════════════════════════════════════════════════

/-- Sum of float cells. NAs treated as 0. -/
def aggSum (cells : Array Cell) : Cell :=
  .float (cells.foldl (fun acc c => acc + c.toFloat) 0)

/-- Mean of float cells. NAs treated as 0. -/
def aggMean (cells : Array Cell) : Cell :=
  if cells.isEmpty then .na
  else .float ((cells.foldl (fun acc c => acc + c.toFloat) 0) / cells.size.toFloat)

/-- Count of non-NA cells. -/
def aggN (cells : Array Cell) : Cell :=
  let n := cells.foldl (fun acc c => match c with | .na => acc | _ => acc + 1.0) 0.0
  .float n

/-- Min of float cells. -/
def aggMin (cells : Array Cell) : Cell :=
  let floats := cells.filterMap Cell.toFloat?
  match floats.get? 0 with
  | none => .na
  | some init => .float (floats.foldl (fun a b => if b < a then b else a) init)

/-- Max of float cells. -/
def aggMax (cells : Array Cell) : Cell :=
  let floats := cells.filterMap Cell.toFloat?
  match floats.get? 0 with
  | none => .na
  | some init => .float (floats.foldl (fun a b => if b > a then b else a) init)

/-- Group a table by multiple columns using a composite key (values joined with "|"). -/
def groupByMany (t : Table) (cols : Array String) : Grouped :=
  let init : Array Cell × Array (Array Nat) := (#[], #[])
  let (keys, groups) := (Array.range t.nRows).foldl (init := init)
    fun (ks, gs) i =>
      let compositeKey := String.intercalate "|" (cols.toList.map fun c =>
        (t.colData c).getD i .na |>.toStr)
      let v := Cell.str compositeKey
      match ks.findIdx? (· == v) with
      | some idx => (ks, gs.modify idx (·.push i))
      | none => (ks.push v, gs.push #[i])
  { table := t, byCol := (cols.getD 0 ""), keys, groups }

end LeanTab
