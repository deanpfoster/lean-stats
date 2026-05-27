import DeanLean.Basic
import LeanTab.Table
import LeanTab.Csv
import LeanTab.Pretty
import LeanStats.Manifests.Util

set_option autoImplicit false

namespace LeanTab.Manifests.IO
open LeanTab
open LeanStats.Manifests (String.containsSubstr)

private def t2x2 : Table := Table.fromRows #["a", "b"] #[
  #[.float 1, .str "x"],
  #[.float 2, .str "y"]
]

/-- renderCsv on a 2x2 table contains a newline. -/
theorem render_has_newline_proof :
  String.containsSubstr (renderCsv t2x2) "\n" = true := by native_decide

UnitTest render_has_newline :
  String.containsSubstr (renderCsv t2x2) "\n" = true

/-- parseCsv of a simple CSV has correct nRows. -/
theorem parse_nrows_proof :
  (parseCsv "a,b\n1,2\n3,4").nRows = 2 := by native_decide

UnitTest parse_nrows :
  (parseCsv "a,b\n1,2\n3,4").nRows = 2

/-- parseCsv of a simple CSV has correct nCols. -/
theorem parse_ncols_proof :
  (parseCsv "a,b\n1,2\n3,4").nCols = 2 := by native_decide

UnitTest parse_ncols :
  (parseCsv "a,b\n1,2\n3,4").nCols = 2

/-- prettyPrint output is non-empty. -/
theorem pretty_nonempty_proof :
  ((prettyPrint t2x2).length > 0) = true := by native_decide

UnitTest pretty_nonempty :
  ((prettyPrint t2x2).length > 0) = true

end LeanTab.Manifests.IO
