import LeanTab.Table
import LeanTab.Missing

set_option autoImplicit false

namespace LeanTab

structure CleaningStep where
  action : String
  column : String
  detail : String
  deriving Repr

structure CleanResult where
  table : Table
  steps : Array CleaningStep
  deriving Repr

private def isAllNa (col : Column) : Bool :=
  col.data.all fun c => match c with | .na => true | _ => false

private def isConstant (col : Column) : Bool :=
  let nonNa := col.data.filter fun c => match c with | .na => false | _ => true
  match nonNa.get? 0 with
  | none => true
  | some first => nonNa.all (· == first)

private def naRatio (col : Column) : Float :=
  if col.data.size == 0 then 0.0
  else (countNa col.data).toFloat / col.data.size.toFloat

private def isStringCol (col : Column) : Bool :=
  col.data.any fun c => match c with | .str _ => true | _ => false

private def tryParseFloat (s : String) : Option Float :=
  let s := s.trim
  if s.isEmpty then none
  else
    let f := s.toFloat!
    -- toFloat! returns 0 for unparseable; distinguish from actual "0"
    if f == 0.0 && s != "0" && s != "0.0" && s != "0.00" && s != ".0" && s != "0." then none
    else some f

private def floatParseRatio (col : Column) : Float :=
  let strs := col.data.filter fun c => match c with | .str _ => true | _ => false
  if strs.size == 0 then 0.0
  else
    let parsed := strs.foldl (init := 0) fun acc c =>
      match c with
      | .str s => match tryParseFloat s with | some _ => acc + 1 | none => acc
      | _ => acc
    parsed.toFloat / strs.size.toFloat

private def coerceToFloat (col : Column) : Column :=
  { col with data := col.data.map fun c =>
      match c with
      | .str s => match tryParseFloat s with | some f => .float f | none => .na
      | other => other }

private def trimStrings (col : Column) : Column :=
  { col with data := col.data.map fun c =>
      match c with | .str s => .str s.trim | other => other }

def autoClean (t : Table) : CleanResult :=
  let steps : Array CleaningStep := #[]
  -- 1. Drop 100% NA columns
  let (cols1, steps) := t.columns.foldl (init := (#[], steps)) fun (kept, st) col =>
    if isAllNa col then
      (kept, st.push { action := "drop", column := col.name, detail := "100% NA" })
    else (kept.push col, st)
  -- 2. Drop constant columns
  let (cols2, steps) := cols1.foldl (init := (#[], steps)) fun (kept, st) col =>
    if isConstant col then
      (kept, st.push { action := "drop", column := col.name, detail := "constant value" })
    else (kept.push col, st)
  -- 3. Coerce string→Float where >90% parse
  let (cols3, steps) := cols2.foldl (init := (#[], steps)) fun (kept, st) col =>
    if isStringCol col && floatParseRatio col > 0.9 then
      (kept.push (coerceToFloat col), st.push { action := "coerce", column := col.name, detail := "string→Float (>90% parseable)" })
    else (kept.push col, st)
  -- 4. Trim whitespace from string columns
  let (cols4, steps) := cols3.foldl (init := (#[], steps)) fun (kept, st) col =>
    if isStringCol col then
      (kept.push (trimStrings col), st.push { action := "trim", column := col.name, detail := "whitespace trimmed" })
    else (kept.push col, st)
  -- 5. Flag columns with >50% NA
  let steps := cols4.foldl (init := steps) fun st col =>
    if naRatio col > 0.5 then
      st.push { action := "warning", column := col.name, detail := ">50% NA" }
    else st
  { table := { columns := cols4 }, steps }

def CleanResult.renderLog (cr : CleanResult) : String :=
  cr.steps.foldl (init := "") fun acc step =>
    acc ++ s!"[{step.action}] {step.column}: {step.detail}\n"

end LeanTab
