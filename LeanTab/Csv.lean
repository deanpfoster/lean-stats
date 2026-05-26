import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

private def tryParseFloat (s : String) : Option Float :=
  let s := s.trim
  -- Split on 'e' or 'E' for scientific notation
  let (mantissa, exponent) := match s.splitOn "e" with
    | [m, e] => (m, e)
    | _ => match s.splitOn "E" with
      | [m, e] => (m, e)
      | _ => (s, "0")
  let (neg, m) := if mantissa.startsWith "-" then (true, mantissa.drop 1)
    else if mantissa.startsWith "+" then (false, mantissa.drop 1)
    else (false, mantissa)
  let parts := m.splitOn "."
  let baseVal := match parts with
    | [intPart] => match intPart.toNat? with
      | some n => some n.toFloat
      | none => none
    | [intPart, fracPart] =>
      if fracPart.isEmpty then none
      else match intPart.toNat?, fracPart.toNat? with
        | some i, some f =>
          let denom := (10 : Float) ^ fracPart.length.toFloat
          some (i.toFloat + f.toFloat / denom)
        | _, _ => none
    | _ => none
  match baseVal with
  | none => none
  | some v =>
    let v := if neg then -v else v
    -- Apply exponent
    let expNeg := exponent.startsWith "-"
    let expStr := if expNeg then exponent.drop 1
      else if exponent.startsWith "+" then exponent.drop 1
      else exponent
    match expStr.toNat? with
    | some e =>
      let factor := (10 : Float) ^ e.toFloat
      some (if expNeg then v / factor else v * factor)
    | none => if exponent == "0" then some v else none

def parseCell (s : String) : Cell :=
  if s == "" then .na
  else match tryParseFloat s with
    | some f => .float f
    | none => .str s

/-- RFC 4180 CSV parser. Handles quoted fields, escaped quotes, newlines in quotes. -/
partial def parseCsv (s : String) (delimiter : Char := ',') : Table :=
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
      if c == delimiter then (acc.toString, it.next, false)
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
    else if it.curr == delimiter then (field, it.next, false)
    else if it.curr == '\n' then (field, it.next, true)
    else if it.curr == '\r' then
      let next := it.next
      let next := if !next.atEnd && next.curr == '\n' then next.next else next
      (field, next, true)
    else (field, it, true)  -- malformed, treat as EOL

private def needsQuoting (s : String) (delimiter : Char) : Bool :=
  s.any fun c => c == delimiter || c == '"' || c == '\n' || c == '\r'

private def quoteField (s : String) (delimiter : Char) : String :=
  if needsQuoting s delimiter then
    "\"" ++ s.replace "\"" "\"\"" ++ "\""
  else s

def renderCell : Cell → String
  | .float v => toString v
  | .str v => v
  | .na => ""

def renderCsv (t : Table) (delimiter : Char := ',') : String :=
  let delStr := String.mk [delimiter]
  let qf (s : String) := quoteField s delimiter
  let header := delStr.intercalate (t.colNames.toList.map qf)
  let rows := (List.range t.nRows).map fun i =>
    delStr.intercalate ((t.row i).map (fun c => qf (renderCell c))).toList
  "\n".intercalate (header :: rows)

end LeanTab
