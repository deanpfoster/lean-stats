import LeanTab.Table
import LeanTab.Summarize

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
  deriving Repr

/-- A data source in the catalog. -/
structure DataSource where
  /-- Human-readable name for this dataset. -/
  name : String
  /-- Where it lives (connection string, S3 path, file path, API endpoint). -/
  origin : String := "unknown"
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
  deriving Repr

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
  { name, origin, schema, quality, rowCount := some t.nRows, summary := some summary }

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
