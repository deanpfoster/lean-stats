import LeanStats.Descriptive
set_option autoImplicit false
namespace LeanStats

structure AnovaResult where
  fStat : Float
  dfBetween : Nat
  dfWithin : Nat
  ssBetween : Float
  ssWithin : Float
  msBetween : Float
  msWithin : Float
  grandMean : Float
  groupMeans : Array Float
  groupNs : Array Nat
  deriving Repr

def oneWayAnova (groups : Array (Array Float)) : Option AnovaResult :=
  if groups.size < 2 then none
  else if groups.any (·.isEmpty) then none
  else
    let ns := groups.map (·.size)
    let n := ns.foldl (· + ·) 0
    let means := groups.map mean
    let gm := (groups.foldl (fun acc g => acc + g.foldl (· + ·) 0) 0) / n.toFloat
    let ssBetween := (ns.zip means).foldl (fun acc (ni, mi) =>
      acc + ni.toFloat * (mi - gm) * (mi - gm)) 0
    let ssWithin := (groups.zip means).foldl (fun acc (g, mi) =>
      acc + g.foldl (fun a x => a + (x - mi) * (x - mi)) 0) 0
    let k := groups.size
    let dfB := k - 1
    let dfW := n - k
    if dfW == 0 then none
    else
      let msB := ssBetween / dfB.toFloat
      let msW := ssWithin / dfW.toFloat
      let f := if msW == 0 then 0 else msB / msW
      some { fStat := f, dfBetween := dfB, dfWithin := dfW,
             ssBetween := ssBetween, ssWithin := ssWithin,
             msBetween := msB, msWithin := msW,
             grandMean := gm, groupMeans := means, groupNs := ns }

def tukeyHSD (groups : Array (Array Float)) (_level : Float := 0.95) : Array (Nat × Nat × Float × Bool) :=
  match oneWayAnova groups with
  | none => #[]
  | some res =>
    let q := 2.8
    let msW := res.msWithin
    Id.run do
      let mut results : Array (Nat × Nat × Float × Bool) := #[]
      for i in [:groups.size] do
        for j in [i+1:groups.size] do
          let diff := res.groupMeans[i]! - res.groupMeans[j]!
          let ni := res.groupNs[i]!.toFloat
          let nj := res.groupNs[j]!.toFloat
          let se := Float.sqrt (msW * (1/ni + 1/nj) / 2)
          let crit := q * se
          results := results.push (i, j, diff, diff.abs > crit)
      return results

end LeanStats
