import LeanTab.Reshape
import LeanStats.Diagnostics
import LeanStats.Transform
import LeanStats.Tests

/-! # LeanTab.Stats — bridge from Table to LeanStats

Connects the Table type to LeanStats functions. This is the glue
that lets you do:

```lean
let t := loadCsv "data.csv"  -- (done by the agent, not this library)
let fit := t.regress "y" "x"
let diag := t.regressDiag "y" "x"
let summary := t.describe "age"
```

When `lean-tab` is extracted as its own library, this file becomes
a separate `lean-tab-stats` bridge package that depends on both.
-/

set_option autoImplicit false

namespace LeanTab
open LeanStats Table

/-- Descriptive summary of a numeric column. -/
def Table.describe (t : Table) (colName : String) : LeanStats.Summary :=
  LeanStats.summary (t.colFloats colName)

/-- Mean of a numeric column. -/
def Table.colMean (t : Table) (colName : String) : Float :=
  LeanStats.mean (t.colFloats colName)

/-- Standard deviation of a numeric column. -/
def Table.colSd (t : Table) (colName : String) : Float :=
  LeanStats.stdDev (t.colFloats colName)

/-- Correlation between two numeric columns. -/
def Table.corr (t : Table) (col1 col2 : String) : Float :=
  LeanStats.correlation (t.colFloats col1) (t.colFloats col2)

/-- Linear regression: response ~ predictor. -/
def Table.regress (t : Table) (response predictor : String) : Option LeanStats.LinearFit :=
  LeanStats.linearRegression (t.colFloats predictor) (t.colFloats response)

/-- Full regression diagnostics: response ~ predictor. -/
def Table.regressDiag (t : Table) (response predictor : String) : Option LeanStats.RegressionDiag :=
  LeanStats.regressionDiag (t.colFloats predictor) (t.colFloats response)

/-- One-sample t-test on a column. -/
def Table.tTest (t : Table) (colName : String) (μ₀ : Float := 0) : Float :=
  LeanStats.tTestOneSample (t.colFloats colName) μ₀

/-- Two-sample t-test between groups defined by a factor column.
    Uses the first two distinct values of `groupCol` as the two groups. -/
def Table.tTest2 (t : Table) (valueCol groupCol : String) : Float :=
  let groups := t.colData groupCol
  let values := t.colFloats valueCol
  let keys : Array Cell := groups.foldl (init := #[]) fun acc c =>
    if acc.contains c then acc else acc.push c
  if keys.size < 2 then 0
  else
    let g1 := (Array.range t.nRows).filterMap fun i =>
      if groups.getD i .na == keys[0]! then some (values.getD i 0) else none
    let g2 := (Array.range t.nRows).filterMap fun i =>
      if groups.getD i .na == keys[1]! then some (values.getD i 0) else none
    LeanStats.tTestTwoSample g1 g2

/-- Apply a transform to a column, returning a new column name. -/
def Table.transform (t : Table) (colName : String) (kind : LeanStats.TransformKind)
    (newName : Option String := none) : Table :=
  let xs := t.colFloats colName
  let transformed := LeanStats.applyTransform xs kind
  let outName := newName.getD (colName ++ "_" ++ reprStr kind)
  mutate t outName (fun row =>
    let i := 0  -- This is a simplification; proper impl needs row index
    .na)
  -- Better: directly build the column
  |> fun _ =>
    let newCol : Column := { name := outName, data := transformed.map .float }
    { columns := t.columns.push newCol }

/-- Find the best response transform for a regression. -/
def Table.bestTransform (t : Table) (response predictor : String) :
    LeanStats.TransformKind × Float :=
  LeanStats.bestResponseTransform (t.colFloats predictor) (t.colFloats response)

end LeanTab
