import LeanStats.Descriptive
set_option autoImplicit false
namespace LeanStats

def chiSquaredTest (observed : Array (Array Nat)) : Float × Nat :=
  let rows := observed.size
  let cols := if h : rows > 0 then (observed[0]'h).size else 0
  let rowSums := observed.map (·.foldl (· + ·) 0)
  let colSums := Id.run do
    let mut cs := Array.mkArray cols 0
    for row in observed do
      for j in [:row.size] do
        cs := cs.set! j (cs[j]! + row[j]!)
    cs
  let total := rowSums.foldl (· + ·) 0
  let tf := total.toFloat
  let chi2 := Id.run do
    let mut s : Float := 0.0
    for i in [:rows] do
      for j in [:cols] do
        let expected := rowSums[i]!.toFloat * colSums[j]!.toFloat / tf
        if expected > 0.0 then
          let diff := (observed[i]![j]!).toFloat - expected
          s := s + diff * diff / expected
    s
  let df := (rows - 1) * (cols - 1)
  (chi2, df)

def propTestOne (successes : Nat) (n : Nat) (p0 : Float := 0.5) : Float :=
  let pHat := successes.toFloat / n.toFloat
  let se := Float.sqrt (p0 * (1.0 - p0) / n.toFloat)
  if se == 0.0 then 0.0 else (pHat - p0) / se

def propTestTwo (s1 n1 s2 n2 : Nat) : Float :=
  let p1 := s1.toFloat / n1.toFloat
  let p2 := s2.toFloat / n2.toFloat
  let pPool := (s1 + s2).toFloat / (n1 + n2).toFloat
  let se := Float.sqrt (pPool * (1.0 - pPool) * (1.0 / n1.toFloat + 1.0 / n2.toFloat))
  if se == 0.0 then 0.0 else (p1 - p2) / se

def crossTab (xs ys : Array String) : Array String × Array String × Array (Array Nat) :=
  let rowLabels := xs.foldl (fun acc x => if acc.contains x then acc else acc.push x) #[]
  let colLabels := ys.foldl (fun acc y => if acc.contains y then acc else acc.push y) #[]
  let mat := Id.run do
    let mut m := Array.mkArray rowLabels.size (Array.mkArray colLabels.size 0)
    for idx in [:xs.size] do
      let x := xs[idx]!
      let y := ys[idx]!
      match rowLabels.indexOf? x, colLabels.indexOf? y with
      | some ri, some ci =>
        let row := m[ri.val]!
        m := m.set! ri.val (row.set! ci.val (row[ci.val]! + 1))
      | _, _ => pure ()
    m
  (rowLabels, colLabels, mat)

end LeanStats
