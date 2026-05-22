import LeanStats.Regression
import LeanStats.Descriptive

/-! # LeanStats.AlphaInvesting — streaming feature selection with pluggable standard errors

Alpha-investing (Foster & Stine 2008): sequential variable selection
that controls mFDR by managing an "alpha wealth" budget. Each test
costs alpha; rejections earn alpha back.

The SE computation is abstract — plug in:
- Classical OLS standard errors
- White (heteroscedasticity-consistent) standard errors
- Liang-Zeger (cluster/block) standard errors
- Bennett-bound p-values for binary outcomes

## Architecture

```
AlphaInvesting
  ├── SEMethod (pluggable: how to compute SE and p-values)
  ├── AlphaWealth (the budget tracker)
  └── StepResult (what happened at each step)
```
-/

set_option autoImplicit false

namespace LeanStats

-- ════════════════════════════════════════════════════════════
-- § Standard error methods (pluggable)
-- ════════════════════════════════════════════════════════════

/-- How to compute the standard error of a regression coefficient.
    Each method takes: xs (predictor), ys (response), residuals, fitted values.
    Returns: (SE of slope, t-statistic, p-value approximation). -/
inductive SEMethod where
  /-- Classical OLS: SE = s / √Sxx. Assumes homoscedastic, independent errors. -/
  | classical
  /-- White (HC1): heteroscedasticity-consistent. SE = √(Σ eᵢ²xᵢ² / Sxx²) × n/(n-2). -/
  | white
  /-- Liang-Zeger cluster: block-based. Groups defined by cluster IDs.
      SE accounts for within-cluster correlation. -/
  | cluster (clusterIds : Array Nat)
  /-- Bennett bound: for binary Y, uses concentration inequality for bounded
      random variables. More conservative but valid without normality. -/
  | bennett
  deriving Repr

/-- Result of computing SE for one coefficient. -/
structure SEResult where
  se : Float
  tStat : Float
  pValue : Float  -- approximate (two-sided)
  deriving Repr

/-- Approximate two-sided p-value from t-statistic and df.
    Uses normal approximation for large df. -/
private def approxPValue (t : Float) (df : Nat) : Float :=
  let z := t.abs
  if z < 0.001 then 1.0
  else if z > 8 then 0.0
  else
    let p := 0.3275911
    let a := #[0.254829592, -0.284496736, 1.421413741, -1.453152027, 1.061405429]
    let tt := 1.0 / (1.0 + p * z)
    let poly := a.foldl (fun acc ai => acc * tt + ai) 0 * tt
    let phi := poly * Float.exp (-z ^ 2 / 2)
    let result := 2 * phi
    if result > 1.0 then 1.0 else result

/-- Compute SE using the specified method. -/
def computeSE (method : SEMethod) (xs : Array Float) (residuals : Array Float)
    (slope : Float) : SEResult :=
  let n := xs.size.toFloat
  let mx := mean xs
  let sxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
  if sxx == 0 then { se := 0, tStat := 0, pValue := 1 }
  else match method with
  | .classical =>
    let sse := (residuals.map (· ^ 2)).foldl (· + ·) 0
    let s2 := sse / (n - 2)
    let se := (s2 / sxx).sqrt
    let t := if se == 0 then 0 else slope / se
    let p := approxPValue t (xs.size - 2)
    { se, tStat := t, pValue := p }
  | .white =>
    -- HC1: Σ(eᵢ² × (xᵢ - x̄)²) / Sxx² × n/(n-2)
    let hc := (Array.zipWith residuals xs (fun e x => e ^ 2 * (x - mx) ^ 2)).foldl (· + ·) 0
    let se := (hc / (sxx ^ 2) * n / (n - 2)).sqrt
    let t := if se == 0 then 0 else slope / se
    let p := approxPValue t (xs.size - 2)
    { se, tStat := t, pValue := p }
  | .cluster clusterIds =>
    -- Liang-Zeger: group residuals by cluster, sum within cluster, then variance
    let nClusters := (clusterIds.foldl (fun mx c => Nat.max mx c) 0) + 1
    -- Compute cluster-level scores: Σⱼ∈cluster eⱼ(xⱼ - x̄)
    let clusterScores := (Array.range nClusters).map fun c =>
      let indices := (Array.range xs.size).filter fun i => clusterIds.getD i 0 == c
      indices.foldl (fun acc i =>
        acc + (residuals.getD i 0) * (xs.getD i 0 - mx)) 0
    let meat := (clusterScores.map (· ^ 2)).foldl (· + ·) 0
    let se := (meat / (sxx ^ 2)).sqrt
    let t := if se == 0 then 0 else slope / se
    let p := approxPValue t (nClusters - 1)  -- df = number of clusters - 1
    { se, tStat := t, pValue := p }
  | .bennett =>
    -- Bennett bound for binary Y: more conservative p-value
    -- Uses the fact that Y ∈ {0,1} so residuals are bounded
    let sse := (residuals.map (· ^ 2)).foldl (· + ·) 0
    let s2 := sse / (n - 2)
    let se := (s2 / sxx).sqrt
    let t := if se == 0 then 0 else slope / se
    -- Bennett: p ≈ exp(-n × h(t²/n)) where h(u) = (1+u)log(1+u) - u
    -- For moderate t, this is more conservative than normal approximation
    let u := t ^ 2 / n
    let bennettH := (1 + u) * (1 + u).log - u
    let p := Float.exp (-n * bennettH / 2)  -- one-sided, double for two-sided
    let p := let raw := 2 * p; if raw > 1.0 then 1.0 else raw
    { se, tStat := t, pValue := p }

-- (approxPValue moved above computeSE)

-- ════════════════════════════════════════════════════════════
-- § Alpha-investing stepwise
-- ════════════════════════════════════════════════════════════

/-- Configuration for alpha-investing. -/
structure AlphaConfig where
  /-- Initial alpha wealth (total budget for false discoveries). -/
  initialWealth : Float := 0.05
  /-- How much alpha to spend on each test. -/
  testCost : Float := 0.005
  /-- How much alpha to earn back on a rejection. -/
  rejectReward : Float := 0.005
  /-- SE method to use for p-values. -/
  seMethod : SEMethod := .white
  deriving Repr

/-- Result of one step in the alpha-investing process. -/
structure StepResult where
  /-- Variable name. -/
  varName : String
  /-- The SE result (t-stat, p-value). -/
  seResult : SEResult
  /-- Was this variable accepted (rejected H₀)? -/
  accepted : Bool
  /-- Alpha threshold used for this test. -/
  threshold : Float
  /-- Alpha wealth after this step. -/
  wealthAfter : Float
  deriving Repr

/-- State of the alpha-investing process. -/
structure AlphaState where
  /-- Current alpha wealth. -/
  wealth : Float
  /-- Variables currently in the model (indices into candidates). -/
  inModel : Array Nat
  /-- History of steps taken. -/
  history : Array StepResult
  deriving Repr

/-- Run alpha-investing stepwise on a set of candidate predictors.
    Returns the final state with accepted variables and step history.

    ys: response variable
    candidates: array of (name, values) pairs to test sequentially
    config: alpha-investing parameters -/
def alphaInvesting (ys : Array Float) (candidates : Array (String × Array Float))
    (config : AlphaConfig := {}) : AlphaState :=
  let n := ys.size
  candidates.foldl (init := { wealth := config.initialWealth, inModel := #[], history := #[] })
    fun state (vname, xs) =>
      if state.wealth < config.testCost then
        let sr : SEResult := ⟨0, 0, 1⟩
        let step : StepResult := ⟨vname, sr, false, 0, state.wealth⟩
        { state with history := state.history.push step }
      else
        -- Compute the threshold for this test
        let threshold := config.testCost
        -- Compute residuals from current model (simple: just use Y - mean for now)
        -- TODO: proper residuals from current model with all accepted vars
        let my := mean ys
        let residuals := ys.map (· - my)
        -- Compute slope of xs on residuals
        let mx := mean xs
        let sxx := (xs.map (fun x => (x - mx) ^ 2)).foldl (· + ·) 0
        let sxy := (Array.zipWith xs residuals (fun x r => (x - mx) * r)).foldl (· + ·) 0
        let slope := if sxx == 0 then 0 else sxy / sxx
        -- Compute residuals from this fit
        let fitResid := Array.zipWith residuals xs (fun r x => r - slope * (x - mx))
        -- Get SE and p-value
        let seResult := computeSE config.seMethod xs fitResid slope
        -- Decision
        let accepted := seResult.pValue < threshold
        let newWealth := if accepted
          then state.wealth - config.testCost + config.rejectReward
          else state.wealth - config.testCost
        let step := { varName := vname, seResult, accepted, threshold, wealthAfter := newWealth }
        { wealth := newWealth,
          inModel := if accepted then state.inModel.push state.history.size else state.inModel,
          history := state.history.push step }

/-- Render alpha-investing results as a human-readable summary. -/
def AlphaState.render (state : AlphaState) : String :=
  let header := s!"Alpha-investing: {state.inModel.size} variables accepted, wealth remaining = {state.wealth}\n"
  let steps := state.history.toList.map fun step =>
    let status := if step.accepted then "✓ ACCEPTED" else "  rejected"
    s!"  {status} {step.varName}: t={step.seResult.tStat}, p={step.seResult.pValue}, threshold={step.threshold}, wealth→{step.wealthAfter}"
  header ++ String.intercalate "\n" steps

end LeanStats
