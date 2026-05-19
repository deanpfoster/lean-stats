import LeanTab.Table
import LeanStats.Descriptive

/-! # LeanTab.Summarize — table summary for handle-based agent interaction

When the LLM gets a handle to a table, it needs a 1-3 line summary
to reason about the data without seeing rows. This module produces
that summary.

The summary answers:
- How big? (rows × cols)
- What columns? (name + inferred type + key stats)
- How clean? (NA counts)
- What's in it? (for categoricals: distinct values; for numerics: range)
-/

set_option autoImplicit false

namespace LeanTab

/-- Inferred column type based on cell contents. -/
inductive ColType where
  | numeric    -- all non-NA cells are Float
  | categorical -- all non-NA cells are String (or mixed)
  | empty      -- all NA
  deriving Repr, BEq

/-- Summary of a single column. -/
structure ColSummary where
  name : String
  type : ColType
  nMissing : Nat
  /-- For numeric: min, max, mean. -/
  min : Option Float := none
  max : Option Float := none
  mean : Option Float := none
  /-- For categorical: number of distinct values, top 3 values by frequency. -/
  nDistinct : Option Nat := none
  topValues : Array String := #[]
  deriving Repr

/-- Summary of an entire table. -/
structure TableSummary where
  nRows : Nat
  nCols : Nat
  columns : Array ColSummary
  deriving Repr

/-- Infer the type of a column from its cells. -/
private def inferType (data : Array Cell) : ColType :=
  let nonNa := data.filter (· != .na)
  if nonNa.isEmpty then .empty
  else if nonNa.all fun c => match c with | .float _ => true | _ => false
    then .numeric
    else .categorical

/-- Summarize a single column. -/
private def summarizeCol (col : Column) : ColSummary :=
  let data := col.data
  let nMissing := data.filter (· == .na) |>.size
  let typ := inferType data
  match typ with
  | .numeric =>
    let floats := data.filterMap Cell.toFloat?
    if floats.isEmpty then { name := col.name, type := typ, nMissing }
    else
      let mn := floats.foldl (fun a b => if b < a then b else a) floats[0]!
      let mx := floats.foldl (fun a b => if b > a then b else a) floats[0]!
      let avg := LeanStats.mean floats
      { name := col.name, type := typ, nMissing,
        min := some mn, max := some mx, mean := some avg }
  | .categorical =>
    let strs := data.filterMap fun c => match c with | .str s => some s | _ => none
    -- Count distinct values
    let distinct : Array String := strs.foldl (init := #[]) fun acc s =>
      if acc.contains s then acc else acc.push s
    -- Top values by frequency
    let counts := distinct.map fun v => (v, strs.filter (· == v) |>.size)
    let sorted := counts.qsort (fun a b => a.2 > b.2)
    let top := (sorted.extract 0 (Nat.min 3 sorted.size)).map (·.1)
    { name := col.name, type := typ, nMissing,
      nDistinct := some distinct.size, topValues := top }
  | .empty =>
    { name := col.name, type := typ, nMissing }

/-- Summarize an entire table. -/
def summarizeTable (t : Table) : TableSummary :=
  { nRows := t.nRows
    nCols := t.nCols
    columns := t.columns.map summarizeCol }

/-- Render a column summary to a compact string. -/
private def renderColSummary (cs : ColSummary) : String :=
  let typeStr := match cs.type with
    | .numeric => "Float"
    | .categorical => "Str"
    | .empty => "Empty"
  let stats := match cs.type with
    | .numeric =>
      let mn := cs.min.getD 0 |> toString
      let mx := cs.max.getD 0 |> toString
      let avg := cs.mean.getD 0 |> toString
      s!"[{mn}–{mx}, μ={avg}]"
    | .categorical =>
      let nd := cs.nDistinct.getD 0
      let top := if cs.topValues.isEmpty then ""
        else " (" ++ String.intercalate ", " cs.topValues.toList ++ ")"
      s!"{nd} levels{top}"
    | .empty => "all NA"
  let na := if cs.nMissing > 0 then s!" ({cs.nMissing} NA)" else ""
  s!"{cs.name}:{typeStr} {stats}{na}"

/-- Render a table summary to a compact multi-line string.
    This is what the LLM sees instead of raw data. -/
def TableSummary.render (ts : TableSummary) : String :=
  let header := s!"{ts.nRows} rows × {ts.nCols} cols"
  let colLines := ts.columns.toList.map renderColSummary
  -- If too many columns, truncate
  let shown := if colLines.length > 8
    then colLines.take 6 ++ [s!"... and {colLines.length - 6} more columns"]
    else colLines
  header ++ "\n" ++ String.intercalate "\n" shown

/-- One-shot: summarize a table and render to string. -/
def tableSummary (t : Table) : String :=
  (summarizeTable t).render

end LeanTab
