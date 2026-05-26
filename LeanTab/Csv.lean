import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

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

/-- RFC 4180 CSV parser. Handles quoted fields, escaped quotes, newlines in quotes. -/
partial def parseCsv (s : String) : Table :=
  let rows := parseRows s.iter
  match rows with
  | [] => { columns := #[] }
  | header :: rest =>
    let names := header.map (·.trim)
    Table.fromRows names.toArray (rest.map (·.map parseCell |>.toArray) |>.toArray)
where
  parseRows (it : String.Iterator) : List (List String) :=
    if it.atEnd then []
    else
      let (row, rest) := parseRow it
      -- skip trailing empty row
      if rest.atEnd && row == [""] then []
      else row :: parseRows rest
  parseRow (it : String.Iterator) : (List String) × String.Iterator :=
    let (field, rest, eol) := parseField it
    if eol then ([field], rest)
    else
      let (fields, rest') := parseRow rest
      (field :: fields, rest')
  parseField (it : String.Iterator) : String × String.Iterator × Bool :=
    if it.atEnd then ("", it, true)
    else if it.curr == '"' then parseQuoted it.next "".toSubstring
    else parseUnquoted it "".toSubstring
  parseUnquoted (it : String.Iterator) (acc : Substring) : String × String.Iterator × Bool :=
    if it.atEnd then (acc.toString, it, true)
    else
      let c := it.curr
      if c == ',' then (acc.toString, it.next, false)
      else if c == '\n' then (acc.toString, it.next, true)
      else if c == '\r' then
        let next := it.next
        let next := if !next.atEnd && next.curr == '\n' then next.next else next
        (acc.toString, next, true)
      else parseUnquoted it.next (acc.toString ++ c.toString).toSubstring
  parseQuoted (it : String.Iterator) (acc : Substring) : String × String.Iterator × Bool :=
    if it.atEnd then (acc.toString, it, true)
    else
      let c := it.curr
      if c == '"' then
        let next := it.next
        if !next.atEnd && next.curr == '"' then
          -- escaped quote
          parseQuoted next.next (acc.toString ++ "\"").toSubstring
        else
          -- end of quoted field, consume delimiter
          consumeDelim next acc.toString
      else
        parseQuoted it.next (acc.toString ++ c.toString).toSubstring
  consumeDelim (it : String.Iterator) (field : String) : String × String.Iterator × Bool :=
    if it.atEnd then (field, it, true)
    else if it.curr == ',' then (field, it.next, false)
    else if it.curr == '\n' then (field, it.next, true)
    else if it.curr == '\r' then
      let next := it.next
      let next := if !next.atEnd && next.curr == '\n' then next.next else next
      (field, next, true)
    else (field, it, true)  -- malformed, treat as EOL

private def needsQuoting (s : String) : Bool :=
  s.any fun c => c == ',' || c == '"' || c == '\n' || c == '\r'

private def quoteField (s : String) : String :=
  if needsQuoting s then
    "\"" ++ s.replace "\"" "\"\"" ++ "\""
  else s

def renderCell : Cell → String
  | .float v => toString v
  | .str v => v
  | .na => ""

def renderCsv (t : Table) : String :=
  let header := ",".intercalate (t.colNames.toList.map quoteField)
  let rows := (List.range t.nRows).map fun i =>
    ",".intercalate ((t.row i).map (quoteField ∘ renderCell)).toList
  "\n".intercalate (header :: rows)

end LeanTab
