import LeanTab.Table

/-! # LeanTab.Verbs — dplyr-style table manipulation verbs

The core tidyverse verbs for row/column manipulation:
- `filter` — keep rows matching a predicate
- `select` — keep/reorder columns by name
- `mutate` — add or replace a column
- `arrange` — sort rows by a column
- `rename` — rename a column
- `head` / `tail` — first/last n rows
- `distinct` — unique rows by column

All are pure functions Table → Table. They compose via `|>`.
-/

set_option autoImplicit false

namespace LeanTab
open Table

/-- Keep rows where predicate on the row's cells is true.
    Equivalent to `dplyr::filter`. -/
def filter (t : Table) (pred : Array Cell → Bool) : Table :=
  let n := t.nRows
  let mask := (Array.range n).filter fun i => pred (t.row i)
  { columns := t.columns.map fun c =>
      { c with data := mask.map fun i => c.data.getD i .na } }

/-- Keep only the named columns, in the order given.
    Equivalent to `dplyr::select`. -/
def select (t : Table) (names : Array String) : Table :=
  { columns := names.filterMap fun name => t.col name }

/-- Add or replace a column computed from existing row data.
    Equivalent to `dplyr::mutate` for a single column. -/
def mutate (t : Table) (name : String) (f : Array Cell → Cell) : Table :=
  let n := t.nRows
  let newData := (Array.range n).map fun i => f (t.row i)
  let newCol : Column := { name, data := newData }
  -- Replace if exists, append if new
  let existing := t.columns.findIdx? (·.name == name)
  match existing with
  | some idx => { columns := t.columns.set! idx newCol }
  | none => { columns := t.columns.push newCol }

/-- Sort rows by a column (ascending). NAs sort last.
    Equivalent to `dplyr::arrange`. -/
def arrange (t : Table) (colName : String) : Table :=
  let data := t.colData colName
  let indices := (Array.range t.nRows).qsort fun a b =>
    match data.getD a .na, data.getD b .na with
    | .float x, .float y => x < y
    | .str x, .str y => x < y
    | .na, _ => false  -- NAs last
    | _, .na => true
    | .float _, .str _ => true
    | .str _, .float _ => false
  { columns := t.columns.map fun c =>
      { c with data := indices.map fun i => c.data.getD i .na } }

/-- Rename a column. Equivalent to `dplyr::rename`. -/
def rename (t : Table) (old new_ : String) : Table :=
  { columns := t.columns.map fun c =>
      if c.name == old then { c with name := new_ } else c }

/-- First n rows. Equivalent to `head`. -/
def head (t : Table) (n : Nat := 6) : Table :=
  let n' := Nat.min n t.nRows
  { columns := t.columns.map fun c =>
      { c with data := c.data.extract 0 n' } }

/-- Last n rows. Equivalent to `tail`. -/
def tail (t : Table) (n : Nat := 6) : Table :=
  let n' := Nat.min n t.nRows
  let start := t.nRows - n'
  { columns := t.columns.map fun c =>
      { c with data := c.data.extract start c.data.size } }

/-- Keep distinct rows by a column's values. First occurrence kept.
    Equivalent to `dplyr::distinct`. -/
def distinct (t : Table) (colName : String) : Table :=
  let data := t.colData colName
  let init : Array Cell × Array Nat := (#[], #[])
  let (_, kept) := (Array.range t.nRows).foldl (init := init)
    fun (seen, acc) i =>
      let v := data.getD i .na
      if seen.contains v then (seen, acc)
      else (seen.push v, acc.push i)
  { columns := t.columns.map fun c =>
      { c with data := kept.map fun i => c.data.getD i .na } }

end LeanTab
