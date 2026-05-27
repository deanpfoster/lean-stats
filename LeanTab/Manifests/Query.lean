import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanTab.Query

/-! # LeanTab.Manifests.Query — claims about LeanTab.runQuery

Proves that the query pipeline correctly handles no-filter, WHERE,
LIMIT, and bad-parse cases on a fixture table.
-/

set_option autoImplicit false

namespace LeanTab.Manifests.Query
open LeanTab

private def fixture : Table := Table.fromColumns #[
  ("x", #[.float 1, .float 2, .float 3, .float 4, .float 5]),
  ("y", #[.float 10, .float 20, .float 30, .float 40, .float 50])
]

private def isOk (r : Except String Table) : Bool := r.isOk
private def nRowsOk (r : Except String Table) (n : Nat) : Bool :=
  match r with
  | .ok t => t.nRows == n
  | .error _ => false
private def nRowsLt (r : Except String Table) (n : Nat) : Bool :=
  match r with
  | .ok t => t.nRows < n
  | .error _ => false
private def isErr (r : Except String Table) : Bool := !r.isOk

/-- No filters: returns .ok with same nRows -/
theorem query_nofilter_proof : nRowsOk (runQuery fixture {}) 5 = true := by native_decide

UnitTest query_nofilter : nRowsOk (runQuery fixture {}) 5 = true

/-- WHERE "x > 2": returns .ok with fewer rows -/
theorem query_where_proof : nRowsLt (runQuery fixture { where_ := some "x > 2" }) 5 = true := by native_decide

UnitTest query_where : nRowsLt (runQuery fixture { where_ := some "x > 2" }) 5 = true

/-- LIMIT 2: returns .ok with 2 rows -/
theorem query_limit_proof : nRowsOk (runQuery fixture { limit := some 2 }) 2 = true := by native_decide

UnitTest query_limit : nRowsOk (runQuery fixture { limit := some 2 }) 2 = true

/-- Bad WHERE parse (empty): returns .error -/
theorem query_bad_where_proof : isErr (runQuery fixture { where_ := some "" }) = true := by native_decide

UnitTest query_bad_where : isErr (runQuery fixture { where_ := some "" }) = true

end LeanTab.Manifests.Query
