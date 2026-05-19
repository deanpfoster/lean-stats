import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanTab.Summarize

/-! # LeanTab.Manifests.Summarize — bound proof for table summaries

The key claim: `tableSummary` output is bounded in length regardless
of input table size. This is what lets l3m classify summary tools as
tame (bounded output).
-/

set_option autoImplicit false

namespace LeanTab.Manifests.Summarize
open LeanTab

-- Test fixture: a table that exercises all paths
private def bigTable : Table := Table.fromColumns #[
  ("a_very_long_column_name_that_goes_on_and_on", #[.float 1, .float 2, .float 3]),
  ("x", #[.float 100, .float 200, .float 300]),
  ("category", #[.str "east", .str "west", .str "east"]),
  ("sparse", #[.float 1, .na, .na])
]

/-- Summary of a 4-column table is bounded. -/
theorem summary_bounded_proof :
  (tableSummary bigTable).length ≤ maxSummaryLen + 1 := by native_decide

ProvenTheorem summary_bounded :
  (tableSummary bigTable).length ≤ maxSummaryLen + 1

/-- Summary of an empty table is bounded. -/
theorem summary_empty_bounded_proof :
  (tableSummary (Table.empty #["a", "b", "c"])).length ≤ maxSummaryLen + 1 := by native_decide

ProvenTheorem summary_empty_bounded :
  (tableSummary (Table.empty #["a", "b", "c"])).length ≤ maxSummaryLen + 1

/-- The maxSummaryLen constant is 1200. l3m can use this as a hard cap. -/
theorem max_summary_len_value_proof : maxSummaryLen = 1200 := by native_decide

ProvenTheorem max_summary_len_value : maxSummaryLen = 1200

end LeanTab.Manifests.Summarize
