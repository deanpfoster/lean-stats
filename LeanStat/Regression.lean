import LeanStat.Descriptive

/-! # LeanStat.Regression — linear regression and correlation

Pure functions for ordinary-least-squares linear regression and
Pearson correlation. Manifest claims about least-squares optimality
and orthogonality live in `LeanStat/Manifests/Regression.lean`.
-/

set_option autoImplicit false

namespace LeanStat

structure LinearFit where
  slope : Float
  intercept : Float
  r2 : Float
  n : Nat
  deriving Repr

/-- Pearson correlation coefficient. -/
def correlation (xs ys : Array Float) : Float :=
  let n := xs.size
  if n ≠ ys.size || n < 2 then 0
  else
    let mx := mean xs
    let my := mean ys
    let num := (Array.zipWith xs ys (fun x y => (x - mx) * (y - my))).foldl (· + ·) 0
    let dx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
    let dy := (ys.map (fun y => (y - my) ^ 2)).foldl (· + ·) 0
    let denom := (dx * dy).sqrt
    if denom == 0 then 0 else num / denom

/-- Ordinary least squares linear regression. Returns `none` if the
    inputs are degenerate (different sizes, < 2 points, or no
    variation in `xs`). -/
def linearRegression (xs ys : Array Float) : Option LinearFit :=
  let n := xs.size
  if n ≠ ys.size || n < 2 then none
  else
    let mx := mean xs
    let my := mean ys
    let ssxy := (Array.zipWith xs ys (fun x y => (x - mx) * (y - my))).foldl (· + ·) 0
    let ssxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
    if ssxx == 0 then none
    else
      let slope := ssxy / ssxx
      let intercept := my - slope * mx
      let r := correlation xs ys
      some { slope, intercept, r2 := r ^ 2, n }

end LeanStat
