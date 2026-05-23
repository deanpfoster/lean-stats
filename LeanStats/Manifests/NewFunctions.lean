import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Anova
import LeanStats.Proportion
import LeanStats.Regression
import LeanStats.LinAlg
import LeanStats.VIFRegression
import LeanStats.Tests
import LeanTab.Table

set_option autoImplicit false
namespace LeanStats.Manifests.NewFunctions
open LeanStats LeanTab

-- ════════════════════════════════════════════════════════════
-- § 1. oneWayAnova returns Some on valid 3-group input
-- ════════════════════════════════════════════════════════════

private def anovaIsSome : Bool :=
  (oneWayAnova #[#[1,2,3], #[4,5,6], #[7,8,9]]).isSome

theorem anova_three_groups_proof : anovaIsSome = true := by native_decide

ProvenTheorem anova_three_groups : anovaIsSome = true

-- ════════════════════════════════════════════════════════════
-- § 2. chiSquaredTest on 2x2 table returns positive statistic
-- ════════════════════════════════════════════════════════════

private def chiSqStat : Float := (chiSquaredTest #[#[10, 20], #[30, 40]]).1

private def chiSqPositive : Bool := chiSqStat > 0

theorem chi_squared_positive_proof : chiSqPositive = true := by native_decide

ProvenTheorem chi_squared_positive : chiSqPositive = true

-- ════════════════════════════════════════════════════════════
-- § 3. vifAll with uncorrelated predictors returns low values
-- ════════════════════════════════════════════════════════════

private def vifValues : Array Float := vifAll #[#[1,2,3,4,5], #[5,3,1,4,2]]

private def vifBothLow : Bool := vifValues.all (· < 5)

theorem vif_uncorrelated_low_proof : vifBothLow = true := by native_decide

ProvenTheorem vif_uncorrelated_low : vifBothLow = true

-- ════════════════════════════════════════════════════════════
-- § 4. Table.dummyCode produces correct column count
-- ════════════════════════════════════════════════════════════

private def testTable : Table :=
  Table.fromColumns #[("color", #[Cell.str "red", Cell.str "green", Cell.str "blue"])]

private def dummyCodedTable : Table := testTable.dummyCode "color"

private def dummyCodeColCount : Bool := dummyCodedTable.nCols = testTable.nCols + 1

theorem dummy_code_col_count_proof : dummyCodeColCount = true := by native_decide

ProvenTheorem dummy_code_col_count : dummyCodeColCount = true

-- ════════════════════════════════════════════════════════════
-- § 5. LinAlg.matmul identity
-- ════════════════════════════════════════════════════════════

private def id2 : LinAlg.Matrix := LinAlg.Matrix.identity 2

private def mat2 : LinAlg.Matrix := LinAlg.Matrix.fromRows #[#[3, 4], #[5, 6]]

private def matmulIdentity : Bool := (LinAlg.matmul id2 mat2).data == mat2.data

theorem matmul_identity_proof : matmulIdentity = true := by native_decide

ProvenTheorem matmul_identity : matmulIdentity = true

-- ════════════════════════════════════════════════════════════
-- § 6. LinAlg.ols on perfect linear data y = 2x + 1
-- ════════════════════════════════════════════════════════════

private def olsX : LinAlg.Matrix := LinAlg.Matrix.fromRows #[#[1,1], #[1,2], #[1,3], #[1,4], #[1,5]]

private def olsY : Array Float := #[3, 5, 7, 9, 11]

private def olsResult : Bool :=
  match LinAlg.ols olsX olsY with
  | some beta => beta.size == 2 && beta[0]! == 1.0 && beta[1]! == 2.0
  | none => false

theorem ols_perfect_linear_proof : olsResult = true := by native_decide

ProvenTheorem ols_perfect_linear : olsResult = true

-- ════════════════════════════════════════════════════════════
-- § 7. iqr on known data
-- ════════════════════════════════════════════════════════════

private def iqrValue : Float := iqr #[1,2,3,4,5,6,7,8,9,10]

private def iqrExpected : Bool := iqrValue > 0

theorem iqr_positive_proof : iqrExpected = true := by native_decide

ProvenTheorem iqr_positive : iqrExpected = true

-- ════════════════════════════════════════════════════════════
-- § 8. tTestPaired returns 0 when pairs are identical
-- ════════════════════════════════════════════════════════════

private def pairedIdentical : Float := tTestPaired #[1,2,3] #[1,2,3]

theorem paired_t_identical_proof : pairedIdentical = 0 := by native_decide

ProvenTheorem paired_t_identical : pairedIdentical = 0

-- VIF-Regression conformance: validated against R's VIF package (CRAN archive)
-- R 4.3.2, VIF 1.0, run: Rscript Conformance/R/vif_regression.R
-- R output: "selected (1-based): 1" → our index 0
private def rY : Array Float := #[2.5, 3.7, 6.8, 7.9, 10.4, 11.4, 14.2, 16.7, 17.6, 20.3, 21.8, 24.6, 25.5, 28.1, 30.9, 31.2, 34.3, 35.9, 38.5, 39.7]
private def rX0 : Array Float := #[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
private def rX1 : Array Float := #[14, 6, 1, 8, 19, 11, 16, 3, 18, 9, 5, 15, 7, 12, 20, 4, 17, 10, 2, 13]

/-- VIF-Regression matches R: selects x0 (signal), rejects x1 (noise).
    R 4.3.2, CRAN VIF package v1.0 (Lin, Foster, Ungar 2011).
    Validated 2026-05-23. -/
ConformanceFixture vif_regression_conforms_r :
  (vifRegression rY #[rX0, rX1] { w0 := 0.1, dw := 0.05, subsize := 20 }).selected = #[0]

end LeanStats.Manifests.NewFunctions
