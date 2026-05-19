import LeanTab.Verbs
import LeanTab.GroupBy
import LeanTab.Sql.Parse
import LeanTab.Sql.Eval

/-! # LeanTab.Query — component-based query pipeline

The LLM provides structured arguments (where, select, group_by, agg,
order_by, limit) and this function assembles them into a chain of
pure LeanTab verb calls.

This is the pure core that l3m's tool wrapper calls. l3m handles IO
(reading the CSV file) and passes the Table + args here.
-/

set_option autoImplicit false

namespace LeanTab

/-- Arguments for a component-based query. -/
structure QueryArgs where
  where_ : Option String := none
  select : Option (Array String) := none
  groupBy : Option String := none
  agg : Option String := none
  orderBy : Option String := none
  limit : Option Nat := none
  deriving Repr, Inhabited

/-- Run a verb pipeline against a Table. Pure.
    Returns the result table or an error message. -/
def runQuery (t : Table) (args : QueryArgs) : Except String Table := do
  -- WHERE
  let t ← match args.where_ with
    | some w => match Sql.parseExpr w with
      | none => .error s!"could not parse WHERE: '{w}'"
      | some expr => .ok (Sql.filterByExpr t expr)
    | none => pure t
  -- SELECT
  let t := match args.select with
    | some cols => select t cols
    | none => t
  -- GROUP BY + AGG
  let t ← match args.groupBy, args.agg with
    | some gc, some a => match Sql.parseAggExpr a with
      | none => .error s!"could not parse aggregate: '{a}'"
      | some (fn, sourceCol) =>
        let g := groupBy t gc
        let resultCol := aggName fn ++ "_" ++ sourceCol
        .ok (Sql.summarizeByAgg g resultCol fn sourceCol)
    | some _, none => .error "group_by requires agg"
    | none, some _ => .error "agg requires group_by"
    | none, none => pure t
  -- ORDER BY
  let t := match args.orderBy with
    | some ob => arrange t ob
    | none => t
  -- LIMIT
  let t := match args.limit with
    | some n => head t n
    | none => t
  pure t
where
  aggName : Sql.AggFn → String
    | .count => "count" | .sum => "sum" | .avg => "avg"
    | .min => "min" | .max => "max" | .countStar => "n"

end LeanTab
