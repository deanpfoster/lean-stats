import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanTab.Sample

set_option autoImplicit false

namespace LeanTab.Manifests.Sample
open LeanTab

private def t : Table := Table.fromColumns #[
  ("a", #[.float 1, .float 2, .float 3, .float 4, .float 5]),
  ("b", #[.str "x", .str "y", .str "z", .str "w", .str "v"])
]

theorem slice_row_count_proof : (slice t 1 3).nRows = 2 := by native_decide

UnitTest slice_row_count : (slice t 1 3).nRows = 2

theorem slice_full_proof : (slice t 0 5).nRows = 5 := by native_decide

UnitTest slice_full : (slice t 0 5).nRows = 5

theorem sample_n_count_proof : (sampleN t 2).nRows = 2 := by native_decide

UnitTest sample_n_count : (sampleN t 2).nRows = 2

theorem slice_preserves_cols_proof : (slice t 1 3).nCols = t.nCols := by native_decide

UnitTest slice_preserves_cols : (slice t 1 3).nCols = t.nCols

end LeanTab.Manifests.Sample
