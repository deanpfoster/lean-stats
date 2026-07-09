import LeanTab.Table
import LeanStats.Descriptive

/-! # LeanTab.Summarize — budget-aware table summary

Produces a summary string that fits within a character budget.
Adapts detail level to the space available:

- **1200 chars** (default): full detail — 8 cols, ranges, means, top values, NA counts
- **400 chars**: compact — 4 cols, ranges only, no top values
- **200 chars**: minimal — 2 cols, type only
- **80 chars**: one-liner — just dimensions + column names
-/
-- Manifest claims: LeanTab/Manifests/Summarize.lean

set_option autoImplicit false

namespace LeanTab

/-- Inferred column type. -/
inductive ColType where
  | numeric | categorical | empty
  deriving Repr, BEq

/-- Summary of a single column. -/
structure ColSummary where
  name : String
  type : ColType
  nMissing : Nat
  min : Option Float := none
  max : Option Float := none
  mean : Option Float := none
  nDistinct : Option Nat := none
  topValues : Array String := #[]
  deriving Repr

/-- Summary of an entire table. -/
structure TableSummary where
  nRows : Nat
  nCols : Nat
  columns : Array ColSummary
  deriving Repr

/-- The default maximum summary length. -/
def maxSummaryLen : Nat := 1200

private def inferType (data : Array Cell) : ColType :=
  let nonNa := data.filter (· != .na)
  if nonNa.isEmpty then .empty
  else if nonNa.all fun c => match c with | .float _ => true | _ => false
    then .numeric
    else .categorical

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
      { name := col.name, type := typ, nMissing, min := some mn, max := some mx, mean := some avg }
  | .categorical =>
    let strs := data.filterMap fun c => match c with | .str s => some s | _ => none
    let distinct : Array String := strs.foldl (init := #[]) fun acc s =>
      if acc.contains s then acc else acc.push s
    let counts := distinct.map fun v => (v, strs.filter (· == v) |>.size)
    let sorted := counts.qsort (fun a b => a.2 > b.2)
    let top := (sorted.extract 0 (Nat.min 3 sorted.size)).map (·.1)
    { name := col.name, type := typ, nMissing, nDistinct := some distinct.size, topValues := top }
  | .empty => { name := col.name, type := typ, nMissing }

/-- Summarize an entire table (structured, before rendering). -/
def summarizeTable (t : Table) : TableSummary :=
  { nRows := t.nRows, nCols := t.nCols, columns := t.columns.map summarizeCol }

-- ════════════════════════════════════════════════════════════
-- § Budget-aware rendering
-- ════════════════════════════════════════════════════════════

private def trunc (s : String) (n : Nat) : String :=
  if s.length ≤ n then s else (s.take n).toString ++ "…"

private def fmtFloat (f : Float) (maxLen : Nat := 10) : String :=
  trunc (toString f) maxLen

/-- Render a column at full detail: "name:Type [min–max, μ=mean] (N NA)" -/
private def renderColFull (cs : ColSummary) : String :=
  let name := trunc cs.name 25
  let typ := match cs.type with | .numeric => "Float" | .categorical => "Str" | .empty => "Empty"
  let stats := match cs.type with
    | .numeric => s!"[{fmtFloat (cs.min.getD 0)}–{fmtFloat (cs.max.getD 0)}, μ={fmtFloat (cs.mean.getD 0)}]"
    | .categorical =>
      let nd := cs.nDistinct.getD 0
      let top := if cs.topValues.isEmpty then ""
        else " (" ++ String.intercalate ", " (cs.topValues.toList.map (trunc · 15)) ++ ")"
      s!"{nd} levels{top}"
    | .empty => "all NA"
  let na := if cs.nMissing > 0 then s!" ({cs.nMissing} NA)" else ""
  trunc (s!"{name}:{typ} {stats}{na}") 120

/-- Render a column at compact detail: "name:Type [min–max]" -/
private def renderColCompact (cs : ColSummary) : String :=
  let name := trunc cs.name 20
  let typ := match cs.type with | .numeric => "F" | .categorical => "S" | .empty => "?"
  match cs.type with
  | .numeric => s!"{name}:{typ}[{fmtFloat (cs.min.getD 0) 8}–{fmtFloat (cs.max.getD 0) 8}]"
  | .categorical => s!"{name}:{typ}({cs.nDistinct.getD 0})"
  | .empty => s!"{name}:NA"

/-- Render a column at minimal detail: "name:Type" -/
private def renderColMinimal (cs : ColSummary) : String :=
  let name := trunc cs.name 15
  match cs.type with
  | .numeric => s!"{name}:F"
  | .categorical => s!"{name}:S"
  | .empty => s!"{name}:?"

/-- Render a table summary within a character budget.
    Adapts detail level to fit. -/
def TableSummary.renderBudget (ts : TableSummary) (budget : Nat := maxSummaryLen) : String :=
  let header := s!"{ts.nRows} rows × {ts.nCols} cols"
  if budget ≤ header.length + 5 then
    trunc header budget
  else
    let remaining := budget - header.length - 1  -- -1 for newline
    -- Decide detail level based on budget
    let (renderer, maxCols) :=
      if remaining ≥ 120 * 8 then (renderColFull, Nat.min 8 ts.columns.size)
      else if remaining ≥ 80 * 4 then (renderColFull, Nat.min 4 ts.columns.size)
      else if remaining ≥ 40 * 4 then (renderColCompact, Nat.min 4 ts.columns.size)
      else if remaining ≥ 20 * 3 then (renderColMinimal, Nat.min 6 ts.columns.size)
      else (renderColMinimal, Nat.min 3 ts.columns.size)
    let colSummaries := (ts.columns.extract 0 maxCols).toList.map renderer
    let suffix := if maxCols < ts.columns.size
      then [s!"… +{ts.columns.size - maxCols} more"]
      else []
    let body := String.intercalate "\n" (colSummaries ++ suffix)
    let result := header ++ "\n" ++ body
    trunc result budget

/-- One-shot: summarize a table within a character budget. -/
def tableSummary (t : Table) (budget : Nat := maxSummaryLen) : String :=
  (summarizeTable t).renderBudget budget

end LeanTab
