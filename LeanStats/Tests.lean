import LeanStats.Descriptive

/-! # LeanStats.Tests — t-test statistics

Pure t-test implementations (one-sample, two-sample Welch's). Returns
the t-statistic only; we don't yet ship a CDF table or p-value
calculator (TODO: incorporate Student's t CDF).
-/
-- Manifest claims: LeanStats/Manifests/Tests.lean

set_option autoImplicit false

namespace LeanStats

/-- One-sample t-test against a hypothesized mean. Returns t-statistic. -/
def tTestOneSample (xs : Array Float) (μ₀ : Float) : Float :=
  let n := xs.size
  if n < 2 then 0
  else
    let m := mean xs
    let se := stdDev xs / n.toFloat.sqrt
    if se == 0 then 0 else (m - μ₀) / se

/-- Two-sample t-test (Welch's, unequal variance). Returns t-statistic. -/
def tTestTwoSample (xs ys : Array Float) : Float :=
  let n1 := xs.size
  let n2 := ys.size
  if n1 < 2 || n2 < 2 then 0
  else
    let m1 := mean xs
    let m2 := mean ys
    let v1 := variance xs
    let v2 := variance ys
    let se := (v1 / n1.toFloat + v2 / n2.toFloat).sqrt
    if se == 0 then 0 else (m1 - m2) / se

def tTestPaired (xs ys : Array Float) : Float :=
  if xs.size != ys.size || xs.size < 2 then 0
  else
    let d := Array.zipWith (fun x y => x - y) xs ys
    tTestOneSample d 0

end LeanStats
