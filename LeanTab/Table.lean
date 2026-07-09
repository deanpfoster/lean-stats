/-! # LeanTab.Table — column-oriented table type

The core data structure. A Table is a named collection of columns,
each column being an array of a uniform cell type. This is the
shape that both tidyverse verbs and statistics functions consume.

Design decisions:
- **Column-oriented** (not row-oriented): most stats operations work
  column-at-a-time (mean of a column, regression of two columns).
- **Heterogeneous columns via sum type**: a cell is Float, String, or
  missing (NA). This matches R's behavior without needing dependent types.
- **Column names are strings**: matches R/SQL/pandas convention.
- **Invariant**: all columns have the same length (= nRows).

When extracted as `lean-tab`, this file becomes the root of that library.
The stats bridge (`LeanTab.Stats`) imports `LeanStats` and provides the
glue; everything else in `LeanTab/` is self-contained.
-/
-- Manifest claims: LeanTab/Manifest.lean

set_option autoImplicit false

namespace LeanTab

/-- A cell value. Matches R's atomic types. -/
inductive Cell where
  | float (v : Float)
  | str (v : String)
  | na
  deriving Repr, BEq

instance : Inhabited Cell := ⟨.na⟩

/-- Extract Float from a cell, or 0 if not a float. -/
def Cell.toFloat : Cell → Float
  | .float v => v
  | _ => 0

/-- Extract Float from a cell, or none if not a float. -/
def Cell.toFloat? : Cell → Option Float
  | .float v => some v
  | _ => none

/-- Extract String from a cell, or "" if not a string. -/
def Cell.toStr : Cell → String
  | .str v => v
  | .float v => toString v
  | .na => "NA"

/-- A column is a named array of cells. -/
structure Column where
  name : String
  data : Array Cell
  deriving Repr

/-- A table: ordered list of columns, all same length. -/
structure Table where
  columns : Array Column
  deriving Repr

namespace Table

/-- Number of rows. -/
def nRows (t : Table) : Nat :=
  match t.columns[0]? with
  | some col => col.data.size
  | none => 0

/-- Number of columns. -/
def nCols (t : Table) : Nat := t.columns.size

/-- Column names. -/
def colNames (t : Table) : Array String :=
  t.columns.map (·.name)

/-- Get a column by name. -/
def col (t : Table) (name : String) : Option Column :=
  t.columns.find? (·.name == name)

/-- Get a column's data as Array Cell. -/
def colData (t : Table) (name : String) : Array Cell :=
  match t.col name with
  | some c => c.data
  | none => #[]

/-- Get a column as Array Float (NAs and strings become 0). -/
def colFloats (t : Table) (name : String) : Array Float :=
  (t.colData name).map Cell.toFloat

/-- Get a column as Array (Option Float) (preserving NA). -/
def colFloats? (t : Table) (name : String) : Array (Option Float) :=
  (t.colData name).map Cell.toFloat?

/-- Get a column as Array String. -/
def colStrings (t : Table) (name : String) : Array String :=
  (t.colData name).map Cell.toStr

/-- Get a single cell by row and column name. -/
def get (t : Table) (row : Nat) (colName : String) : Cell :=
  (t.colData colName).getD row .na

/-- Get a row as an array of cells (column order). -/
def row (t : Table) (i : Nat) : Array Cell :=
  t.columns.map fun c => c.data.getD i .na

/-- Build a table from column names and row data. -/
def fromRows (names : Array String) (rows : Array (Array Cell)) : Table :=
  let cols := names.mapIdx fun j name =>
    let data := rows.map fun r => r.getD j .na
    { name, data }
  { columns := cols }

/-- Build a table from named column arrays. -/
def fromColumns (cols : Array (String × Array Cell)) : Table :=
  { columns := cols.map fun (name, data) => { name, data } }

/-- Empty table with given column names. -/
def empty (names : Array String) : Table :=
  { columns := names.map fun name => { name, data := #[] } }

end Table

/-- Convert a categorical (String) column into k-1 dummy/indicator columns,
    dropping the first level as reference. Removes the original column. -/
def Table.dummyCode (t : Table) (col : String) : Table :=
  let vals := t.colStrings col
  let levels := vals.foldl (fun acc v => if acc.contains v then acc else acc.push v) #[]
  -- drop first level (reference category)
  let dummyLevels := levels.extract 1 levels.size
  -- remove original column
  let baseCols := t.columns.filter (·.name != col)
  -- create indicator columns
  let newCols := dummyLevels.map fun lv =>
    let data := vals.map fun v => Cell.float (if v == lv then 1.0 else 0.0)
    ({ name := col ++ "_" ++ lv, data } : Column)
  { columns := baseCols ++ newCols }

/-- Apply dummyCode to multiple columns. -/
def Table.dummyCodeAll (t : Table) (cols : Array String) : Table :=
  cols.foldl (fun acc c => acc.dummyCode c) t

/-- Create an interaction column "col1×col2" as element-wise product of two Float columns. -/
def Table.interactionCol (t : Table) (col1 col2 : String) : Table :=
  let xs := t.colFloats col1
  let ys := t.colFloats col2
  let data := Array.zipWith (fun a b => Cell.float (a * b)) xs ys
  let newCol : Column := { name := col1 ++ "×" ++ col2, data }
  { columns := t.columns.push newCol }

end LeanTab
