import LeanStats.Descriptive

/-! # LeanStats.Regression — linear regression and correlation

Pure functions for ordinary-least-squares linear regression and
Pearson correlation. Manifest claims about least-squares optimality
and orthogonality live in `LeanStats/Manifests/Regression.lean`.
-/

set_option autoImplicit false

namespace LeanStats

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

structure CorTest where
  r : Float
  tStat : Float
  df : Nat
  ciLow : Float
  ciHigh : Float
  deriving Repr

/-- Test H₀: ρ=0 with CI via Fisher z-transform. Returns `none` if n < 4. -/
def correlationTest (xs ys : Array Float) : Option CorTest :=
  let n := xs.size
  if n ≠ ys.size || n < 4 then none
  else
    let r := correlation xs ys
    let df := n - 2
    let tStat := r * (Float.sqrt (df.toFloat)) / (Float.sqrt (1 - r ^ 2))
    let z := 0.5 * Float.log ((1 + r) / (1 - r))
    let se := 1.0 / Float.sqrt ((n - 3).toFloat)
    let zLow := z - 1.96 * se
    let zHigh := z + 1.96 * se
    let ciLow := (Float.exp (2 * zLow) - 1) / (Float.exp (2 * zLow) + 1)
    let ciHigh := (Float.exp (2 * zHigh) - 1) / (Float.exp (2 * zHigh) + 1)
    some { r, tStat, df, ciLow, ciHigh }

structure RegressionCI where
  slopeCI : Float × Float
  interceptCI : Float × Float
  level : Float
  deriving Repr

/-- Confidence intervals for slope and intercept (t ≈ 1.96). -/
def regressionConfInt (xs ys : Array Float) (level : Float := 0.95) : Option RegressionCI :=
  let n := xs.size
  if n ≠ ys.size || n < 3 then none
  else
    let mx := mean xs
    let sxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
    if sxx == 0 then none
    else
      match linearRegression xs ys with
      | none => none
      | some fit =>
        let sse := (Array.zipWith xs ys (fun x y =>
          let res := y - (fit.slope * x + fit.intercept); res ^ 2)).foldl (· + ·) 0
        let s := (sse / (n.toFloat - 2)).sqrt
        let t := 1.96
        let seSlope := s / sxx.sqrt
        let seIntercept := s * (1 / n.toFloat + mx ^ 2 / sxx).sqrt
        some { slopeCI := (fit.slope - t * seSlope, fit.slope + t * seSlope)
               interceptCI := (fit.intercept - t * seIntercept, fit.intercept + t * seIntercept)
               level }

/-- Confidence interval for the mean response at `xNew`. Returns (ŷ, CI_low, CI_high). -/
def predictCI (xs ys : Array Float) (xNew : Float) : Option (Float × Float × Float) :=
  let n := xs.size
  if n ≠ ys.size || n < 3 then none
  else
    let mx := mean xs
    let sxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
    if sxx == 0 then none
    else
      match linearRegression xs ys with
      | none => none
      | some fit =>
        let yhat := fit.slope * xNew + fit.intercept
        let sse := (Array.zipWith xs ys (fun x y =>
          let res := y - (fit.slope * x + fit.intercept); res ^ 2)).foldl (· + ·) 0
        let s := (sse / (n.toFloat - 2)).sqrt
        let t := 1.96
        let margin := t * s * (1 / n.toFloat + (xNew - mx) ^ 2 / sxx).sqrt
        some (yhat, yhat - margin, yhat + margin)

/-- Prediction interval for a new observation at `xNew`. Returns (ŷ, PI_low, PI_high). -/
def predictPI (xs ys : Array Float) (xNew : Float) : Option (Float × Float × Float) :=
  let n := xs.size
  if n ≠ ys.size || n < 3 then none
  else
    let mx := mean xs
    let sxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
    if sxx == 0 then none
    else
      match linearRegression xs ys with
      | none => none
      | some fit =>
        let yhat := fit.slope * xNew + fit.intercept
        let sse := (Array.zipWith xs ys (fun x y =>
          let res := y - (fit.slope * x + fit.intercept); res ^ 2)).foldl (· + ·) 0
        let s := (sse / (n.toFloat - 2)).sqrt
        let t := 1.96
        let margin := t * s * (1 + 1 / n.toFloat + (xNew - mx) ^ 2 / sxx).sqrt
        some (yhat, yhat - margin, yhat + margin)

/-- Variance Inflation Factor for predictor `idx`. VIF = 1/(1-R²) where R² is from
    regressing predictor `idx` on all other predictors. Returns 1e10 if R²=1, returns 1
    if fewer than 2 predictors. -/
def vif (xs : Array (Array Float)) (idx : Nat) : Float :=
  let p := xs.size
  if p < 2 then 1.0
  else
    let y := xs[idx]!
    let others := (Array.range p).filterMap (fun j => if j == idx then none else some xs[j]!)
    let n := y.size
    if n < 2 then 1.0
    else
      let my := mean y
      let ssTotal := (y.map (fun v => (v - my) ^ 2)).foldl (· + ·) 0
      if ssTotal == 0 then 1e10
      else
        -- Regress y on all other predictors: compute fitted values
        let fitted := Array.mkArray n 0.0
        let fitted := others.foldl (fun acc xj =>
          match linearRegression xj y with
          | some fit => acc.mapIdx (fun i v => v + fit.slope * xj[i]! + fit.intercept / (p - 1).toFloat)
          | none => acc) fitted
        let ssRes := (Array.zipWith y fitted (fun yi fi => (yi - fi) ^ 2)).foldl (· + ·) 0
        let r2 := 1.0 - ssRes / ssTotal
        if r2 >= 1.0 then 1e10
        else 1.0 / (1.0 - r2)

/-- VIF for every predictor. -/
def vifAll (xs : Array (Array Float)) : Array Float :=
  (Array.range xs.size).map (fun i => vif xs i)

end LeanStats
