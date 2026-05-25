import LeanTab.CatalogJson

/-! # LeanTab.CatalogMerge — merge catalogs with provenance and secret tracking

When merging two catalogs (yours + Bob's), we need to:
1. Combine knowledge (Bob knows about tables you don't)
2. Resolve conflicts (both have an entry for the same table)
3. Track provenance (where did each piece of knowledge come from?)
4. Handle secrets correctly (Bob's passwords stay with Bob)

The rule: secrets never travel. If Bob's catalog has a connection
string you don't have, the merged entry gets a note:
"Bob knows the password" — not the password itself.
-/

set_option autoImplicit false

namespace LeanTab

/-- Who contributed a catalog entry during a merge. -/
structure MergeSource where
  person : String        -- "Bob", "Alice", "production-catalog"
  date : String := ""    -- when the merge happened
  deriving Repr

/-- Result of merging one entry: what happened and why. -/
inductive MergeAction where
  /-- Entry only existed in one catalog — taken as-is. -/
  | added (source : String)
  /-- Both had it; kept the one with higher validation status. -/
  | keptBetter (source : String) (reason : String)
  /-- Both had it; merged fields from both. -/
  | merged (fields : Array String)
  deriving Repr

/-- Result of a full catalog merge. -/
structure MergeResult where
  catalog : DataCatalog
  actions : Array (String × MergeAction)  -- (source name, what happened)
  secretNotes : Array String              -- "Bob knows the password for X"
  deriving Repr

/-- Merge two catalogs. `mine` is the local catalog, `theirs` comes from `theirName`.
    Secrets from theirs are NOT copied — instead a note is added. -/
def DataCatalog.mergeFrom (mine theirs : DataCatalog) (theirName : String)
    (mergeDate : String := "unknown") : MergeResult := Id.run do
  let mut result := mine
  let mut actions : Array (String × MergeAction) := #[]
  let mut secretNotes : Array String := #[]

  for src in theirs.sources do
    match mine.sources.find? (·.name == src.name) with
    | none =>
      -- New entry from theirs — add it (without secrets)
      let cleaned := { src with
        encryptedOrigin := none
        communications := src.communications.push {
          date := mergeDate
          channel := .conversation theirName mergeDate
          person := theirName
          content := s!"Entry merged from {theirName}'s catalog"
        }
      }
      result := { result with sources := result.sources.push cleaned }
      actions := actions.push (src.name, .added theirName)
      -- Note if they had a secret we don't have
      if src.encryptedOrigin.isSome then
        secretNotes := secretNotes.push s!"{theirName} knows the password for '{src.name}'"

    | some existing =>
      -- Both have it — merge intelligently
      let theirBetter := match src.validation, existing.validation with
        | .validated, .unverified => true
        | .validated, .drifted => true
        | .drifted, .unverified => true
        | _, _ => false

      if theirBetter then
        -- Take theirs (better validation) but keep our secrets and merge comms
        let merged := { src with
          encryptedOrigin := existing.encryptedOrigin  -- keep OUR secret
          communications := existing.communications ++ src.communications
          notes := existing.notes ++ src.notes.filter (fun n => !existing.notes.contains n)
          tags := existing.tags ++ src.tags.filter (fun t => !existing.tags.contains t)
        }
        let merged := { merged with communications := merged.communications.push {
          date := mergeDate
          channel := .conversation theirName mergeDate
          person := theirName
          content := s!"Upgraded from {theirName}'s catalog (better validation: {reprValidation src.validation})"
        }}
        result := result.upsert merged
        actions := actions.push (src.name, .keptBetter theirName s!"{reprValidation src.validation} > {reprValidation existing.validation}")
      else
        -- Keep ours but merge their communications/notes/tags
        let merged := { existing with
          communications := existing.communications ++ src.communications
          notes := existing.notes ++ src.notes.filter (fun n => !existing.notes.contains n)
          tags := existing.tags ++ src.tags.filter (fun t => !existing.tags.contains t)
        }
        result := result.upsert merged
        actions := actions.push (src.name, .merged #["communications", "notes", "tags"])

      -- Note if they have a secret we don't
      if src.encryptedOrigin.isSome && existing.encryptedOrigin.isNone then
        secretNotes := secretNotes.push s!"{theirName} knows the password for '{src.name}'"

  return { catalog := result, actions, secretNotes }
where
  reprValidation : ValidationStatus → String
    | .validated => "validated"
    | .drifted => "drifted"
    | .unverified => "unverified"

/-- Render merge results as human-readable text. -/
def MergeResult.render (mr : MergeResult) : String :=
  let header := s!"Merged: {mr.actions.size} entries processed\n"
  let actionLines := mr.actions.toList.map fun (name, action) =>
    match action with
    | .added source => s!"  + {name} (new, from {source})"
    | .keptBetter source reason => s!"  ↑ {name} (upgraded from {source}: {reason})"
    | .merged fields => s!"  ∪ {name} (merged {fields})"
  let secretLines := if mr.secretNotes.isEmpty then []
    else ["", "Secrets (not copied):"] ++ mr.secretNotes.toList.map (s!"  🔑 " ++ ·)
  header ++ String.intercalate "\n" (actionLines ++ secretLines)

end LeanTab
