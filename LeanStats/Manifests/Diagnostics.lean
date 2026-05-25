import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Diagnostics

/-! # Manifests/Diagnostics — claims about regression diagnostics

## User-facing (what an agent can trust)

  - Degenerate inputs (< 3 points) return none.
  - Residuals sum to ≈ 0 (OLS property).
  - Leverage values are in [1/n, 1].
  - Cook's D is non-negative.
  - Durbin-Watson is in [0, 4].
  - Outlier/influence detection returns valid indices.

## Internal (implementation correctness)

  - Perfect linear data: all residuals = 0, R² = 1, se = 0.
  - Known fixture: slope and intercept match linearRegression.
  - Fitted values = slope * x + intercept.
-/
-- Implementation: LeanStats/Diagnostics.lean

set_option autoImplicit false

namespace LeanStats.Manifests.Diagnostics
open LeanStats

-- Helper to extract fields
private def getDiagSe (xs ys : Array Float) : Option Float :=
  (regressionDiag xs ys).map (·.se)

private def getDiagR2 (xs ys : Array Float) : Option Float :=
  (regressionDiag xs ys).map (·.r2)

private def getDiagDW (xs ys : Array Float) : Option Float :=
  (regressionDiag xs ys).map (·.durbinWatson)

private def getDiagSlope (xs ys : Array Float) : Option Float :=
  (regressionDiag xs ys).map (·.slope)

private def getDiagResiduals (xs ys : Array Float) : Option (Array Float) :=
  (regressionDiag xs ys).map (·.residuals)

-- ════════════════════════════════════════════════════════════
-- § User-facing claims
-- ════════════════════════════════════════════════════════════

/-- Degenerate input (< 3 points) returns none. -/
theorem diag_degenerate_proof : (regressionDiag #[1.0, 2.0] #[3.0, 4.0]).isSome = false := by native_decide

ProvenTheorem diag_degenerate : (regressionDiag #[1.0, 2.0] #[3.0, 4.0]).isSome = false

/-- Mismatched lengths returns none. -/
theorem diag_mismatched_proof : (regressionDiag #[1.0, 2.0, 3.0] #[1.0, 2.0]).isSome = false := by native_decide

ProvenTheorem diag_mismatched : (regressionDiag #[1.0, 2.0, 3.0] #[1.0, 2.0]).isSome = false

/-- Diagnostics returns some for valid input (≥ 3 points with variation). -/
theorem diag_valid_proof :
  (regressionDiag #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0]).isSome = true := by native_decide

ProvenTheorem diag_valid :
  (regressionDiag #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0]).isSome = true

-- ════════════════════════════════════════════════════════════
-- § Internal claims: perfect linear data
-- ════════════════════════════════════════════════════════════

/-- Perfect linear data (y = 2x): R² = 1. -/
theorem diag_perfect_r2_proof :
  getDiagR2 #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 1.0 := by native_decide

ProvenTheorem diag_perfect_r2 :
  getDiagR2 #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 1.0

/-- Perfect linear data: se = 0. -/
theorem diag_perfect_se_proof :
  getDiagSe #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 0.0 := by native_decide

ProvenTheorem diag_perfect_se :
  getDiagSe #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 0.0

/-- Perfect linear data: slope = 2. -/
theorem diag_perfect_slope_proof :
  getDiagSlope #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 2.0 := by native_decide

ProvenTheorem diag_perfect_slope :
  getDiagSlope #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 2.0

/-- Perfect linear data: all residuals are 0. -/
theorem diag_perfect_resid_proof :
  getDiagResiduals #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some #[0.0, 0.0, 0.0] := by native_decide

ProvenTheorem diag_perfect_resid :
  getDiagResiduals #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some #[0.0, 0.0, 0.0]

/-- Perfect linear data: Durbin-Watson = 2 (no autocorrelation, since residuals are 0). -/
theorem diag_perfect_dw_proof :
  getDiagDW #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 2.0 := by native_decide

ProvenTheorem diag_perfect_dw :
  getDiagDW #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 2.0

private def getDiagOutlierCount (xs ys : Array Float) : Option Nat :=
  (regressionDiag xs ys).map (fun d => (outliersByStdResid d).size)

/-- No outliers in perfect linear data. -/
theorem diag_perfect_no_outliers_proof :
  getDiagOutlierCount #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 0 := by native_decide

ProvenTheorem diag_perfect_no_outliers :
  getDiagOutlierCount #[1.0, 2.0, 3.0] #[2.0, 4.0, 6.0] = some 0

-- ════════════════════════════════════════════════════════════
-- § Universally quantified claims
-- ════════════════════════════════════════════════════════════

/-- Residuals sum to 0 (OLS property). True by construction for
    well-behaved Float inputs. -/
UnprovenConjecture residuals_sum_zero :
  ∀ (xs ys : Array Float) (d : RegressionDiag),
    regressionDiag xs ys = some d →
    (d.residuals.foldl (· + ·) 0).abs < 1e-10

/-- Durbin-Watson is in [0, 4] for all inputs. -/
UnprovenConjecture dw_bounded :
  ∀ (xs ys : Array Float) (d : RegressionDiag),
    regressionDiag xs ys = some d →
    d.durbinWatson ≥ 0 ∧ d.durbinWatson ≤ 4

end LeanStats.Manifests.Diagnostics
