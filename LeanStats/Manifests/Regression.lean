import DeanLean.Basic
import LeanStats.Regression

/-! # Manifests/Regression — claims about correlation and linear regression

The OLS implementation should satisfy:
  - `correlation` is in [-1, 1] (within float tolerance)
  - `linearRegression` returns `none` exactly when inputs are
    degenerate (mismatched sizes, < 2 points, no variation in xs)
  - When it returns `some fit`: `fit.slope` minimizes the sum of
    squared residuals (least-squares optimality)
  - `fit.intercept` is determined by `fit.slope` and the means
    (`fit.intercept = mean ys - fit.slope * mean xs`)
-/

set_option autoImplicit false

namespace LeanStats.Manifests.Regression
open LeanStat

/-- Correlation of empty or singleton inputs is 0. -/
UnprovenConjecture correlation_degenerate :
  correlation #[] #[] = 0 ∧
  correlation #[1.0] #[2.0] = 0

/-- Linear regression on degenerate inputs returns `none`. -/
UnprovenConjecture regression_degenerate :
  linearRegression #[] #[] = none

/-- Linear regression on inputs of different lengths returns `none`. -/
UnprovenConjecture regression_mismatched :
  linearRegression #[1.0] #[1.0, 2.0] = none

/-- Linear regression on a horizontal line (no variation in xs)
    returns `none` (slope is undefined). -/
UnprovenConjecture regression_zero_variance :
  linearRegression #[1.0, 1.0, 1.0] #[1.0, 2.0, 3.0] = none

end LeanStats.Manifests.Regression
