import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

/-- Inner join: keep rows where key column values match in both tables.
    Result columns = t1.cols ++ t2.cols (minus duplicate key). -/
def innerJoin (t1 t2 : Table) (key : String) : Table :=
  let n1 := t1.nRows
  let k1 := t1.colData key
  let k2 := t2.colData key
  let n2 := t2.nRows
  -- Collect matched (i, j) pairs
  let pairs := Id.run do
    let mut acc : Array (Nat × Nat) := #[]
    for i in [:n1] do
      for j in [:n2] do
        if k1.getD i .na == k2.getD j .na then
          acc := acc.push (i, j)
    return acc
  -- Build result columns: all of t1, then t2 cols minus key
  let leftCols := t1.columns.map fun c =>
    { name := c.name, data := pairs.map fun (i, _) => c.data.getD i .na : Column }
  let rightCols := (t2.columns.filter (·.name != key)).map fun c =>
    { name := c.name, data := pairs.map fun (_, j) => c.data.getD j .na : Column }
  { columns := leftCols ++ rightCols }

/-- Left join: keep ALL left rows. Where no match in right, fill with .na. -/
def leftJoin (t1 t2 : Table) (key : String) : Table :=
  let n1 := t1.nRows
  let k1 := t1.colData key
  let k2 := t2.colData key
  let n2 := t2.nRows
  let rightNonKey := t2.columns.filter (·.name != key)
  -- For each left row, find matching right rows (or emit one row with NAs)
  let rows := Id.run do
    let mut acc : Array (Nat × Option Nat) := #[]
    for i in [:n1] do
      let mut matched := false
      for j in [:n2] do
        if k1.getD i .na == k2.getD j .na then
          acc := acc.push (i, some j)
          matched := true
      if !matched then
        acc := acc.push (i, none)
    return acc
  let leftCols := t1.columns.map fun c =>
    { name := c.name, data := rows.map fun (i, _) => c.data.getD i .na : Column }
  let rightCols := rightNonKey.map fun c =>
    { name := c.name, data := rows.map fun (_, j?) =>
        match j? with
        | some j => c.data.getD j .na
        | none => .na : Column }
  { columns := leftCols ++ rightCols }

/-- Cross join: every left row paired with every right row. -/
def crossJoin (t1 t2 : Table) : Table :=
  let n1 := t1.nRows
  let n2 := t2.nRows
  let pairs := Id.run do
    let mut acc : Array (Nat × Nat) := #[]
    for i in [:n1] do
      for j in [:n2] do
        acc := acc.push (i, j)
    return acc
  let leftCols := t1.columns.map fun c =>
    { name := c.name, data := pairs.map fun (i, _) => c.data.getD i .na : Column }
  let rightCols := t2.columns.map fun c =>
    { name := c.name, data := pairs.map fun (_, j) => c.data.getD j .na : Column }
  { columns := leftCols ++ rightCols }

end LeanTab
