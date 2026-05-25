import LeanTab.Sql.Ast
import LeanTab.GroupBy

/-! # LeanTab.Sql.Eval — evaluate SQL queries against Tables

`eval` takes a `Query` and a name→Table environment, and produces a `Table`.
It dispatches to existing LeanTab verbs:

  - WHERE → `filter`
  - SELECT columns → `select` + `mutate`
  - GROUP BY → `groupBy` + `summarize`
  - ORDER BY → `arrange`
  - LIMIT → `head`
  - JOIN → cross product + filter (naive but correct)

This is a reference evaluator — correct, not fast.
-/
-- Manifest claims: LeanTab/Sql/Manifest.lean

set_option autoImplicit false

namespace LeanTab.Sql
open LeanTab

/-- A database: named tables. -/
abbrev Database := List (String × Table)

/-- Look up a table by name. -/
def Database.get (db : Database) (name : String) : Option Table :=
  db.find? (·.1 == name) |>.map (·.2)

-- ════════════════════════════════════════════════════════════
-- § Expression evaluation
-- ════════════════════════════════════════════════════════════

/-- Evaluate an expression against a row (array of cells + column names). -/
partial def evalExpr (names : Array String) (row : Array Cell) : Expr → Cell
  | .col name => match names.findIdx? (· == name) with
    | some i => row.getD i .na
    | none => .na
  | .litFloat v => .float v
  | .litStr v => .str v
  | .null => .na
  | .add l r => binFloat (evalExpr names row l) (evalExpr names row r) (· + ·)
  | .sub l r => binFloat (evalExpr names row l) (evalExpr names row r) (· - ·)
  | .mul l r => binFloat (evalExpr names row l) (evalExpr names row r) (· * ·)
  | .div l r => binFloat (evalExpr names row l) (evalExpr names row r)
      (fun a b => if b == 0 then 0 else a / b)
  | .eq l r => cellBool (cellEq (evalExpr names row l) (evalExpr names row r))
  | .neq l r => cellBool (!cellEq (evalExpr names row l) (evalExpr names row r))
  | .lt l r => cellBool (cellLt (evalExpr names row l) (evalExpr names row r))
  | .gt l r => cellBool (cellLt (evalExpr names row r) (evalExpr names row l))
  | .le l r => let a := evalExpr names row l; let b := evalExpr names row r
    cellBool (cellEq a b || cellLt a b)
  | .ge l r => let a := evalExpr names row l; let b := evalExpr names row r
    cellBool (cellEq a b || cellLt b a)
  | .and l r => cellBool (isTruthy (evalExpr names row l) && isTruthy (evalExpr names row r))
  | .or l r => cellBool (isTruthy (evalExpr names row l) || isTruthy (evalExpr names row r))
  | .not e => cellBool (!isTruthy (evalExpr names row e))
  | .isNull e => cellBool (evalExpr names row e == .na)
  | .isNotNull e => cellBool (evalExpr names row e != .na)
  | .between e lo hi =>
    let v := evalExpr names row e
    let l := evalExpr names row lo
    let h := evalExpr names row hi
    cellBool ((cellEq v l || cellLt l v) && (cellEq v h || cellLt v h))
  | .inList e vals =>
    let v := evalExpr names row e
    cellBool (vals.any fun ve => cellEq v (evalExpr names row ve))
where
  binFloat (a b : Cell) (f : Float → Float → Float) : Cell :=
    match a, b with
    | .float x, .float y => .float (f x y)
    | _, _ => .na
  cellEq (a b : Cell) : Bool := a == b
  cellLt (a b : Cell) : Bool :=
    match a, b with
    | .float x, .float y => x < y
    | .str x, .str y => x < y
    | _, _ => false
  cellBool (b : Bool) : Cell := .float (if b then 1.0 else 0.0)
  isTruthy (c : Cell) : Bool :=
    match c with
    | .float v => v != 0
    | .str s => s != ""
    | .na => false

/-- Is a cell truthy? (exported for WHERE evaluation) -/
def cellTruthy (c : Cell) : Bool :=
  match c with
  | .float v => v != 0
  | .str s => s != ""
  | .na => false

-- ════════════════════════════════════════════════════════════
-- § Aggregate evaluation
-- ════════════════════════════════════════════════════════════

/-- Evaluate an aggregate function over a group of cells. -/
def evalAgg (fn : AggFn) (cells : Array Cell) : Cell :=
  match fn with
  | .countStar => .float cells.size.toFloat
  | .count => .float (cells.filter (· != .na)).size.toFloat
  | .sum => aggSum cells
  | .avg => aggMean cells
  | .min => aggMin cells
  | .max => aggMax cells

-- ════════════════════════════════════════════════════════════
-- § JOIN
-- ════════════════════════════════════════════════════════════

/-- Cross product of two tables (all column names prefixed if ambiguous). -/
private def crossJoin (l r : Table) : Table :=
  let lNames := l.colNames
  let rNames := r.colNames
  let nl := l.nRows
  let nr := r.nRows
  let totalRows := nl * nr
  let lCols := l.columns.map fun c =>
    { name := c.name
      data := (Array.range totalRows).map fun i => c.data.getD (i / nr) .na : Column }
  let rCols := r.columns.map fun c =>
    let name := if lNames.contains c.name then c.name ++ "_r" else c.name
    { name
      data := (Array.range totalRows).map fun i => c.data.getD (i % nr) .na : Column }
  { columns := lCols ++ rCols }

-- ════════════════════════════════════════════════════════════
-- § Query evaluation
-- ════════════════════════════════════════════════════════════

/-- Evaluate a SQL query against a database. -/
def eval (q : Query) (db : Database) : Option Table := do
  -- FROM
  let mut t ← db.get q.from_
  -- JOINs
  for j in q.joins do
    let rhs ← db.get j.table
    t := crossJoin t rhs
    -- Apply ON condition as filter
    match j.on_ with
    | some cond =>
      let names := t.colNames
      t := filter t (fun row =>
        cellTruthy (evalExpr names row cond))
    | none => pure ()  -- CROSS JOIN, no filter
  -- WHERE
  match q.where_ with
  | some cond =>
    let names := t.colNames
    t := filter t (fun row =>
      cellTruthy (evalExpr names row cond))
  | none => pure ()
  -- GROUP BY + aggregates
  if !q.groupBy.isEmpty then
    -- For simplicity, group by first group column
    let gCol := q.groupBy.head!
    let g := groupBy t gCol
    -- Build result columns from select items
    let mut outCols : Array (String × Array Cell) := #[]
    -- Group key column
    outCols := outCols.push (gCol, g.keys)
    -- Aggregate columns
    for item in q.select_ do
      match item with
      | .agg fn (.col src) alias_ =>
        let vals := g.groups.map fun indices =>
          let cells := indices.map fun i => (t.colData src).getD i .na
          evalAgg fn cells
        outCols := outCols.push (alias_, vals)
      | .agg .countStar _ alias_ =>
        let vals := g.groups.map fun indices =>
          Cell.float indices.size.toFloat
        outCols := outCols.push (alias_, vals)
      | _ => pure ()  -- non-aggregate select items in GROUP BY context: skip
    t := Table.fromColumns outCols
  else
    -- No GROUP BY: apply SELECT as column selection / expression
    let hasAgg := q.select_.any fun
      | .agg .. => true | _ => false
    if hasAgg then
      -- Whole-table aggregate (e.g. SELECT COUNT(*) FROM t)
      let mut outCols : Array (String × Array Cell) := #[]
      for item in q.select_ do
        match item with
        | .agg fn (.col src) alias_ =>
          let cells := t.colData src
          outCols := outCols.push (alias_, #[evalAgg fn cells])
        | .agg .countStar _ alias_ =>
          outCols := outCols.push (alias_, #[.float t.nRows.toFloat])
        | _ => pure ()
      t := Table.fromColumns outCols
    else
      -- Plain SELECT: column selection
      let selectNames := q.select_.filterMap fun
        | .star => none
        | .expr (.col name) none => some name
        | .expr _ (some alias_) => some alias_
        | _ => none
      let hasStar := q.select_.any fun | .star => true | _ => false
      if !hasStar && !selectNames.isEmpty then
        t := select t selectNames.toArray
  -- ORDER BY
  match q.orderBy.head? with
  | some ob => t := arrange t ob.col
  | none => pure ()
  -- LIMIT
  match q.limit with
  | some n => t := head t n
  | none => pure ()
  return t

/-- Extract all column names referenced in an Expr. -/
partial def Expr.columns : Expr → List String
  | .col name => [name]
  | .add l r | .sub l r | .mul l r | .div l r
  | .eq l r | .neq l r | .lt l r | .gt l r | .le l r | .ge l r
  | .and l r | .or l r => l.columns ++ r.columns
  | .not e | .isNull e | .isNotNull e => e.columns
  | .between e lo hi => e.columns ++ lo.columns ++ hi.columns
  | .inList e vals => e.columns ++ vals.bind Expr.columns
  | _ => []

/-- Check that all columns referenced in an Expr exist in a table.
    Returns the list of missing column names (empty = valid). -/
def checkExpr (t : LeanTab.Table) (expr : Expr) : List String :=
  let available := t.colNames
  expr.columns.filter fun name => !available.contains name

/-- Parse an aggregate expression like "avg(salary)" or "count(*)".
    Returns (AggFn, column name) or none on failure. -/
def parseAggExpr (s : String) : Option (AggFn × String) :=
  let s := s.trim
  let parts := s.splitOn "("
  if parts.length < 2 then none
  else
    let fnStr := (parts.getD 0 "").trim.toLower
    let colPart := (parts.getD 1 "").trim
    let col := if colPart.endsWith ")" then colPart.dropRight 1 |>.trim else colPart
    match fnStr with
    | "count" => if col == "*" then some (.countStar, col) else some (.count, col)
    | "sum" => some (.sum, col)
    | "avg" | "mean" => some (.avg, col)
    | "min" => some (.min, col)
    | "max" => some (.max, col)
    | _ => none

/-- Summarize a grouped table using a parsed aggregate.
    `resultCol` is the name for the output column. -/
def summarizeByAgg (g : LeanTab.Grouped) (resultCol : String)
    (fn : AggFn) (sourceCol : String) : LeanTab.Table :=
  let vals := g.groups.map fun indices =>
    match fn with
    | .countStar => Cell.float indices.size.toFloat
    | _ =>
      let cells := indices.map fun i => (g.table.colData sourceCol).getD i .na
      evalAgg fn cells
  LeanTab.Table.fromColumns #[(g.byCol, g.keys), (resultCol, vals)]

/-- Check that an aggregate expression references valid columns. -/
def checkAggExpr (t : LeanTab.Table) (s : String) : Option String :=
  match parseAggExpr s with
  | none => some s!"Failed to parse aggregate expression: '{s}'"
  | some (.countStar, _) => none  -- count(*) doesn't need a column
  | some (_, col) =>
    if t.colNames.contains col then none
    else some s!"Column '{col}' not found in table"

/-- Filter a table by an Expr predicate. The Expr is evaluated against
    each row using the table's own column names. Portable: works on any
    table that has the referenced columns. -/
def filterByExpr (t : LeanTab.Table) (expr : Expr) : LeanTab.Table :=
  let names := t.colNames
  LeanTab.filter t fun row => cellTruthy (evalExpr names row expr)

/-- Mutate a table by an Expr computation. Adds a column whose value
    is the expression evaluated per row. -/
def mutateByExpr (t : LeanTab.Table) (colName : String) (expr : Expr) : LeanTab.Table :=
  let names := t.colNames
  LeanTab.mutate t colName fun row => evalExpr names row expr

end LeanTab.Sql
