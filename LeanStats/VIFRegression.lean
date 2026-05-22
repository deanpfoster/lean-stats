import LeanStats.Descriptive
import LeanStats.Regression
import LeanStats.LinAlg

/-! # LeanStats.VIFRegression — VIF-Regression (Lin, Foster, Ungar 2011)

A fast streaming feature selection algorithm that uses the Variance
Inflation Factor as its test statistic, combined with alpha-investing
for mFDR control.

Reference: Dongyu Lin, Dean P. Foster, and Lyle H. Ungar (2011).
"VIF-Regression: A Fast Regression Algorithm for Large Data."
Journal of the American Statistical Association, 106(493): 232-247.

Key properties:
- One-pass over predictors (streaming)
- Uses subsample to approximate VIF (fast for large n)
- Controls marginal false discovery rate via alpha-investing
- Two modes: "dense" (many signals expected) and "sparse" (few signals)
-/

set_option autoImplicit false

namespace LeanStats

/-- Mode for alpha-investing wealth management. -/
inductive VIFMode where
  /-- Dense: expects many signals. Invests more aggressively. -/
  | dense
  /-- Sparse: expects few signals. Conservative investment. -/
  | sparse
  deriving Repr, BEq

/-- Configuration for VIF-Regression. -/
structure VIFConfig where
  /-- Initial alpha wealth. -/
  w0 : Float := 0.05
  /-- Incremental wealth gained when a variable is accepted. -/
  dw : Float := 0.05
  /-- Subsample size for VIF approximation. -/
  subsize : Nat := 200
  /-- Dense or sparse mode. -/
  mode : VIFMode := .sparse
  deriving Repr

/-- Result of VIF-Regression. -/
structure VIFResult where
  /-- Indices of selected variables. -/
  selected : Array Nat
  /-- For each candidate: (index, t-stat, p-value, accepted, wealth-after). -/
  trace : Array (Nat × Float × Float × Bool × Float)
  /-- Final alpha wealth remaining. -/
  finalWealth : Float
  deriving Repr

/-- Compute the t-statistic for adding predictor `xNew` to a model
    that already contains predictors `xIn`. Uses the VIF-adjusted
    test: t = correlation(residuals, xNew) * sqrt(n-p-1) / sqrt(1 - r²).
    The VIF adjustment accounts for collinearity with existing predictors. -/
private def vifTStat (y : Array Float) (xIn : Array (Array Float)) (xNew : Array Float)
    (subsize : Nat) : Float × Float :=
  let n := y.size
  -- Subsample for speed (use first `subsize` observations if n > subsize)
  let ss := Nat.min subsize n
  let ySub := y.extract 0 ss
  let xNewSub := xNew.extract 0 ss
  let xInSub := xIn.map (·.extract 0 ss)
  -- Compute residuals of y on xIn (or just y if xIn is empty)
  let residY := if xInSub.isEmpty then ySub
    else
      -- Simple: regress y on xIn via normal equations
      let p := xInSub.size
      let designRows := (Array.range ss).map fun i =>
        #[1.0] ++ xInSub.map (·.getD i 0)
      let X := LinAlg.Matrix.fromRows designRows
      match LinAlg.ols X ySub with
      | some beta => LinAlg.residuals X ySub beta
      | none => ySub
  -- Compute residuals of xNew on xIn
  let residX := if xInSub.isEmpty then xNewSub
    else
      let designRows := (Array.range ss).map fun i =>
        #[1.0] ++ xInSub.map (·.getD i 0)
      let X := LinAlg.Matrix.fromRows designRows
      match LinAlg.ols X xNewSub with
      | some beta => LinAlg.residuals X xNewSub beta
      | none => xNewSub
  -- Correlation between residuals
  let r := correlation residY residX
  -- t-statistic: r * sqrt(n - p - 1) / sqrt(1 - r²)
  let p := xInSub.size.toFloat
  let df := ss.toFloat - p - 2.0
  let t := if (1.0 - r^2) ≤ 0 then 0
    else r * df.sqrt / (1.0 - r^2).sqrt
  -- Approximate p-value (two-sided, normal approximation)
  let z := t.abs
  let pval := if z > 8 then 0.0
    else if z < 0.001 then 1.0
    else
      let tt := 1.0 / (1.0 + 0.3275911 * z)
      let poly := ((((1.061405429 * tt - 1.453152027) * tt + 1.421413741) * tt - 0.284496736) * tt + 0.254829592) * tt
      2.0 * poly * Float.exp (-z^2 / 2)
  (t, pval)

/-- VIF-Regression: streaming feature selection with VIF-based testing
    and alpha-investing for mFDR control.

    y: response variable
    xs: array of candidate predictors (tested in order)
    config: algorithm parameters -/
def vifRegression (y : Array Float) (xs : Array (Array Float))
    (config : VIFConfig := {}) : VIFResult := Id.run do
  let mut wealth := config.w0
  let mut selected : Array Nat := #[]
  let mut trace : Array (Nat × Float × Float × Bool × Float) := #[]

  for idx in List.range xs.size do
    let xNew := xs.getD idx #[]
    if xNew.size != y.size then continue

    -- Compute alpha threshold for this test
    let threshold := match config.mode with
      | .sparse => wealth / (xs.size - idx).toFloat  -- spread remaining wealth
      | .dense => wealth / 2.0  -- invest half each time

    if threshold ≤ 0 then
      trace := trace.push (idx, 0, 1, false, wealth)
      continue

    -- Get the currently selected predictors
    let xIn := selected.map (xs.getD · #[])

    -- Compute VIF-adjusted t-statistic
    let (tStat, pval) := vifTStat y xIn xNew config.subsize

    -- Decision
    let accept := pval < threshold
    if accept then
      selected := selected.push idx
      wealth := wealth + config.dw  -- earn reward
    else
      wealth := wealth - threshold  -- pay cost

    trace := trace.push (idx, tStat, pval, accept, wealth)

  return { selected, trace, finalWealth := wealth }

/-- Render VIF-Regression results as human-readable text. -/
def VIFResult.render (result : VIFResult) (varNames : Option (Array String) := none) : String :=
  let header := s!"VIF-Regression: {result.selected.size} variables selected, final wealth = {result.finalWealth}\n"
  let lines := result.trace.toList.map fun (idx, t, p, acc, w) =>
    let name := match varNames with
      | some names => names.getD idx s!"x{idx}"
      | none => s!"x{idx}"
    let status := if acc then "✓" else " "
    s!"  {status} {name}: t={t}, p={p}, wealth→{w}"
  header ++ String.intercalate "\n" lines

end LeanStats
