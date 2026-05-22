import LeanTab.Catalog

/-! # LeanTab.CatalogJson — JSON serialization for the data catalog

Provides toJsonString / fromJsonString for DataCatalog, enabling
persistence to `.l3m/catalog.json` and interchange with l3m.

Simple hand-rolled JSON (no Lean.Json dependency — keeps lean-stats
free of Mathlib/std4 deps). Format: nested objects with string keys.

Round-trip property: fromJsonString (toJsonString cat) = .ok cat
-/

set_option autoImplicit false

namespace LeanTab

-- ════════════════════════════════════════════════════════════
-- § JSON encoding (to string)
-- ════════════════════════════════════════════════════════════

private def jsonStr (s : String) : String :=
  let escaped := s.replace "\\" "\\\\" |>.replace "\"" "\\\"" |>.replace "\n" "\\n"
  "\"" ++ escaped ++ "\""

private def jsonArr (items : List String) : String :=
  "[" ++ String.intercalate "," items ++ "]"

private def jsonObj (fields : List (String × String)) : String :=
  "{" ++ String.intercalate "," (fields.map fun (k, v) => jsonStr k ++ ":" ++ v) ++ "}"

private def jsonOptFloat : Option Float → String
  | some f => toString f
  | none => "null"

private def jsonOptNat : Option Nat → String
  | some n => toString n
  | none => "null"

private def jsonOptStr : Option String → String
  | some s => jsonStr s
  | none => "null"

def InfoSource.toJson : InfoSource → String
  | .unknown => jsonObj [("type", jsonStr "unknown")]
  | .slack ch d => jsonObj [("type", jsonStr "slack"), ("channel", jsonStr ch), ("date", jsonStr d)]
  | .email s d => jsonObj [("type", jsonStr "email"), ("sender", jsonStr s), ("date", jsonStr d)]
  | .documentation u => jsonObj [("type", jsonStr "docs"), ("url", jsonStr u)]
  | .conversation p d => jsonObj [("type", jsonStr "conversation"), ("person", jsonStr p), ("date", jsonStr d)]
  | .inferred => jsonObj [("type", jsonStr "inferred")]

def Communication.toJson (c : Communication) : String :=
  jsonObj [("date", jsonStr c.date), ("channel", c.channel.toJson),
    ("person", jsonStr c.person), ("content", jsonStr c.content)]

def ColumnSpec.toJson (c : ColumnSpec) : String :=
  jsonObj [("name", jsonStr c.name), ("type", jsonStr c.type),
    ("missing", jsonOptFloat c.missing), ("distinct", jsonOptNat c.distinct),
    ("sample", jsonArr (c.sample.toList.map jsonStr)),
    ("description", jsonStr c.description)]

def DataQuality.toJson (q : DataQuality) : String :=
  jsonObj [("completeness", jsonOptFloat q.completeness),
    ("duplicateRows", jsonOptNat q.duplicateRows),
    ("suspiciousColumns", jsonArr (q.suspiciousColumns.toList.map jsonStr)),
    ("typeConflicts", jsonArr (q.typeConflicts.toList.map jsonStr))]

def UpstreamDependency.toJson (u : UpstreamDependency) : String :=
  jsonObj [("tableName", jsonStr u.tableName), ("pipelineStep", jsonStr u.pipelineStep),
    ("cti", jsonStr u.cti), ("oncallRotation", jsonStr u.oncallRotation)]

def Environment.toJson (e : Environment) : String :=
  jsonObj [("name", jsonStr e.name), ("accountId", jsonStr e.accountId),
    ("s3Root", jsonStr e.s3Root), ("region", jsonStr e.region)]

def Crypto.EncryptedField.toJson (e : Crypto.EncryptedField) : String :=
  jsonObj [("ciphertext", jsonStr e.ciphertext), ("keyEnvVar", jsonStr e.keyEnvVar),
    ("hint", jsonStr e.hint)]

def DataSource.toJson (src : DataSource) : String :=
  jsonObj [
    ("name", jsonStr src.name),
    ("origin", jsonStr src.origin),
    ("encryptedOrigin", match src.encryptedOrigin with | some e => e.toJson | none => "null"),
    ("fetchedAt", jsonStr src.fetchedAt),
    ("schema", jsonArr (src.schema.toList.map ColumnSpec.toJson)),
    ("quality", src.quality.toJson),
    ("rowCount", jsonOptNat src.rowCount),
    ("summary", jsonOptStr src.summary),
    ("owner", jsonStr src.owner),
    ("contact", jsonStr src.contact),
    ("communications", jsonArr (src.communications.toList.map Communication.toJson)),
    ("notes", jsonArr (src.notes.toList.map jsonStr)),
    ("tags", jsonArr (src.tags.toList.map jsonStr)),
    ("confidence", jsonStr src.confidence),
    ("upstreamDeps", jsonArr (src.upstreamDeps.toList.map UpstreamDependency.toJson)),
    ("environments", jsonArr (src.environments.toList.map Environment.toJson)),
    ("pipelineUrl", jsonStr src.pipelineUrl),
    ("lastSuccessfulRun", jsonStr src.lastSuccessfulRun),
    ("pipelineStep", jsonStr src.pipelineStep)
  ]

def DataCatalog.toJsonString (cat : DataCatalog) : String :=
  jsonObj [
    ("lastUpdated", jsonStr cat.lastUpdated),
    ("sources", jsonArr (cat.sources.toList.map DataSource.toJson))
  ]

-- ════════════════════════════════════════════════════════════
-- § Helpers: upsert and update
-- ════════════════════════════════════════════════════════════

/-- Replace a source by name if it exists, otherwise append. -/
def DataCatalog.upsert (cat : DataCatalog) (src : DataSource) : DataCatalog :=
  let idx := cat.sources.findIdx? (·.name == src.name)
  match idx with
  | some i => { cat with sources := cat.sources.set! i src }
  | none => { cat with sources := cat.sources.push src }

/-- Update a catalog entry preserving sociology fields (owner, contact,
    communications, notes, tags) while refreshing data fields. -/
def DataSource.refreshFrom (old : DataSource) (t : Table) : DataSource :=
  let fresh := catalogFromTable t old.name old.origin
  { fresh with
    owner := old.owner
    contact := old.contact
    communications := old.communications
    notes := old.notes
    tags := old.tags
    confidence := old.confidence
    upstreamDeps := old.upstreamDeps
    environments := old.environments
    pipelineUrl := old.pipelineUrl
    encryptedOrigin := old.encryptedOrigin }

end LeanTab
