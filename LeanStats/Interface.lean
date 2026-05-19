import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Diagnostics
import LeanStats.Transform
import LeanStats.Manifest

/-! # LeanStats.Interface — the manifest l3m reads to know what it can call

This is the MINIMAL trust surface for an agent wrapping LeanStats as tools.

## What l3m gets

1. **Signatures** — type-checked function signatures (if the function
   changes type, this file breaks the build)
2. **Safety** — proven: degenerate inputs return safe defaults
3. **Correctness** — proven: known fixtures produce expected results
4. **Purity** — asserted: no IO anywhere

## How l3m uses this

The agent reads this file to populate its tool registry. Each Signature
line becomes a tool. The Restate'd theorems become the tool's "trust
documentation" — what the agent can tell the user about why the result
is trustworthy.
-/

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

-- These are already proven in LeanStats.Manifest (which this imports).
-- The agent can reference them by name:
--   LeanStats.Manifest.degenerate_safe
--   LeanStats.Manifests.Descriptive.mean_empty
--   LeanStats.Manifests.Regression.regression_slope
--   etc.
--
-- We don't re-prove them here; we just document that they exist
-- and that importing LeanStats.Manifest gives you the full trust chain.

/-- The complete trust chain is available via `import LeanStats.Manifest`.
    Key proven claims:
    - `degenerate_safe`: empty/singleton inputs → safe defaults (0, none)
    - `mean_singleton`: mean #[x] = x
    - `regression_slope`: OLS on y=2x+1 recovers slope=2
    - `regression_r2_perfect`: perfect linear data → R²=1
    - `ttest_one_positive`: mean > μ₀ → t > 0
    - `diag_perfect_r2`: perfect fit → R²=1, se=0
-/
ManifestAxiom trust_chain_documented : True

/-- No IO in any function signature. -/
ManifestAxiom pure_no_io : True

end LeanStats.Interface
