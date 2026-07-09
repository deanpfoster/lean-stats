import LeanTab.Sql.Eval

/-! # LeanTab.Sql.Parse — parse predicate/expression strings into Expr

Parses simple SQL-like expressions:
  "age > 30"
  "name = 'alice'"
  "x >= 1.5 AND y < 10"
  "status IS NULL"
  "region IN ('east', 'west')"

Returns `Option Expr` — none on malformed input. The parser is
deliberately simple (no precedence climbing, no subqueries). It
handles the 90% case for filter predicates.

Grammar:
  expr     := orExpr
  orExpr   := andExpr ("OR" andExpr)*
  andExpr  := atom ("AND" atom)*
  atom     := "NOT" atom
           | term comparison term
           | term "IS" "NULL"
           | term "IS" "NOT" "NULL"
           | term "IN" "(" literals ")"
           | term "BETWEEN" term "AND" term
           | "(" expr ")"
  term     := number | 'string' | identifier
  comparison := "=" | "!=" | "<>" | "<" | ">" | "<=" | ">="
-/

set_option autoImplicit false

namespace LeanTab.Sql

/-- Tokenize an expression string into words, respecting quoted strings. -/
private partial def tokenize (s : String) : List String :=
  let s := s.trimAscii.toString
  go s.toList []
where
  go : List Char → List String → List String
  | [], acc => acc.reverse
  | '\'' :: rest, acc =>
    -- Quoted string: collect until closing quote
    let (inside, after) := collectUntil rest '\''
    go after (("'" ++ String.mk inside ++ "'") :: acc)
  | ' ' :: rest, acc => go (rest.dropWhile (· == ' ')) acc
  | c :: rest, acc =>
    if c ∈ ['(', ')', ','] then
      go rest (String.mk [c] :: acc)
    else
      -- Collect word (alphanumeric, dots, underscores, or operator chars)
      let isOp := c ∈ ['<', '>', '=', '!']
      let (word, after) := if isOp
        then collectWhile (c :: rest) (· ∈ ['<', '>', '=', '!'])
        else collectWhile (c :: rest) fun ch =>
          ch != ' ' && ch != '(' && ch != ')' && ch != ',' && ch != '\''
      go after (String.mk word :: acc)
  collectUntil : List Char → Char → List Char × List Char
  | [], _ => ([], [])
  | c :: rest, delim =>
    if c == delim then ([], rest)
    else let (inside, after) := collectUntil rest delim; (c :: inside, after)
  collectWhile : List Char → (Char → Bool) → List Char × List Char
  | [], _ => ([], [])
  | c :: rest, pred =>
    if pred c then
      let (word, after) := collectWhile rest pred; (c :: word, after)
    else ([], c :: rest)

/-- Try to parse a string as a Float. -/
private def tryFloat (s : String) : Option Float :=
  if s.isEmpty then none
  else
    let chars := s.toList
    let chars := if chars.head? == some '-' then chars.tail else chars
    let hasDot := chars.contains '.'
    let digits := if hasDot
      then chars.filter (· != '.')
      else chars
    if digits.all Char.isDigit && !digits.isEmpty then
      -- Manual float construction
      some (parseFloatSimple s)
    else none
where
  parseFloatSimple (s : String) : Float :=
    let negative := s.startsWith "-"
    let s := if negative then (s.drop 1).toString else s
    let parts := s.splitOn "."
    let whole := (parts.getD 0 "0").foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0
    let frac := match parts[1]? with
      | none => 0.0
      | some f => f.foldl (fun (acc, div) c =>
          (acc + (c.toNat - '0'.toNat).toFloat / div, div * 10)) (0.0, 10.0) |>.1
    let v := whole.toFloat + frac
    if negative then -v else v

/-- Parse a term (literal or column reference). -/
private def parseTerm (tok : String) : Expr :=
  if tok.startsWith "'" && tok.endsWith "'" then
    .litStr ((tok.drop 1).toString.dropEnd 1).toString
  else match tryFloat tok with
    | some f => .litFloat f
    | none =>
      if tok.toUpper == "NULL" then .null
      else .col tok

/-- Parse a comparison operator. -/
private def parseOp (tok : String) : Option (Expr → Expr → Expr) :=
  match tok with
  | "=" => some .eq
  | "==" => some .eq
  | "!=" => some .neq
  | "<>" => some .neq
  | "<" => some .lt
  | ">" => some .gt
  | "<=" => some .le
  | ">=" => some .ge
  | _ => none

/-- Parse an expression string into an Expr. Returns none on failure. -/
partial def parseExpr (s : String) : Option Expr :=
  let tokens := tokenize s
  match parseOrExpr tokens with
  | some (e, []) => some e
  | some (e, _) => some e  -- trailing tokens OK (lenient)
  | none => none
where
  parseOrExpr (toks : List String) : Option (Expr × List String) := do
    let (left, rest) ← parseAndExpr toks
    foldOr left rest
  foldOr (acc : Expr) (toks : List String) : Option (Expr × List String) :=
    match toks with
    | t :: rest =>
      if t.toUpper == "OR" then do
        let (right, rest') ← parseAndExpr rest
        foldOr (.or acc right) rest'
      else some (acc, toks)
    | [] => some (acc, [])
  parseAndExpr (toks : List String) : Option (Expr × List String) := do
    let (left, rest) ← parseAtom toks
    foldAnd left rest
  foldAnd (acc : Expr) (toks : List String) : Option (Expr × List String) :=
    match toks with
    | t :: rest =>
      if t.toUpper == "AND" then do
        let (right, rest') ← parseAtom rest
        foldAnd (.and acc right) rest'
      else some (acc, toks)
    | [] => some (acc, [])
  parseAtom (toks : List String) : Option (Expr × List String) :=
    match toks with
    | [] => none
    | "(" :: rest => do
      let (e, rest') ← parseOrExpr rest
      match rest' with
      | ")" :: rest'' => some (e, rest'')
      | _ => some (e, rest')  -- lenient: missing close paren
    | t :: rest =>
      if t.toUpper == "NOT" then do
        let (e, rest') ← parseAtom rest
        some (.not e, rest')
      else
        let lhs := parseTerm t
        match rest with
        | op :: rest' =>
          if op.toUpper == "IS" then
            match rest' with
            | "NOT" :: "NULL" :: rest'' | "not" :: "null" :: rest'' =>
              some (.isNotNull lhs, rest'')
            | "NULL" :: rest'' | "null" :: rest'' =>
              some (.isNull lhs, rest'')
            | _ => some (lhs, rest)
          else if op.toUpper == "IN" then
            match rest' with
            | "(" :: rest'' =>
              let (vals, rest''') := collectLiterals rest'' []
              some (.inList lhs vals, rest''')
            | _ => some (lhs, rest)
          else if op.toUpper == "BETWEEN" then
            match rest' with
            | lo :: "AND" :: hi :: rest'' | lo :: "and" :: hi :: rest'' =>
              some (.between lhs (parseTerm lo) (parseTerm hi), rest'')
            | _ => some (lhs, rest)
          else match parseOp op with
            | some mkOp => some (mkOp lhs (parseTerm (rest'.headD "")), rest'.tailD [])
            | none => some (lhs, rest)
        | [] => some (lhs, [])
  collectLiterals : List String → List Expr → List Expr × List String
  | [], acc => (acc.reverse, [])
  | ")" :: rest, acc => (acc.reverse, rest)
  | "," :: rest, acc => collectLiterals rest acc
  | tok :: rest, acc => collectLiterals rest (parseTerm tok :: acc)

end LeanTab.Sql
