import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

private def tryParseFloat (s : String) : Option Float :=
  let s := s.trimAscii.toString
  -- Split on 'e' or 'E' for scientific notation
  let (mantissa, exponent) := match s.splitOn "e" with
    | [m, e] => (m, e)
    | _ => match s.splitOn "E" with
      | [m, e] => (m, e)
      | _ => (s, "0")
  let (neg, m) := if mantissa.startsWith "-" then (true, (mantissa.drop 1).toString)
    else if mantissa.startsWith "+" then (false, (mantissa.drop 1).toString)
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
    let expStr := if expNeg then (exponent.drop 1).toString
      else if exponent.startsWith "+" then (exponent.drop 1).toString
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
  let rows := parseRows s.toList
  match rows with
  | [] => { columns := #[] }
  | header :: rest =>
    let names := header.map (·.trimAscii.toString)
    Table.fromRows names.toArray (rest.map (·.map parseCell |>.toArray) |>.toArray)
where
  finish (acc : List Char) : String :=
    String.ofList acc.reverse
  parseRows (cs : List Char) : List (List String) :=
    match cs with
    | [] => []
    | _ =>
      let (row, rest) := parseRow cs
      -- skip trailing empty row
      if rest.isEmpty && row == [""] then []
      else row :: parseRows rest
  parseRow (cs : List Char) : (List String) × List Char :=
    let (field, rest, eol) := parseField cs
    if eol then ([field], rest)
    else
      let (fields, rest') := parseRow rest
      (field :: fields, rest')
  parseField (cs : List Char) : String × List Char × Bool :=
    match cs with
    | [] => ("", [], true)
    | '"' :: rest => parseQuoted rest []
    | _ => parseUnquoted cs []
  parseUnquoted (cs : List Char) (acc : List Char) : String × List Char × Bool :=
    match cs with
    | [] => (finish acc, [], true)
    | c :: rest =>
      if c == delimiter then (finish acc, rest, false)
      else if c == '\n' then (finish acc, rest, true)
      else if c == '\r' then
        let rest := match rest with
          | '\n' :: rest' => rest'
          | _ => rest
        (finish acc, rest, true)
      else parseUnquoted rest (c :: acc)
  parseQuoted (cs : List Char) (acc : List Char) : String × List Char × Bool :=
    match cs with
    | [] => (finish acc, [], true)
    | c :: rest =>
      if c == '"' then
        match rest with
        | '"' :: rest' =>
          -- escaped quote
          parseQuoted rest' ('"' :: acc)
        | _ =>
          -- end of quoted field, consume delimiter
          consumeDelim rest (finish acc)
      else
        parseQuoted rest (c :: acc)
  consumeDelim (cs : List Char) (field : String) : String × List Char × Bool :=
    match cs with
    | [] => (field, [], true)
    | c :: rest =>
      if c == delimiter then (field, rest, false)
      else if c == '\n' then (field, rest, true)
      else if c == '\r' then
        let rest := match rest with
          | '\n' :: rest' => rest'
          | _ => rest
        (field, rest, true)
      else (field, cs, true)  -- malformed, treat as EOL

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
  let delStr := String.ofList [delimiter]
  let qf (s : String) := quoteField s delimiter
  let header := delStr.intercalate (t.colNames.toList.map qf)
  let rows := (List.range t.nRows).map fun i =>
    delStr.intercalate ((t.row i).map (fun c => qf (renderCell c))).toList
  "\n".intercalate (header :: rows)

end LeanTab
