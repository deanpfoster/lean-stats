import LeanStats.Diagnostics
import LeanStats.Transform
import LeanStats.Tests

/-! # LeanStats.Eval — parse and evaluate stats expressions from strings

Lets an LLM write `mean([1, 2, 3])` and get back `"2.000000"`.

Grammar:
  expr   ::= number | array | call | string
  number ::= -?[0-9]+(\.[0-9]+)?
  array  ::= '[' (expr (',' expr)*)? ']'
  call   ::= ident '(' (expr (',' expr)*)? ')'
  string ::= '"' [^"]* '"'

Dispatch table covers all LeanStats public functions.
Pure — no IO. l3m calls `evalString` and gets back a result or error message.
-/
-- Manifest claims: LeanStats/Manifests/Eval.lean

set_option autoImplicit false

namespace LeanStats.Eval

inductive Value where
  | num : Float → Value
  | arr : Array Value → Value
  | str : String → Value
  | none_ : Value
  deriving Repr, Inhabited

structure ParseState where
  input : String
  pos : Nat

private def peek (s : ParseState) : Option Char :=
  s.input.get? ⟨s.pos⟩

private def advance (s : ParseState) : ParseState :=
  { s with pos := s.pos + 1 }

private partial def skipWs (s : ParseState) : ParseState :=
  match peek s with
  | some ' ' | some '\t' | some '\n' | some '\r' => skipWs (advance s)
  | _ => s

private def isDigit (c : Char) : Bool := c >= '0' && c <= '9'
private def isIdent (c : Char) : Bool :=
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == '.' || isDigit c

private partial def parseNumber (s : ParseState) : Except String (Value × ParseState) :=
  let start := s.pos
  let s := match peek s with | some '-' => advance s | _ => s
  let s := consumeDigits s
  let s := match peek s with
    | some '.' => consumeDigits (advance s)
    | _ => s
  if s.pos == start then .error s!"expected number at {s.pos}"
  else
    let numStr := s.input.extract ⟨start⟩ ⟨s.pos⟩
    .ok (.num (parseFloat numStr), s)
where
  consumeDigits (s : ParseState) : ParseState :=
    match peek s with
    | some c => if isDigit c then consumeDigits (advance s) else s
    | none => s
  parseFloat (s : String) : Float :=
    let neg := s.startsWith "-"
    let s := if neg then s.drop 1 else s
    let parts := s.splitOn "."
    let whole := (parts.getD 0 "0").foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0
    let frac := match parts.get? 1 with
      | none => 0.0
      | some f =>
        let (v, _) := f.foldl (fun (acc, div) c =>
          (acc + (c.toNat - '0'.toNat).toFloat / div, div * 10)) (0.0, 10.0)
        v
    let r := whole.toFloat + frac
    if neg then -r else r

-- ════════════════════════════════════════════════════════════
-- § Dispatch table (must be before parser which calls it)
-- ════════════════════════════════════════════════════════════

private def toFloats (v : Value) (ctx : String) : Except String (Array Float) :=
  match v with
  | .arr elems => elems.foldlM (init := #[]) fun acc e =>
    match e with
    | .num f => .ok (acc.push f)
    | _ => .error s!"{ctx}: expected array of numbers"
  | _ => .error s!"{ctx}: expected an array"

private def floatsToVal (xs : Array Float) : Value := .arr (xs.map .num)

private def dispatchFn (name : String) (args : Array Value) : Except String Value :=
  let canon := if name.startsWith "LeanStats." then name.drop 10 else name
  match canon, args.size with
  | "mean", 1 => do let xs ← toFloats args[0]! "mean"; .ok (.num (mean xs))
  | "variance", 1 => do let xs ← toFloats args[0]! "variance"; .ok (.num (variance xs))
  | "stdDev", 1 => do let xs ← toFloats args[0]! "stdDev"; .ok (.num (stdDev xs))
  | "median", 1 => do let xs ← toFloats args[0]! "median"; .ok (.num (median xs))
  | "quantile", 2 => do
    let xs ← toFloats args[0]! "quantile"
    let q := match args[1]! with | .num f => f | _ => 0.5
    .ok (.num (quantile xs q))
  | "correlation", 2 => do
    let xs ← toFloats args[0]! "correlation"; let ys ← toFloats args[1]! "correlation"
    .ok (.num (correlation xs ys))
  | "linearRegression", 2 => do
    let xs ← toFloats args[0]! "linearRegression"; let ys ← toFloats args[1]! "linearRegression"
    match linearRegression xs ys with
    | some fit => .ok (.str s!"slope={fit.slope}, intercept={fit.intercept}, r2={fit.r2}")
    | none => .ok (.none_)
  | "tTestOneSample", 2 => do
    let xs ← toFloats args[0]! "tTestOneSample"
    let mu := match args[1]! with | .num f => f | _ => 0
    .ok (.num (tTestOneSample xs mu))
  | "tTestTwoSample", 2 => do
    let xs ← toFloats args[0]! "tTestTwoSample"; let ys ← toFloats args[1]! "tTestTwoSample"
    .ok (.num (tTestTwoSample xs ys))
  | "logTransform", 1 => do let xs ← toFloats args[0]! "logTransform"; .ok (floatsToVal (logTransform xs))
  | "sqrtTransform", 1 => do let xs ← toFloats args[0]! "sqrtTransform"; .ok (floatsToVal (sqrtTransform xs))
  | "recipTransform", 1 => do let xs ← toFloats args[0]! "recipTransform"; .ok (floatsToVal (recipTransform xs))
  | "summary", 1 => do
    let xs ← toFloats args[0]! "summary"
    let s := summary xs
    .ok (.str s!"n={s.n}, mean={s.mean}, sd={s.sd}, min={s.min}, q25={s.q25}, median={s.median}, q75={s.q75}, max={s.max}")
  | "regressionDiag", 2 => do
    let xs ← toFloats args[0]! "regressionDiag"; let ys ← toFloats args[1]! "regressionDiag"
    match regressionDiag xs ys with
    | some d =>
      let s := regressionSummary d
      .ok (.str s!"slope={s.slope}, intercept={s.intercept}, r2={s.r2}, adjR2={s.adjR2}, se={s.se}, dw={s.durbinWatson}, outliers={s.nOutliers}, influential={s.nInfluential}")
    | none => .ok (.none_)
  | fname, nargs =>
    let known := ["mean", "variance", "stdDev", "median", "quantile", "correlation",
      "linearRegression", "tTestOneSample", "tTestTwoSample", "logTransform",
      "sqrtTransform", "recipTransform", "summary", "regressionDiag"]
    let suggs := known.filter fun k => k.toLower.startsWith (fname.toLower.take 3)
    let msg := s!"unknown function '{fname}' with {nargs} args"
    let hint := if suggs.isEmpty then "" else s!". Did you mean: {suggs}?"
    .error (msg ++ hint)

-- ════════════════════════════════════════════════════════════
-- § Parser
-- ════════════════════════════════════════════════════════════

private partial def parseExprAt (s : ParseState) : Except String (Value × ParseState) :=
  let s := skipWs s
  match peek s with
  | none => .error "unexpected end of input"
  | some '[' => parseArray (advance s)
  | some '"' => parseString (advance s)
  | some c =>
    if isDigit c || (c == '-') then parseNumber s
    else if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '_' then
      let (name, s) := collectIdent s
      let s := skipWs s
      match peek s with
      | some '(' => parseCall name (advance s)
      | _ => .error s!"bare identifier '{name}' — did you mean {name}(...)?"
    else .error s!"unexpected '{c}' at {s.pos}"
where
  collectIdent (s : ParseState) : String × ParseState :=
    let start := s.pos
    let rec go (s : ParseState) : ParseState :=
      match peek s with
      | some c => if isIdent c then go (advance s) else s
      | none => s
    let s' := go s
    (s.input.extract ⟨start⟩ ⟨s'.pos⟩, s')
  parseArray (s : ParseState) : Except String (Value × ParseState) :=
    let s := skipWs s
    match peek s with
    | some ']' => .ok (.arr #[], advance s)
    | _ => do
      let (first, s) ← parseExprAt s
      collectMore #[first] s
  collectMore (acc : Array Value) (s : ParseState) : Except String (Value × ParseState) :=
    let s := skipWs s
    match peek s with
    | some ']' => .ok (.arr acc, advance s)
    | some ',' => do let (v, s) ← parseExprAt (skipWs (advance s)); collectMore (acc.push v) s
    | _ => .error s!"expected ',' or ']' at {s.pos}"
  parseCall (name : String) (s : ParseState) : Except String (Value × ParseState) :=
    let s := skipWs s
    match peek s with
    | some ')' => dispatch name #[] (advance s)
    | _ => do
      let (first, s) ← parseExprAt s
      collectArgs name #[first] s
  collectArgs (name : String) (acc : Array Value) (s : ParseState) : Except String (Value × ParseState) :=
    let s := skipWs s
    match peek s with
    | some ')' => dispatch name acc (advance s)
    | some ',' => do let (v, s) ← parseExprAt (skipWs (advance s)); collectArgs name (acc.push v) s
    | _ => .error s!"expected ',' or ')' at {s.pos}"
  parseString (s : ParseState) : Except String (Value × ParseState) :=
    let start := s.pos
    let rec go (s : ParseState) : ParseState :=
      match peek s with
      | some '"' => s
      | some _ => go (advance s)
      | none => s
    let s' := go s
    .ok (.str (s.input.extract ⟨start⟩ ⟨s'.pos⟩), advance s')
  dispatch (name : String) (args : Array Value) (s : ParseState) : Except String (Value × ParseState) :=
    match dispatchFn name args with
    | .ok v => .ok (v, s)
    | .error e => .error e

-- ════════════════════════════════════════════════════════════
-- § Top-level API
-- ════════════════════════════════════════════════════════════

/-- Stringify a Value for display. -/
partial def stringify : Value → String
  | .num f => toString f
  | .str s => s
  | .none_ => "none"
  | .arr elems => "[" ++ String.intercalate ", " (elems.toList.map stringify) ++ "]"

/-- Parse and evaluate a stats expression string. Returns the result as a string
    or an error message. This is the single entry point l3m calls. -/
def evalString (input : String) : Except String String :=
  match parseExprAt { input, pos := 0 } with
  | .error e => .error e
  | .ok (val, _) => .ok (stringify val)

end LeanStats.Eval
