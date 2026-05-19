import LeanStats.Diagnostics
import LeanStats.Descriptive

/-! # LeanStats.Plot.Describe — text summaries of plots for LLM consumption

When a plot is shown to the user, the LLM needs a text description
to reason about what it shows. This module produces structured
summaries that answer:

- What type of plot?
- What are the axes (name, range)?
- How many points?
- What patterns are visible (trend, outliers, clusters)?

Output is a compact structured string (not JSON — just key: value lines)
that fits in ~200-400 characters. The LLM reads this instead of pixels.
-/

set_option autoImplicit false

namespace LeanStats.Plot

/-- Description of a scatter plot. -/
structure ScatterDesc where
  n : Nat
  xName : String
  xMin : Float
  xMax : Float
  xDistinct : Nat
  yName : String
  yMin : Float
  yMax : Float
  nMissing : Nat := 0
  correlation : Float
  slope : Option Float := none
  intercept : Option Float := none
  r2 : Option Float := none
  shape : String := ""
  maxResidSigma : Option Float := none
  curvature : Option Float := none  -- coefficient of (x - x̄)² in residuals
  nOutliers : Nat := 0
  deriving Repr

/-- Describe a scatter plot from raw data. -/
def describeScatter (xs ys : Array Float)
    (xName : String := "x") (yName : String := "y") : ScatterDesc :=
  let n := xs.size
  let xMin := xs.foldl (fun a b => if b < a then b else a) (xs.getD 0 0)
  let xMax := xs.foldl (fun a b => if b > a then b else a) (xs.getD 0 0)
  let yMin := ys.foldl (fun a b => if b < a then b else a) (ys.getD 0 0)
  let yMax := ys.foldl (fun a b => if b > a then b else a) (ys.getD 0 0)
  -- Distinct x values
  let xDistinct := (xs.foldl (init := (#[] : Array Float)) fun acc v =>
    if acc.contains v then acc else acc.push v).size
  let r := LeanStats.correlation xs ys
  -- OLS fit
  -- OLS fit + curvature
  let diagResult := LeanStats.regressionDiag xs ys
  let slope := diagResult.map (·.slope)
  let intercept := diagResult.map (·.intercept)
  let r2 := diagResult.map (·.r2)
  let maxResidSigma := diagResult.map fun d =>
    d.stdResiduals.foldl (fun a b => if b.abs > a then b.abs else a) 0
  let nOutliers := match diagResult with
    | some d => (LeanStats.outliersByStdResid d).size
    | none => 0
  -- Curvature: regress residuals on (x - x̄)²
  let curvature := match diagResult with
    | some d =>
      let mx := LeanStats.mean xs
      let xc2 := xs.map (fun x => (x - mx) ^ 2)
      match LeanStats.linearRegression xc2 d.residuals with
      | some fit => some fit.slope
      | none => none
    | none => none
  -- Shape description
  let shape :=
    let dir := if r > 0.3 then "increasing" else if r < -0.3 then "decreasing" else "no trend"
    let lin := if r.abs > 0.95 then "near-linear"
      else if r.abs > 0.7 then "moderate linear"
      else if r.abs > 0.3 then "weak linear"
      else "no linear relationship"
    let curvNote := match curvature with
      | some c => if c.abs > 0.01 then s!"; curvature detected" else ""
      | none => ""
    let outlierNote := if nOutliers > 0 then s!"; {nOutliers} outliers"
      else match maxResidSigma with
        | some m => s!"; no outliers (max |resid| = {fmtF m 2}σ)"
        | none => ""
    s!"monotone {dir}, {lin}{curvNote}{outlierNote}"
  { n, xName, xMin, xMax, xDistinct, yName, yMin, yMax,
    correlation := r, slope, intercept, r2, shape, maxResidSigma, curvature, nOutliers }
where
  fmtF (f : Float) (decimals : Nat) : String :=
    let factor := (10 ^ decimals).toFloat
    toString (Float.round (f * factor) / factor)

/-- Render a scatter description to text. -/
def ScatterDesc.render (d : ScatterDesc) : String :=
  let olsLine := match d.slope, d.intercept, d.r2 with
    | some s, some i, some r2 =>
      let sign := if i ≥ 0 then "+" else ""
      s!"ols: {d.yName} = {s}·{d.xName} {sign} {i} (R² = {r2})\n"
    | _, _, _ => ""
  let curvLine := match d.curvature with
    | some c => if c.abs > 0.001 then s!"curvature: {c} · ({d.xName} - x̄)²\n" else ""
    | none => ""
  s!"chart: scatter\n" ++
  s!"x: {d.xName} ∈ [{d.xMin}, {d.xMax}], {d.xDistinct} distinct values\n" ++
  s!"y: {d.yName} ∈ [{d.yMin}, {d.yMax}]\n" ++
  s!"n: {d.n} (0 clipped, {d.nMissing} missing)\n" ++
  s!"pearson_r: {d.correlation}\n" ++
  olsLine ++ curvLine ++
  s!"shape: {d.shape}"

/-- Description of a histogram. -/
structure HistogramDesc where
  n : Nat
  varName : String
  min : Float
  max : Float
  mean : Float
  sd : Float
  skew : String  -- "left", "right", "symmetric"
  nBins : Nat
  modeBin : String  -- range of the tallest bin
  deriving Repr

/-- Describe a histogram from raw data. -/
def describeHistogram (data : Array Float) (varName : String := "x")
    (bins : Nat := 10) : HistogramDesc :=
  let n := data.size
  let mn := data.foldl (fun a b => if b < a then b else a) (data.getD 0 0)
  let mx := data.foldl (fun a b => if b > a then b else a) (data.getD 0 0)
  let avg := LeanStats.mean data
  let sd := LeanStats.stdDev data
  let med := LeanStats.median data
  let skew := if avg > med + 0.2 * sd then "right"
    else if avg < med - 0.2 * sd then "left"
    else "symmetric"
  -- Find mode bin
  let range := if mx == mn then 1.0 else mx - mn
  let binWidth := range / bins.toFloat
  let counts := data.foldl (init := Array.mkArray bins 0) fun acc v =>
    let idx := ((v - mn) / binWidth).toUInt64.toNat
    let idx := if idx >= bins then bins - 1 else idx
    acc.set! idx (acc.getD idx 0 + 1)
  let modeIdx := counts.foldl (init := (0, 0, 0)) fun (best, bestI, i) c =>
    if c > best then (c, i, i + 1) else (best, bestI, i + 1)
  let modeLo := mn + modeIdx.2.1.toFloat * binWidth
  let modeHi := modeLo + binWidth
  { n, varName, min := mn, max := mx, mean := avg, sd,
    skew, nBins := bins, modeBin := s!"[{modeLo}, {modeHi}]" }

/-- Render a histogram description to text. -/
def HistogramDesc.render (d : HistogramDesc) : String :=
  s!"histogram: {d.n} values, {d.nBins} bins\n" ++
  s!"var: {d.varName} [{d.min}, {d.max}]\n" ++
  s!"mean: {d.mean}, sd: {d.sd}\n" ++
  s!"shape: {d.skew}, mode bin: {d.modeBin}"

/-- Description of a regression diagnostic plot set. -/
structure DiagDesc where
  n : Nat
  r2 : Float
  se : Float
  slope : Float
  intercept : Float
  durbinWatson : Float
  nOutliers : Nat
  nInfluential : Nat
  residPattern : String  -- "random", "funnel", "curved", "clustered"
  deriving Repr

/-- Describe regression diagnostics. -/
def describeDiag (diag : LeanStats.RegressionDiag) : DiagDesc :=
  let nOut := (LeanStats.outliersByStdResid diag).size
  let nInf := (LeanStats.influentialByCooksD diag).size
  -- Simple pattern detection from residuals
  let resid := diag.residuals
  let n := resid.size
  -- Check if variance increases with fitted (funnel)
  let half := n / 2
  let firstHalf := resid.extract 0 half
  let secondHalf := resid.extract half n
  let var1 := LeanStats.variance firstHalf
  let var2 := LeanStats.variance secondHalf
  let pattern := if var2 > var1 * 2 then "funnel"
    else if diag.durbinWatson < 1.5 || diag.durbinWatson > 2.5 then "autocorrelated"
    else "random"
  { n := diag.n, r2 := diag.r2, se := diag.se,
    slope := diag.slope, intercept := diag.intercept,
    durbinWatson := diag.durbinWatson,
    nOutliers := nOut, nInfluential := nInf,
    residPattern := pattern }

/-- Render diagnostics description to text. -/
def DiagDesc.render (d : DiagDesc) : String :=
  s!"regression: {d.n} obs, y = {d.slope}·x + {d.intercept}\n" ++
  s!"R²: {d.r2}, se: {d.se}\n" ++
  s!"residuals: {d.residPattern}, DW: {d.durbinWatson}\n" ++
  s!"outliers: {d.nOutliers}, influential: {d.nInfluential}"

end LeanStats.Plot
