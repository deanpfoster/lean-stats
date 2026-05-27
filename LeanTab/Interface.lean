import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanTab.Join
import LeanTab.Window
import LeanTab.Missing
import LeanTab.StringOps
import LeanTab.Csv
import LeanTab.Pretty
import LeanTab.Sample
import LeanTab.Sql.Eval
import LeanTab.Manifest
import LeanTab.Sql.Manifest

/-! # LeanTab.Interface — the manifest l3m reads to know what table ops it can call

Minimal trust surface for an agent wrapping LeanTab as tools.

## Tool categories

1. **Ingest**: parseCsv
2. **Inspect**: prettyPrint, nRows, nCols, colNames
3. **Transform**: filter, select, mutate, arrange, rename, distinct
4. **Reshape**: pivotLonger, pivotWider, innerJoin, leftJoin
5. **Aggregate**: groupBy, summarize, count
6. **Sample**: head, tail, slice, sampleN
7. **Clean**: dropNa, fillForward, replaceNa
8. **Query**: SQL eval
9. **Output**: renderCsv, prettyPrint
-/

set_option autoImplicit false

namespace LeanTab.Interface
open LeanTab

-- ════════════════════════════════════════════════════════════
-- § Signatures: type-checked function contracts
-- ════════════════════════════════════════════════════════════

-- Ingest / Output
Signature parseCsv : String → Table
Signature renderCsv : Table → String
Signature prettyPrint : Table → optParam Nat 20 → String

-- Core verbs
Signature filter : Table → (Array Cell → Bool) → Table
Signature select : Table → Array String → Table
Signature mutate : Table → String → (Array Cell → Cell) → Table
Signature arrange : Table → String → Table
Signature rename : Table → String → String → Table
Signature head : Table → optParam Nat 6 → Table
Signature tail : Table → optParam Nat 6 → Table
Signature distinct : Table → String → Table
Signature slice : Table → Nat → Nat → Table
Signature sampleN : Table → Nat → optParam Nat 42 → Table

-- Joins
Signature innerJoin : Table → Table → String → Table
Signature leftJoin : Table → Table → String → Table
Signature crossJoin : Table → Table → Table

-- Reshape
Signature pivotLonger : Table → Array String → optParam String "name" → optParam String "value" → Table
Signature pivotWider : Table → String → String → Table

-- Aggregate
Signature groupBy : Table → String → Grouped
Signature count : Table → String → Table

-- Missing data
Signature dropNa : Table → String → Table
Signature replaceNa : Table → String → Cell → Table

-- SQL
Signature Sql.eval : Sql.Query → Sql.Database → Option Table

-- ════════════════════════════════════════════════════════════
-- § Trust chain: restated from sub-manifests (transitive search)
-- ════════════════════════════════════════════════════════════

Restate filter_cols
Restate filter_none
Restate select_cols from LeanTab.Manifest
Restate mutate_adds
Restate arrange_dims
Restate pivot_longer_rows
Restate select_star_rows
Restate where_reduces
Restate unknown_table

/-- No IO, no mutation. Every function returns a new Table. -/
Sketch pure_no_mutation

end LeanTab.Interface
