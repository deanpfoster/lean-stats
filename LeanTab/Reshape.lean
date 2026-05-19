import LeanTab.GroupBy

/-! # LeanTab.Reshape — pivot_longer and pivot_wider

Equivalent to `tidyr::pivot_longer` and `tidyr::pivot_wider`.

- `pivotLonger`: wide → long (multiple columns become name/value pairs)
- `pivotWider`: long → wide (name/value pairs become columns)
-/

set_option autoImplicit false

namespace LeanTab
open Table

/-- Pivot from wide to long format.
    `cols` are the columns to pivot; they become rows.
    `namesTo` is the new column holding the original column names.
    `valuesTo` is the new column holding the values.
    Non-pivoted columns are repeated for each pivoted column.

    Equivalent to `tidyr::pivot_longer`. -/
def pivotLonger (t : Table) (cols : Array String)
    (namesTo : String := "name") (valuesTo : String := "value") : Table :=
  let idCols := t.columns.filter fun c => !cols.contains c.name
  let n := t.nRows
  let nPivot := cols.size
  let totalRows := n * nPivot
  -- Repeat id columns nPivot times each row
  let newIdCols := idCols.map fun c =>
    let data := (Array.range totalRows).map fun i =>
      c.data.getD (i / nPivot) .na
    { name := c.name, data : Column }
  -- Names column: cycle through pivot column names
  let namesData := (Array.range totalRows).map fun i =>
    Cell.str (cols.getD (i % nPivot) "")
  -- Values column: pull from the appropriate pivot column
  let valuesData := (Array.range totalRows).map fun i =>
    let row := i / nPivot
    let colIdx := i % nPivot
    let colName := cols.getD colIdx ""
    (t.colData colName).getD row .na
  { columns := newIdCols ++ #[
      { name := namesTo, data := namesData },
      { name := valuesTo, data := valuesData }
    ] }

/-- Pivot from long to wide format.
    `namesFrom` is the column whose values become new column names.
    `valuesFrom` is the column whose values fill the new columns.
    Remaining columns define the row identity.

    Equivalent to `tidyr::pivot_wider`. -/
def pivotWider (t : Table) (namesFrom valuesFrom : String) : Table :=
  let nameData := t.colData namesFrom
  let valueData := t.colData valuesFrom
  let idColNames := (t.colNames).filter fun n => n != namesFrom && n != valuesFrom
  -- Unique pivot names (new column names)
  let pivotNames : Array String := nameData.foldl (init := #[]) fun acc c =>
    let s := c.toStr
    if acc.contains s then acc else acc.push s
  -- Group by id columns to find unique rows
  -- Simple approach: use first id column as grouper, collect row indices
  let n := t.nRows
  -- Build row keys (concatenation of id column values)
  let rowKeys := (Array.range n).map fun i =>
    idColNames.foldl (fun acc name => acc ++ (t.get i name).toStr ++ "|") ""
  -- Unique row keys in order
  let init2 : Array String × Array Nat := (#[], #[])
  let (uniqueKeys, firstIdx) := rowKeys.foldl (init := init2)
    fun (ks, idxs) key =>
      if ks.contains key then (ks, idxs)
      else (ks.push key, idxs.push ks.size)
  let _ := firstIdx  -- suppress unused warning
  let nOutRows := uniqueKeys.size
  -- For each unique row, find all source rows
  let rowGroups := uniqueKeys.map fun key =>
    (Array.range n).filter fun i => rowKeys.getD i "" == key
  -- Build id columns for output
  let outIdCols := idColNames.map fun name =>
    let data := rowGroups.map fun group =>
      (t.colData name).getD (group.getD 0 0) .na
    ({ name, data } : Column)
  -- Build pivot columns
  let outPivotCols := pivotNames.map fun pname =>
    let data := rowGroups.map fun group =>
      -- Find the row in this group where namesFrom == pname
      match group.find? (fun i => (nameData.getD i .na).toStr == pname) with
      | some i => valueData.getD i .na
      | none => .na
    ({ name := pname, data } : Column)
  { columns := outIdCols ++ outPivotCols }

end LeanTab
