import LeanTab.Table

set_option autoImplicit false

namespace LeanTab
open Table

/-- Count .na values in an array of cells. -/
def countNa (xs : Array Cell) : Nat :=
  xs.foldl (init := 0) fun acc c =>
    match c with | .na => acc + 1 | _ => acc

/-- Remove rows where the named column is .na. -/
def dropNa (t : Table) (col : String) : Table :=
  let data := t.colData col
  let kept := (Array.range t.nRows).filter fun i =>
    match data.getD i .na with | .na => false | _ => true
  { columns := t.columns.map fun c =>
      { c with data := kept.map fun i => c.data.getD i .na } }

/-- Replace .na with last non-na value. Leading NAs stay. -/
def fillForward (xs : Array Cell) : Array Cell :=
  let r := xs.foldl (init := (Array.mkEmpty xs.size, Cell.na)) fun acc c =>
    let arr := acc.1
    let last := acc.2
    match c with
    | .na => match last with
      | .na => (arr.push .na, last)
      | _ => (arr.push last, last)
    | _ => (arr.push c, c)
  r.1

/-- Replace .na with next non-na value. Trailing NAs stay. -/
def fillBackward (xs : Array Cell) : Array Cell :=
  let n := xs.size
  let r := (Array.range n).foldr (init := (Array.mkEmpty n, Cell.na)) fun i acc =>
    let arr := acc.1
    let next := acc.2
    let c := xs.getD i .na
    match c with
    | .na => match next with
      | .na => (arr.push .na, next)
      | _ => (arr.push next, next)
    | _ => (arr.push c, c)
  r.1.reverse

/-- Replace all .na in the named column with val. -/
def replaceNa (t : Table) (col : String) (val : Cell) : Table :=
  { columns := t.columns.map fun c =>
      if c.name == col then
        { c with data := c.data.map fun cell =>
            match cell with | .na => val | _ => cell }
      else c }

end LeanTab
