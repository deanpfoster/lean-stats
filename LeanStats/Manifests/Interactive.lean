import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Plot.Interactive
import LeanStats.Report.Interactive

/-! # Manifests/Interactive — claims about point identification and brushing

## Testing strategy

Since this library does no IO, we can't open a browser. But the output
is pure strings, so we can make structural claims:

1. **data-id presence**: rendered SVG contains `data-id='i'` for each i.
2. **data-id count = n**: number of data-id attributes matches input size.
3. **Consistency**: same data rendered through different plot functions
   produces the same set of data-id values.
4. **JS presence**: interactive report contains the brushing script.
5. **Tooltip content**: each point's tooltip contains its observation index.

These are all decidable string properties on concrete fixtures.

## What we do NOT claim

  - Visual correctness (highlight looks right in a browser).
  - JS execution correctness (point-in-polygon, event handling).
  - Browser compatibility.
  - Performance on large n.
-/

set_option autoImplicit false

namespace LeanStats.Manifests.Interactive
open LeanStats.Plot LeanStats.Report LeanStats.Manifests

-- Small fixture for testing
private def testData : Array (Float × Float) := #[(1.0, 2.0), (2.0, 4.0), (3.0, 6.0)]
private def testXs : Array Float := #[1.0, 2.0, 3.0]
private def testYs : Array Float := #[2.0, 4.0, 6.0]

-- ════════════════════════════════════════════════════════════
-- § Claim 1: data-id count matches n
-- ════════════════════════════════════════════════════════════

/-- Interactive scatter on 3 points produces exactly 3 data-id attributes. -/
theorem scatter_dataid_count_proof :
  countDataIds (interactiveScatter testData).render = 3 := by native_decide

ProvenTheorem scatter_dataid_count :
  countDataIds (interactiveScatter testData).render = 3

-- ════════════════════════════════════════════════════════════
-- § Claim 2: specific data-id values are present
-- ════════════════════════════════════════════════════════════

/-- Scatter output contains data-id='0'. -/
theorem scatter_has_id0_proof :
  String.containsSubstr (interactiveScatter testData).render "data-id='0'" = true := by native_decide

ProvenTheorem scatter_has_id0 :
  String.containsSubstr (interactiveScatter testData).render "data-id='0'" = true

/-- Scatter output contains data-id='2' (last point). -/
theorem scatter_has_id2_proof :
  String.containsSubstr (interactiveScatter testData).render "data-id='2'" = true := by native_decide

ProvenTheorem scatter_has_id2 :
  String.containsSubstr (interactiveScatter testData).render "data-id='2'" = true

-- ════════════════════════════════════════════════════════════
-- § Claim 3: tooltip contains observation index
-- ════════════════════════════════════════════════════════════

/-- Tooltip for first point contains "obs 0". -/
theorem scatter_tooltip_obs0_proof :
  String.containsSubstr (interactiveScatter testData).render "obs 0" = true := by native_decide

ProvenTheorem scatter_tooltip_obs0 :
  String.containsSubstr (interactiveScatter testData).render "obs 0" = true

/-- Tooltip for last point contains "obs 2". -/
theorem scatter_tooltip_obs2_proof :
  String.containsSubstr (interactiveScatter testData).render "obs 2" = true := by native_decide

ProvenTheorem scatter_tooltip_obs2 :
  String.containsSubstr (interactiveScatter testData).render "obs 2" = true

-- ════════════════════════════════════════════════════════════
-- § Claim 4: JS is present in interactive report
-- ════════════════════════════════════════════════════════════

/-- Interactive JS contains the selection sync function. -/
theorem js_has_sync_proof :
  String.containsSubstr interactiveJs "sync()" = true := by native_decide

ProvenTheorem js_has_sync :
  String.containsSubstr interactiveJs "sync()" = true

/-- Interactive JS contains point-in-polygon for lasso. -/
theorem js_has_pip_proof :
  String.containsSubstr interactiveJs "function pip" = true := by native_decide

ProvenTheorem js_has_pip :
  String.containsSubstr interactiveJs "function pip" = true

/-- Interactive CSS contains the .selected class. -/
theorem css_has_selected_proof :
  String.containsSubstr interactiveCss ".selected" = true := by native_decide

ProvenTheorem css_has_selected :
  String.containsSubstr interactiveCss ".selected" = true

-- ════════════════════════════════════════════════════════════
-- § Claim 5: cross-plot consistency (same data-id set)
-- ════════════════════════════════════════════════════════════

-- Helpers for cross-plot claims
private def residDataIdCount (xs ys : Array Float) : Option Nat :=
  (LeanStats.regressionDiag xs ys).map fun d => countDataIds (interactiveResidVsFitted d).render

private def qqDataIdCount (xs ys : Array Float) : Option Nat :=
  (LeanStats.regressionDiag xs ys).map fun d => countDataIds (interactiveQQ d).render

/-- Residual plot on same data also has 3 data-ids. -/
theorem resid_dataid_count_proof :
  residDataIdCount testXs testYs = some 3 := by native_decide

ProvenTheorem resid_dataid_count :
  residDataIdCount testXs testYs = some 3

/-- Q-Q plot on same data also has 3 data-ids. -/
theorem qq_dataid_count_proof :
  qqDataIdCount testXs testYs = some 3 := by native_decide

ProvenTheorem qq_dataid_count :
  qqDataIdCount testXs testYs = some 3

-- ════════════════════════════════════════════════════════════
-- § Known gaps
-- ════════════════════════════════════════════════════════════

/-- KNOWN GAP: data-tooltip values are not HTML-escaped. Adversarial
    float-to-string output could theoretically inject attributes. -/
ManifestAxiom tooltip_escaping_gap : True

/-- KNOWN GAP: lasso point-in-polygon correctness is not formally verified.
    The ray-casting algorithm is standard but we don't prove it in Lean. -/
ManifestAxiom lasso_pip_unverified : True

end LeanStats.Manifests.Interactive
