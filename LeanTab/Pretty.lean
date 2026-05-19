import LeanTab.Table
import LeanTab.Csv

set_option autoImplicit false

namespace LeanTab

def prettyPrint (t : Table) (maxRows : Nat := 20) : String :=
  let names := t.colNames.toList
  let nRows := min t.nRows maxRows
  let rows := (List.range nRows).map fun i => (t.row i).map renderCell |>.toList
  let widths := names.mapIdx fun j name =>
    let colW := rows.foldl (fun acc r => max acc ((r.get? j).getD "").length) name.length
    colW
  let pad (s : String) (w : Nat) : String := s ++ String.mk (List.replicate (w - s.length) ' ')
  let headerLine := " | ".intercalate (List.zipWith pad names widths)
  let sepLine := "-+-".intercalate (widths.map fun w => String.mk (List.replicate w '-'))
  let dataLines := rows.map fun r =>
    " | ".intercalate (List.zipWith pad r widths)
  "\n".intercalate (headerLine :: sepLine :: dataLines)

end LeanTab
