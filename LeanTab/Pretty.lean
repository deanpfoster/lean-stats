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

private def sparklineStr (vals : Array Float) : String :=
  if vals.isEmpty then "        "
  else
    let blocks := "▁▂▃▄▅▆▇█"
    let mn := vals.foldl min vals[0]!
    let mx := vals.foldl max vals[0]!
    -- bin into 8 bins
    let bins : Array Nat := Id.run do
      let mut b := Array.mkArray 8 0
      for v in vals do
        let idx := if mx == mn then 3
          else let raw := ((v - mn) / (mx - mn) * 7.99).toUInt32.toNat; min raw 7
        b := b.set! idx (b[idx]! + 1)
      pure b
    let maxBin := bins.foldl max 1
    let chars := bins.map fun cnt =>
      let level := if maxBin == 0 then 0 else (cnt * 7) / maxBin
      blocks.get ⟨level * 3⟩  -- UTF-8: each block char is 3 bytes
    String.mk chars.toList

private def columnSummary (col : Column) : String :=
  -- Check if column is numeric
  let floats := col.data.filterMap Cell.toFloat?
  if floats.size > col.data.size / 2 then
    sparklineStr floats
  else
    -- String column: count distinct values
    let strs := col.data.filterMap fun c => match c with | .str v => some v | _ => none
    let counts := strs.foldl (fun (m : List (String × Nat)) s =>
      match m.find? (·.1 == s) with
      | some _ => m.map fun (k, n) => if k == s then (k, n + 1) else (k, n)
      | none => m ++ [(s, 1)]) []
    let distinct := counts.length
    if distinct > 10 then s!"({distinct} distinct)"
    else
      let sorted := counts.toArray.qsort (·.2 > ·.2)
      " ".intercalate (sorted.toList.map fun (k, n) => s!"{k}({n})")

private def countNAs (t : Table) : Nat :=
  t.columns.foldl (fun acc c => acc + c.data.foldl (fun n cell =>
    match cell with | .na => n + 1 | _ => n) 0) 0

def prettyPrintEnhanced (t : Table) (maxRows : Nat := 20) : String :=
  let names := t.colNames.toList
  let nRows := min t.nRows maxRows
  let rows := (List.range nRows).map fun i => (t.row i).map renderCell |>.toList
  -- Column summaries (sparklines / value counts)
  let summaries := t.columns.toList.map columnSummary
  let widths := names.mapIdx fun j name =>
    let colW := rows.foldl (fun acc r => max acc ((r.get? j).getD "").length) name.length
    let sumW := (summaries.get? j).getD "" |>.length
    max colW sumW
  let pad (s : String) (w : Nat) : String := s ++ String.mk (List.replicate (w - s.length) ' ')
  let headerLine := " | ".intercalate (List.zipWith pad names widths)
  let summaryLine := " | ".intercalate (List.zipWith pad summaries widths)
  let sepLine := "-+-".intercalate (widths.map fun w => String.mk (List.replicate w '-'))
  let dataLines := rows.map fun r =>
    " | ".intercalate (List.zipWith pad r widths)
  let naCount := countNAs t
  let footer := s!"[{t.nRows} rows]" ++
    (if naCount > 0 then s!" ({naCount} NAs)" else "")
  "\n".intercalate (headerLine :: summaryLine :: sepLine :: dataLines ++ [sepLine, footer])

end LeanTab
