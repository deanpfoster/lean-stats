import LeanTab.Table
import LeanTab.Summarize
import LeanTab.Crypto

/-! # LeanTab.Catalog — data source registry with provenance and sociology

The hard part of data work isn't SQL. It's finding the right table,
knowing who owns it, whether it's trustworthy, and who to ask when
it breaks. This module tracks all of that.

Every field supports "unknown" because most of this information is
scraped from Slack channels, half-remembered conversations, and
tribal knowledge.
-/

set_option autoImplicit false

namespace LeanTab

/-- How we learned about something. -/
inductive InfoSource where
  | unknown
  | slack (channel : String) (date : String)
  | email (sender : String) (date : String)
  | documentation (url : String)
  | conversation (person : String) (date : String)
  | inferred  -- we figured it out from the data itself
  deriving Repr

/-- A communication record — who said what about this data. -/
structure Communication where
  date : String := "unknown"
  channel : InfoSource := .unknown
  person : String := "unknown"
  content : String
  deriving Repr

/-- Column-level metadata. -/
structure ColumnSpec where
  name : String
  type : String := "unknown"  -- "Float", "String", "Date", "Boolean", "unknown"
  missing : Option Float := none  -- fraction missing (0.0 to 1.0)
  distinct : Option Nat := none
  sample : Array String := #[]  -- first few values
  description : String := "unknown"
  deriving Repr

/-- Data quality assessment (computed from the actual data). -/
structure DataQuality where
  completeness : Option Float := none  -- fraction of cells that aren't NA
  duplicateRows : Option Nat := none
  suspiciousColumns : Array String := #[]  -- columns that look wrong
  typeConflicts : Array String := #[]  -- "column 'age' has strings in numeric"
  staleness : String := "unknown"  -- "fresh", "1 week old", "unknown"
  outlierColumns : Array String := #[]
  highCardinality : Array String := #[]
  lowCardinality : Array String := #[]
  nDuplicateRows : Option Nat := none
  deriving Repr

/-- How much we trust this catalog entry. -/
inductive ValidationStatus where
  /-- Hearsay. No fetch has confirmed any field. -/
  | unverified
  /-- A fetch succeeded but found schema drift from what was recorded. -/
  | drifted
  /-- A fetch succeeded and schema matched (or entry was just recorded from a fetch). -/
  | validated
  deriving Repr, BEq, Inhabited

/-- An upstream table dependency (who feeds this table). -/
structure UpstreamDependency where
  tableName : String             -- "unified_inventory_costs"
  pipelineStep : String := "unknown"  -- "InventoryWaitOn"
  cti : String := "unknown"      -- ticket system path for issues
  oncallRotation : String := "unknown"  -- "avengersde", "aft-bi"
  deriving Repr

/-- Where a table lives in a specific environment. -/
structure Environment where
  name : String                  -- "test", "preprod", "prod"
  accountId : String := "unknown"
  s3Root : String := "unknown"   -- "s3://scot-rl-prod-na-2-0/us/placement"
  region : String := "us-east-1"
  deriving Repr

/-- A data source in the catalog. -/
structure DataSource where
  /-- Human-readable name for this dataset. -/
  name : String
  /-- Where it lives (connection string, S3 path, file path, API endpoint). -/
  origin : String := "unknown"
  encryptedOrigin : Option Crypto.EncryptedField := none
  /-- When we last fetched/validated it. -/
  fetchedAt : String := "unknown"
  /-- Schema: what columns exist. -/
  schema : Array ColumnSpec := #[]
  /-- Quality assessment. -/
  quality : DataQuality := {}
  /-- Row count (if known). -/
  rowCount : Option Nat := none
  /-- Our budget-aware summary (if we've seen the data). -/
  summary : Option String := none

  -- The sociology fields:

  /-- Who officially owns this table/dataset. -/
  owner : String := "unknown"
  /-- Who to contact when something is wrong. -/
  contact : String := "unknown"
  /-- How we know about this data — the trail of breadcrumbs. -/
  communications : Array Communication := #[]

  /-- Free-form notes (accumulated over time). -/
  notes : Array String := #[]
  /-- Tags for search. -/
  tags : Array String := #[]
  /-- Confidence: how much do we trust this entry? -/
  confidence : String := "low"  -- "high", "medium", "low", "unknown"
  /-- Validation status: unverified (hearsay), drifted, or validated. -/
  validation : ValidationStatus := .unverified
  /-- If this entry was derived from/corrected from another, name the parent. -/
  derivedFrom : Option String := none

  -- Pipeline/infrastructure fields (Amazon-style):

  /-- Upstream tables this depends on (the dependency graph). -/
  upstreamDeps : Array UpstreamDependency := #[]
  /-- Where this table lives in each environment (test/preprod/prod). -/
  environments : Array Environment := #[]
  /-- URL to the pipeline definition (Step Functions, Airflow, etc.). -/
  pipelineUrl : String := "unknown"
  /-- When the pipeline last completed successfully. -/
  lastSuccessfulRun : String := "unknown"
  /-- The pipeline step that produces this table. -/
  pipelineStep : String := "unknown"
  deriving Repr

def DataSource.getOrigin (src : DataSource) (key : Option String := none) : String :=
  match src.encryptedOrigin, key with
  | some enc, some k => match Crypto.decryptCatalogField k enc with
    | .ok s => s
    | .error _ => "[decryption failed]"
  | _, _ => src.origin

def DataSource.setEncryptedOrigin (src : DataSource) (key : String) (connStr : String) (hint : String := "") : DataSource :=
  { src with encryptedOrigin := some (Crypto.encryptForCatalog key connStr hint) }

/-- The catalog: all known data sources. -/
structure DataCatalog where
  sources : Array DataSource := #[]
  lastUpdated : String := "unknown"
  deriving Repr

-- ════════════════════════════════════════════════════════════
-- § Building catalog entries from actual data
-- ════════════════════════════════════════════════════════════

/-- Assess data quality. -/
def assessQuality (t : Table) : DataQuality :=
  let totalCells := t.nRows * t.nCols
  let naMask := t.columns.foldl (fun acc col =>
    acc + (col.data.filter (· == .na)).size) 0
  let completeness := if totalCells == 0 then 1.0
    else 1.0 - naMask.toFloat / totalCells.toFloat
  let suspicious := t.columns.filterMap fun col =>
    let nonNa := col.data.filter (· != .na)
    if nonNa.isEmpty then some s!"{col.name}: all NA"
    else if nonNa.all (· == nonNa[0]!) then some s!"{col.name}: constant value"
    else none
  { completeness := some completeness,
    suspiciousColumns := suspicious.map id }

/-- Enhanced quality assessment with outlier, cardinality, and duplicate detection. -/
def assessQualityFull (t : Table) : DataQuality :=
  let base := assessQuality t
  -- Type conflicts: columns where >5% of non-NA values don't match majority type
  let typeConflicts := t.columns.filterMap fun col =>
    let nonNa := col.data.filter (· != .na)
    if nonNa.isEmpty then none
    else
      let nFloat := nonNa.filter (fun c => match c with | .float _ => true | _ => false) |>.size
      let nStr := nonNa.filter (fun c => match c with | .str _ => true | _ => false) |>.size
      let n := nonNa.size.toFloat
      let minority := if nFloat.toFloat < nStr.toFloat then nFloat.toFloat else nStr.toFloat
      if minority / n > 0.05 then some s!"{col.name}: {minority.toUInt64}/{nonNa.size} values conflict"
      else none
  -- High cardinality: string columns with distinct/n > 0.9
  let highCard := t.columns.filterMap fun col =>
    let nonNa := col.data.filter (· != .na)
    let isStr := nonNa.all (fun c => match c with | .str _ => true | _ => false)
    if !isStr || nonNa.isEmpty then none
    else
      let distinct := nonNa.foldl (init := #[]) fun acc c =>
        if acc.contains c then acc else acc.push c
      if distinct.size.toFloat / nonNa.size.toFloat > 0.9 then some col.name
      else none
  -- Low cardinality: numeric columns with < 5 distinct values
  let lowCard := t.columns.filterMap fun col =>
    let nonNa := col.data.filter (· != .na)
    let isNum := nonNa.all (fun c => match c with | .float _ => true | _ => false)
    if !isNum || nonNa.isEmpty then none
    else
      let distinct := nonNa.foldl (init := #[]) fun acc c =>
        if acc.contains c then acc else acc.push c
      if distinct.size < 5 then some col.name
      else none
  -- Outliers: numeric columns where any value > 4 SD from mean
  let outliers := t.columns.filterMap fun col =>
    let nonNa := col.data.filter (· != .na)
    let floats := nonNa.filterMap Cell.toFloat?
    if floats.size < 2 then none
    else
      let n := floats.size.toFloat
      let mu := floats.foldl (· + ·) 0.0 / n
      let variance := floats.foldl (fun acc x => acc + (x - mu) * (x - mu)) 0.0 / n
      let sd := Float.sqrt variance
      if sd == 0.0 then none
      else if floats.any (fun x => Float.abs (x - mu) > 4.0 * sd) then some col.name
      else none
  -- Duplicate rows
  let nDups := if t.nRows == 0 then 0
    else
      let rows := (List.range t.nRows).toArray.map t.row
      let unique := rows.foldl (init := #[]) fun acc r =>
        if acc.contains r then acc else acc.push r
      t.nRows - unique.size
  { base with
    typeConflicts := base.typeConflicts ++ typeConflicts,
    outlierColumns := outliers,
    highCardinality := highCard,
    lowCardinality := lowCard,
    nDuplicateRows := some nDups }

/-- Human-readable quality report. -/
def qualityReport (q : DataQuality) : String :=
  let lines : Array String := #[]
  let lines := match q.completeness with
    | some c => lines.push s!"Completeness: {(c * 100).toUInt64}%"
    | none => lines
  let lines := match q.nDuplicateRows with
    | some n => if n > 0 then lines.push s!"Duplicate rows: {n}" else lines
    | none => lines
  let lines := if q.typeConflicts.isEmpty then lines
    else lines.push s!"Type conflicts: {String.intercalate ", " q.typeConflicts.toList}"
  let lines := if q.outlierColumns.isEmpty then lines
    else lines.push s!"Outlier columns (>4 SD): {String.intercalate ", " q.outlierColumns.toList}"
  let lines := if q.highCardinality.isEmpty then lines
    else lines.push s!"High cardinality (likely IDs): {String.intercalate ", " q.highCardinality.toList}"
  let lines := if q.lowCardinality.isEmpty then lines
    else lines.push s!"Low cardinality (likely categorical): {String.intercalate ", " q.lowCardinality.toList}"
  let lines := if q.suspiciousColumns.isEmpty then lines
    else lines.push s!"Suspicious: {String.intercalate ", " q.suspiciousColumns.toList}"
  if lines.isEmpty then "No quality issues detected."
  else String.intercalate "\n" lines.toList

/-- Build a catalog entry from a fetched table. Pure — just analyzes what we have. -/
def catalogFromTable (t : Table) (name : String) (origin : String := "unknown") : DataSource :=
  let schema := t.columns.map fun col =>
    let data := col.data
    let nMissing := data.filter (· == .na) |>.size
    let missingFrac := if data.isEmpty then 0.0 else nMissing.toFloat / data.size.toFloat
    let nonNa := data.filter (· != .na)
    let typ := if nonNa.all (fun c => match c with | .float _ => true | _ => false) then "Float"
      else if nonNa.all (fun c => match c with | .str _ => true | _ => false) then "String"
      else "Mixed"
    let distinct : Array String := nonNa.foldl (init := #[]) fun acc c =>
      let s := c.toStr; if acc.contains s then acc else acc.push s
    let sample := (nonNa.extract 0 (Nat.min 5 nonNa.size)).map Cell.toStr
    { name := col.name, type := typ, missing := some missingFrac,
      distinct := some distinct.size, sample, description := "unknown" : ColumnSpec }
  let quality := assessQuality t
  let summary := tableSummary t
  { name, origin, schema, quality, rowCount := some t.nRows, summary := some summary,
    validation := .validated }

-- ════════════════════════════════════════════════════════════
-- § Searching and querying the catalog
-- ════════════════════════════════════════════════════════════

/-- Search catalog by keyword (matches name, tags, notes, owner, column names). -/
def DataCatalog.search (cat : DataCatalog) (keyword : String) : Array DataSource :=
  let kw := keyword.toLower
  let has (s : String) : Bool := (s.toLower.splitOn kw).length > 1
  cat.sources.filter fun src =>
    has src.name ||
    has src.owner ||
    src.tags.any has ||
    src.notes.any has ||
    src.schema.any (fun c => has c.name)

/-- Find tables that might join with a given table (shared column names). -/
def DataCatalog.findJoinCandidates (cat : DataCatalog) (src : DataSource) : Array (String × Array String) :=
  let srcCols := src.schema.map (·.name)
  cat.sources.filterMap fun other =>
    if other.name == src.name then none
    else
      let shared := srcCols.filter fun col =>
        other.schema.any (·.name == col)
      if shared.isEmpty then none
      else some (other.name, shared)

/-- Render a catalog entry for the LLM (the "two-eyed" symbolic view). -/
def DataSource.renderForLLM (src : DataSource) (budget : Nat := 400) : String :=
  let header := s!"{src.name} ({src.rowCount.getD 0} rows, {src.schema.size} cols)"
  let owner := if src.owner != "unknown" then s!"\nowner: {src.owner}" else ""
  let contact := if src.contact != "unknown" then s!", contact: {src.contact}" else ""
  let confidence := s!"\nconfidence: {src.confidence}"
  let cols := if budget > 200 then
    "\ncols: " ++ String.intercalate ", " (src.schema.toList.map fun c =>
      s!"{c.name}:{c.type}" ++ (match c.missing with | some m => if m > 0.05 then s!"({(m*100).toUInt64}%NA)" else "" | none => ""))
    else ""
  let notes := if src.notes.isEmpty then "" else
    "\nnotes: " ++ (src.notes.getD 0 "")
  let comms := if src.communications.isEmpty then "" else
    let last := src.communications.getD (src.communications.size - 1) { content := "" }
    s!"\nlast heard: {last.person} ({last.date}): {last.content.take 60}"
  let result := header ++ owner ++ contact ++ confidence ++ cols ++ notes ++ comms
  if result.length > budget then result.take budget ++ "…" else result

/-- Render the full catalog as a summary for the LLM. -/
def DataCatalog.renderForLLM (cat : DataCatalog) (budget : Nat := 1200) : String :=
  let perSource := budget / (Nat.max 1 cat.sources.size)
  let entries := cat.sources.toList.map (·.renderForLLM perSource)
  String.intercalate "\n---\n" entries

end LeanTab
