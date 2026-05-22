import LeanTab.Summarize
import LeanTab.Pretty
import LeanTab.Verbs
import LeanTab.GroupBy
import LeanTab.Query
set_option autoImplicit false
namespace LeanTab

structure TwoEyedResult where
  table : Table
  humanView : String
  llmView : String
  description : String
  deriving Repr

def twoEyedFilter (t : Table) (cond : String) : Except String TwoEyedResult := do
  let expr ← match Sql.parseExpr cond with
    | some e => pure e
    | none => .error s!"could not parse condition: '{cond}'"
  let result := Sql.filterByExpr t expr
  .ok {
    table := result
    humanView := prettyPrint result 10
    llmView := tableSummary result 400
    description := s!"filtered to {result.nRows} rows where {cond}"
  }

def twoEyedSelect (t : Table) (cols : Array String) : TwoEyedResult :=
  let result := select t cols
  {
    table := result
    humanView := prettyPrint result 10
    llmView := tableSummary result 400
    description := s!"selected {cols.size} columns"
  }

def twoEyedQuery (t : Table) (args : QueryArgs) : Except String TwoEyedResult := do
  let result ← runQuery t args
  .ok {
    table := result
    humanView := prettyPrint result 10
    llmView := tableSummary result 400
    description := s!"query returned {result.nRows} rows"
  }

def twoEyedGroupCount (t : Table) (col : String) : TwoEyedResult :=
  let result := count t col
  {
    table := result
    humanView := prettyPrint result 10
    llmView := tableSummary result 400
    description := s!"{result.nRows} groups by {col}"
  }

end LeanTab
