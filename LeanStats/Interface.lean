import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanStats.Diagnostics
import LeanStats.Transform

/-! # LeanStats.Interface — the manifest l3m reads to know what it can call

This is the MINIMAL trust surface for an agent wrapping LeanStats as tools.

## What l3m gets

1. **Signatures** — type-checked function signatures (if the function
   changes type, this file breaks the build)
2. **Safety/correctness pointers** — names of the manifest modules that
   carry the tested/proven claims
3. **Purity pointer** — the separate audit module that checks the combined
   LeanStats+LeanTab surface

## How l3m uses this

The agent reads this file to populate its tool registry. Each Signature
line becomes a tool. The full proof/test inventory is intentionally kept
in `LeanStats.Manifest` and `LeanStats.Audit` so this core interface does
not pull LeanTab back into LeanStats' shared library.
-/
-- API contract for l3m. See also: LeanStats/Manifest.lean

set_option autoImplicit false

namespace LeanStats.Interface
open LeanStats

-- ════════════════════════════════════════════════════════════
-- § Signatures: type-checked function contracts
-- ════════════════════════════════════════════════════════════

Signature mean : Array Float → Float
Signature variance : Array Float → Float
Signature stdDev : Array Float → Float
Signature median : Array Float → Float
Signature quantile : Array Float → Float → Float
Signature summary : Array Float → Summary
Signature correlation : Array Float → Array Float → Float
Signature linearRegression : Array Float → Array Float → Option LinearFit
Signature regressionDiag : Array Float → Array Float → Option RegressionDiag
Signature tTestOneSample : Array Float → Float → Float
Signature tTestTwoSample : Array Float → Array Float → Float
Signature logTransform : Array Float → Array Float
Signature sqrtTransform : Array Float → Array Float
Signature recipTransform : Array Float → Array Float
Signature bestResponseTransform : Array Float → Array Float → TransformKind × Float

-- ════════════════════════════════════════════════════════════
-- § Safety + Correctness: restated from sub-manifests
-- ════════════════════════════════════════════════════════════

-- These are tracked in LeanStats.Manifest (import it separately when the
-- full combined LeanStats+LeanTab trust inventory is needed).
-- The agent can reference them by name:
--   LeanStats.Manifest.degenerate_safe
--   LeanStats.Manifests.Descriptive.mean_empty
--   LeanStats.Manifests.Regression.regression_slope
--   etc.
--
-- We don't import or re-prove them here; this module stays on the
-- LeanStats-only side of the package boundary.

/-- The complete trust chain is available via `import LeanStats.Manifest`.
    Key proven claims:
    - `degenerate_safe`: empty/singleton inputs → safe defaults (0, none)
    - `mean_singleton`: mean #[x] = x
    - `regression_slope`: OLS on y=2x+1 recovers slope=2
    - `regression_r2_perfect`: perfect linear data → R²=1
    - `ttest_one_positive`: mean > μ₀ → t > 0
    - `diag_perfect_r2`: perfect fit → R²=1, se=0
-/
Sketch trust_chain_documented

/-- No IO in any function signature. -/
Sketch pure_no_io

end LeanStats.Interface
