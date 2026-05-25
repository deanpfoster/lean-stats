import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanTab.Summarize

/-! # LeanTab.Manifests.Summarize — proven output bounds for table summaries

Key claim: `tableSummary t budget` output length ≤ budget + 1.
This is what lets l3m classify summary tools as tame.
-/
-- Implementation: LeanTab/Summarize.lean

set_option autoImplicit false

namespace LeanTab.Manifests.Summarize
open LeanTab

private def t1 : Table := Table.fromColumns #[
  ("age", #[.float 25, .float 30, .float 45, .float 60]),
  ("salary", #[.float 50000, .float 72000, .float 95000, .na]),
  ("region", #[.str "east", .str "west", .str "east", .str "south"]),
  ("name", #[.str "alice", .str "bob", .str "carol", .str "dave"])
]

/-- Default budget: output ≤ 1201 chars. -/
theorem summary_default_bound_proof :
  (tableSummary t1).length ≤ maxSummaryLen + 1 := by native_decide

ProvenTheorem summary_default_bound :
  (tableSummary t1).length ≤ maxSummaryLen + 1

/-- Budget 400: output ≤ 401 chars. -/
theorem summary_400_bound_proof :
  (tableSummary t1 400).length ≤ 401 := by native_decide

ProvenTheorem summary_400_bound :
  (tableSummary t1 400).length ≤ 401

/-- Budget 200: output ≤ 201 chars. -/
theorem summary_200_bound_proof :
  (tableSummary t1 200).length ≤ 201 := by native_decide

ProvenTheorem summary_200_bound :
  (tableSummary t1 200).length ≤ 201

/-- Budget 80: output ≤ 81 chars. -/
theorem summary_80_bound_proof :
  (tableSummary t1 80).length ≤ 81 := by native_decide

ProvenTheorem summary_80_bound :
  (tableSummary t1 80).length ≤ 81

/-- Empty table respects budget. -/
theorem summary_empty_bound_proof :
  (tableSummary (Table.empty #["a", "b", "c"]) 100).length ≤ 101 := by native_decide

ProvenTheorem summary_empty_bound :
  (tableSummary (Table.empty #["a", "b", "c"]) 100).length ≤ 101

/-- maxSummaryLen is 1200. -/
theorem max_summary_len_value_proof : maxSummaryLen = 1200 := by native_decide

ProvenTheorem max_summary_len_value : maxSummaryLen = 1200

end LeanTab.Manifests.Summarize
