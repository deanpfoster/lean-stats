import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

def renderCell : Cell → String
  | .float v => toString v
  | .str v => v
  | .na => ""

def renderCsv (t : Table) : String :=
  let header := ",".intercalate (t.colNames.toList)
  let rows := (List.range t.nRows).map fun i =>
    ",".intercalate ((t.row i).map renderCell).toList
  "\n".intercalate (header :: rows)

private def tryParseFloat (s : String) : Option Float :=
  let s := s.trim
  let (neg, s) := if s.startsWith "-" then (true, s.drop 1) else (false, s)
  let parts := s.splitOn "."
  match parts with
  | [intPart] =>
    match intPart.toNat? with
    | some n => some (if neg then -(n.toFloat) else n.toFloat)
    | none => none
  | [intPart, fracPart] =>
    if fracPart.isEmpty then none
    else match intPart.toNat?, fracPart.toNat? with
      | some i, some f =>
        let denom := (10 : Float) ^ fracPart.length.toFloat
        let v := i.toFloat + f.toFloat / denom
        some (if neg then -v else v)
      | _, _ => none
  | _ => none

def parseCell (s : String) : Cell :=
  if s == "" then .na
  else match tryParseFloat s with
    | some f => .float f
    | none => .str s

def parseCsv (s : String) : Table :=
  let lines := s.splitOn "\n" |>.filter (· != "")
  match lines with
  | [] => { columns := #[] }
  | header :: rest =>
    let names := header.splitOn ","
    let rows := rest.map fun line =>
      (line.splitOn ",").map parseCell |>.toArray
    Table.fromRows names.toArray rows.toArray

end LeanTab
