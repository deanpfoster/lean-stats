import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanTab.GroupBy

/-! # LeanTab.Manifests.MultiGroup — claims for multi-column groupBy -/

set_option autoImplicit false

namespace LeanTab.Manifests.MultiGroup
open LeanTab

private def t : Table := Table.fromColumns #[
  ("a", #[.str "x", .str "x", .str "y", .str "x"]),
  ("b", #[.str "1", .str "2", .str "1", .str "1"]),
  ("x", #[.float 1, .float 2, .float 3, .float 4])
]

/-- groupByMany on two columns produces 3 distinct composite keys. -/
theorem multi_group_keys_proof :
  (groupByMany t #["a", "b"]).keys.size = 3 := by native_decide

ProvenTheorem multi_group_keys :
  (groupByMany t #["a", "b"]).keys.size = 3

/-- groupByMany on one column produces 2 distinct keys. -/
theorem multi_group_single_proof :
  (groupByMany t #["a"]).keys.size = 2 := by native_decide

ProvenTheorem multi_group_single :
  (groupByMany t #["a"]).keys.size = 2

/-- Group sizes sum to total rows (4). -/
theorem group_counts_sum_proof :
  ((groupByMany t #["a", "b"]).groups.map (·.size)).foldl (· + ·) 0 = 4 := by native_decide

ProvenTheorem group_counts_sum :
  ((groupByMany t #["a", "b"]).groups.map (·.size)).foldl (· + ·) 0 = 4

end LeanTab.Manifests.MultiGroup
