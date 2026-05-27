import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Plot.Describe

/-! # LeanStats.Manifests.PlotDescribe — claims about describeScatter/describeHistogram

Proves structural properties of plot description functions on fixtures.
-/
-- Implementation: LeanStats/Plot/Describe.lean

set_option autoImplicit false

namespace LeanStats.Manifests.PlotDescribe
open LeanStats.Plot

private def xs : Array Float := #[1.0, 2.0, 3.0, 4.0, 5.0]
private def ys : Array Float := #[2.0, 4.0, 6.0, 8.0, 10.0]
private def histData : Array Float := #[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]

/-- describeScatter n equals xs.size -/
theorem scatter_n_proof : (describeScatter xs ys).n = xs.size := by native_decide

UnitTest scatter_n : (describeScatter xs ys).n = xs.size

/-- describeHistogram n equals data.size -/
theorem histogram_n_proof : (describeHistogram histData).n = histData.size := by native_decide

UnitTest histogram_n : (describeHistogram histData).n = histData.size

/-- describeScatter correlation matches LeanStats.correlation -/
theorem scatter_corr_proof : (describeScatter xs ys).correlation = LeanStats.correlation xs ys := by native_decide

UnitTest scatter_corr : (describeScatter xs ys).correlation = LeanStats.correlation xs ys

end LeanStats.Manifests.PlotDescribe
