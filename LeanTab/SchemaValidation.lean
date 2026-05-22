import LeanTab.Catalog
set_option autoImplicit false
namespace LeanTab

inductive SchemaIssue where
  | newColumn (name : String)
  | missingColumn (name : String)
  | typeChanged (name : String) (was now : String)
  | rowCountAnomaly (expected actual : Nat)
  | missingRateChanged (col : String) (was now : Float)
  deriving Repr

def validateAgainstCatalog (t : Table) (src : DataSource) : Array SchemaIssue :=
  let catalogCols := src.schema.map (·.name)
  let tableCols := t.columns.map (·.name)
  let newCols := tableCols.filter (!catalogCols.contains ·) |>.map SchemaIssue.newColumn
  let missingCols := catalogCols.filter (!tableCols.contains ·) |>.map SchemaIssue.missingColumn
  let typeIssues := src.schema.filterMap fun spec =>
    match t.columns.find? (·.name == spec.name) with
    | none => none
    | some col =>
      let nonNa := col.data.filter (· != .na)
      let typ := if nonNa.all (fun c => match c with | .float _ => true | _ => false) then "Float"
        else if nonNa.all (fun c => match c with | .str _ => true | _ => false) then "String"
        else "Mixed"
      if typ != spec.type && spec.type != "unknown" then some (.typeChanged spec.name spec.type typ)
      else none
  let missingIssues := src.schema.filterMap fun spec =>
    match spec.missing, t.columns.find? (·.name == spec.name) with
    | some was, some col =>
      let now := if col.data.isEmpty then 0.0
        else (col.data.filter (· == .na)).size.toFloat / col.data.size.toFloat
      if (now - was).abs > 0.05 then some (.missingRateChanged spec.name was now) else none
    | _, _ => none
  let rowIssue := match src.rowCount with
    | some expected =>
      let actual := t.nRows
      if actual < expected / 2 || actual > expected * 2 then #[.rowCountAnomaly expected actual] else #[]
    | none => #[]
  newCols ++ missingCols ++ typeIssues ++ missingIssues ++ rowIssue

def SchemaIssue.render : SchemaIssue → String
  | .newColumn name => s!"NEW column: {name}"
  | .missingColumn name => s!"MISSING column: {name}"
  | .typeChanged name was now => s!"TYPE changed: {name} was {was}, now {now}"
  | .rowCountAnomaly expected actual => s!"ROW COUNT anomaly: expected ~{expected}, got {actual}"
  | .missingRateChanged col was now => s!"MISSING RATE changed: {col} was {was}, now {now}"

def validationReport (issues : Array SchemaIssue) : String :=
  if issues.isEmpty then "✓ schema matches catalog"
  else String.intercalate "\n" (issues.toList.map SchemaIssue.render)

end LeanTab
