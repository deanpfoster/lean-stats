import LeanStats.Regression

/-! # LeanStats.Diagnostics — regression diagnostics and influence analysis

The JMP / Stine & Foster workflow after fitting a line:

1. **Look at residuals** — are they random? Any pattern means the
   model is missing something.
2. **Check for outliers** — large residuals relative to se.
3. **Check for influence** — high leverage + large residual = Cook's D.
4. **Check assumptions** — normality (Q-Q), constant variance,
   independence (Durbin-Watson).

This module provides all of that as pure functions over the fit.
-/

set_option autoImplicit false

namespace LeanStats

/-- Full regression diagnostics. Extends LinearFit with everything
    JMP shows in its regression report. -/
structure RegressionDiag where
  /-- The basic fit. -/
  slope : Float
  intercept : Float
  r2 : Float
  n : Nat
  /-- Standard error of the regression (root MSE). -/
  se : Float
  /-- Residuals: yᵢ - ŷᵢ -/
  residuals : Array Float
  /-- Fitted values: ŷᵢ = slope * xᵢ + intercept -/
  fitted : Array Float
  /-- Leverage (hat values): hᵢᵢ = 1/n + (xᵢ - x̄)² / SSxx -/
  leverage : Array Float
  /-- Standardized residuals: eᵢ / (se * √(1 - hᵢᵢ)) -/
  stdResiduals : Array Float
  /-- Cook's distance for each observation. -/
  cooksD : Array Float
  /-- Durbin-Watson statistic (autocorrelation check). -/
  durbinWatson : Float
  deriving Repr

/-- Compute full regression diagnostics. Returns `none` on degenerate input. -/
def regressionDiag (xs ys : Array Float) : Option RegressionDiag :=
  let n := xs.size
  if n ≠ ys.size || n < 3 then none  -- need ≥ 3 for diagnostics (df = n-2)
  else
    let mx := mean xs
    let ssxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
    if ssxx == 0 then none
    else
      -- Basic fit
      let my := mean ys
      let ssxy := (Array.zipWith xs ys (fun x y => (x - mx) * (y - my))).foldl (· + ·) 0
      let slope := ssxy / ssxx
      let intercept := my - slope * mx
      -- Fitted and residuals
      let fitted := xs.map (fun x => slope * x + intercept)
      let residuals := Array.zipWith ys fitted (· - ·)
      -- Standard error (root MSE)
      let sse := (residuals.map (· ^ 2)).foldl (· + ·) 0
      let df := (n - 2).toFloat
      let mse := sse / df
      let se := mse.sqrt
      -- R²
      let sst := (ys.map (fun y => (y - my) ^ 2)).foldl (· + ·) 0
      let r2 := if sst == 0 then 1.0 else 1.0 - sse / sst
      -- Leverage: hᵢ = 1/n + (xᵢ - x̄)² / SSxx
      let nf := n.toFloat
      let leverage := xs.map (fun x => 1.0 / nf + (x - mx) ^ 2 / ssxx)
      -- Standardized residuals
      let stdResiduals := Array.zipWith residuals leverage fun e h =>
        let denom := se * (1.0 - h).sqrt
        if denom == 0 then 0 else e / denom
      -- Cook's distance: Dᵢ = (eᵢ*)² * hᵢ / (p * (1 - hᵢ))
      -- where p = 2 (number of parameters: slope + intercept)
      let p : Float := 2.0
      let cooksD := Array.zipWith stdResiduals leverage fun sr h =>
        if h ≥ 1.0 then 0 else (sr ^ 2 * h) / (p * (1.0 - h))
      -- Durbin-Watson: Σ(eᵢ - eᵢ₋₁)² / Σeᵢ²
      let dw := if sse == 0 then 2.0  -- perfect fit
        else
          let diffs := (List.range (n - 1)).foldl (init := 0.0) fun acc i =>
            acc + (residuals[i + 1]! - residuals[i]!) ^ 2
          diffs / sse
      some {
        slope, intercept, r2, n, se,
        residuals, fitted, leverage, stdResiduals, cooksD,
        durbinWatson := dw
      }

/-- Indices of observations with Cook's D above threshold (default 4/n). -/
def influentialByCooksD (diag : RegressionDiag) (threshold : Option Float := none) : Array Nat :=
  let thresh := threshold.getD (4.0 / diag.n.toFloat)
  diag.cooksD.foldl (init := (#[], 0)) (fun (acc, i) d =>
    if d > thresh then (acc.push i, i + 1) else (acc, i + 1))
  |>.1

/-- Indices of high-leverage observations (default threshold: 2p/n = 4/n). -/
def highLeverage (diag : RegressionDiag) (threshold : Option Float := none) : Array Nat :=
  let thresh := threshold.getD (4.0 / diag.n.toFloat)
  diag.leverage.foldl (init := (#[], 0)) (fun (acc, i) h =>
    if h > thresh then (acc.push i, i + 1) else (acc, i + 1))
  |>.1

/-- Indices of outliers by standardized residual (default |sr| > 2). -/
def outliersByStdResid (diag : RegressionDiag) (threshold : Float := 2.0) : Array Nat :=
  diag.stdResiduals.foldl (init := (#[], 0)) (fun (acc, i) sr =>
    if sr > threshold || sr < -threshold then (acc.push i, i + 1) else (acc, i + 1))
  |>.1

/-- Data for residuals-vs-fitted plot. Returns (fitted, residuals) pairs. -/
def residVsFitted (diag : RegressionDiag) : Array (Float × Float) :=
  diag.fitted.zip diag.residuals

/-- Data for residuals-vs-x plot. Returns (x, residual) pairs. -/
def residVsX (xs : Array Float) (diag : RegressionDiag) : Array (Float × Float) :=
  xs.zip diag.residuals

/-- Normal Q-Q data for residuals. Returns (theoretical quantile, observed residual)
    pairs sorted by residual. Uses the normal approximation z = Φ⁻¹((i - 0.375)/(n + 0.25)). -/
def residQQ (diag : RegressionDiag) : Array (Float × Float) :=
  let sorted := diag.residuals.qsort (· < ·)
  let n := sorted.size.toFloat
  sorted.mapIdx fun i r =>
    -- Approximation to inverse normal CDF using rational approximation
    let p := (i.toFloat + 0.625) / (n + 0.25)
    let t := if p < 0.5
      then ((-2.0) * (p.log)).sqrt
      else ((-2.0) * ((1.0 - p).log)).sqrt
    -- Abramowitz & Stegun approximation 26.2.23
    let c0 := 2.515517
    let c1 := 0.802853
    let c2 := 0.010328
    let d1 := 1.432788
    let d2 := 0.189269
    let d3 := 0.001308
    let z := t - (c0 + c1 * t + c2 * t ^ 2) / (1.0 + d1 * t + d2 * t ^ 2 + d3 * t ^ 3)
    let z := if p < 0.5 then -z else z
    (z, r)

/-- Regression EDA summary — the "story" output. -/
structure RegressionSummary where
  r2 : Float
  adjR2 : Float
  se : Float
  n : Nat
  slope : Float
  intercept : Float
  durbinWatson : Float
  nOutliers : Nat
  nInfluential : Nat
  nHighLeverage : Nat
  deriving Repr

/-- Produce the EDA summary from diagnostics. -/
def regressionSummary (diag : RegressionDiag) : RegressionSummary :=
  let n := diag.n.toFloat
  let adjR2 := 1.0 - (1.0 - diag.r2) * (n - 1.0) / (n - 2.0)
  { r2 := diag.r2
    adjR2 := adjR2
    se := diag.se
    n := diag.n
    slope := diag.slope
    intercept := diag.intercept
    durbinWatson := diag.durbinWatson
    nOutliers := (outliersByStdResid diag).size
    nInfluential := (influentialByCooksD diag).size
    nHighLeverage := (highLeverage diag).size }

/-- Fitted line plot data: returns (x, y) data points plus two endpoints
    of the regression line for overlay. -/
def fittedLinePlot (xs ys : Array Float) (diag : RegressionDiag) :
    Array (Float × Float) × (Float × Float) × (Float × Float) :=
  let data := xs.zip ys
  let xmin := xs.foldl (fun a b => if a < b then a else b) (xs.getD 0 0)
  let xmax := xs.foldl (fun a b => if a > b then a else b) (xs.getD 0 0)
  let ymin := diag.slope * xmin + diag.intercept
  let ymax := diag.slope * xmax + diag.intercept
  (data, (xmin, ymin), (xmax, ymax))

end LeanStats
