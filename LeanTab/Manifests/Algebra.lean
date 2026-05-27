import DeanLean.Basic
import LeanTab.Verbs
import LeanTab.Table

/-! # Relational Algebra Properties

Universal theorems about table operations. These catch real bugs:
if filter ever duplicates rows, or select drops structure, or
mutate changes row count, the build breaks.
-/

namespace LeanTab.Manifest.Algebra
open LeanTab

-- ════════════════════════════════════════════════════════════
-- § Filter properties
-- ════════════════════════════════════════════════════════════

/-- Filter never changes the number of columns. If this fails,
    filter is corrupting table structure. -/
theorem filter_preserves_ncols_proof (t : Table) (p : Array Cell → Bool) :
    (filter t p).columns.size = t.columns.size := by
  simp [filter]

ProvenTheorem filter_preserves_ncols :
    ∀ (t : Table) (p : Array Cell → Bool),
    (filter t p).columns.size = t.columns.size

/-- Filter with always-false still preserves column structure. -/
theorem filter_false_preserves_structure_proof (t : Table) :
    (filter t (fun _ => false)).columns.size = t.columns.size := by
  simp [filter]

ProvenTheorem filter_false_preserves_structure :
    ∀ (t : Table),
    (filter t (fun _ => false)).columns.size = t.columns.size

/-- nCols is invariant under filter. -/
theorem filter_ncols_invariant_proof (t : Table) (p : Array Cell → Bool) :
    Table.nCols (filter t p) = Table.nCols t := by
  simp [Table.nCols, filter]

ProvenTheorem filter_ncols_invariant :
    ∀ (t : Table) (p : Array Cell → Bool),
    Table.nCols (filter t p) = Table.nCols t

-- ════════════════════════════════════════════════════════════
-- § Select properties
-- ════════════════════════════════════════════════════════════

/-- Selecting no columns gives an empty table. -/
theorem select_empty_proof (t : Table) :
    (select t #[]).columns = #[] := by
  simp [select]

ProvenTheorem select_empty :
    ∀ (t : Table), (select t #[]).columns = #[]

-- ════════════════════════════════════════════════════════════
-- § Conjectured (meaningful but not yet proven universally)
-- ════════════════════════════════════════════════════════════

/-- Filter can't grow the table. Falsifying observation: filter
    duplicates a row, producing more output than input. -/
UnprovenConjecture filter_nrows_le :
    ∀ (t : Table) (p : Array Cell → Bool),
    (filter t p).nRows ≤ t.nRows

/-- Filter fusion: two consecutive filters equal one filter with
    conjunction. Falsifying observation: the optimizer rewrites
    filter(filter(t,p),q) to filter(t, p∧q) and gets different
    results. -/
UnprovenConjecture filter_fusion :
    ∀ (t : Table) (p q : Array Cell → Bool),
    filter (filter t p) q = filter t (fun r => p r && q r)

/-- Select-all is identity. Falsifying observation: selecting
    every column reorders or drops data. -/
UnprovenConjecture select_all_identity :
    ∀ (t : Table), select t (Table.colNames t) = t

end LeanTab.Manifest.Algebra
