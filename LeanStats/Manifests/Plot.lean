import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Plot.Scatter
import LeanStats.Plot.Histogram

/-! # Manifests/Plot — claims about chart rendering

## User-facing (what an agent calling `scatterPlot`/`histogram` can trust)

  - `svgDoc` output starts with `<svg xmlns=` (valid SVG root).
  - Scale maps domain endpoints to range endpoints correctly.
  - Scale of constant data doesn't crash (returns rangeMin).

## Internal (implementation correctness)

  - `Scale.apply` maps domainMin → rangeMin and domainMax → rangeMax.
  - `Scale.fromData` spans the input data (domainMin/Max correct).
  - `Svg.render` on basic shapes produces expected strings.
  - Attr renders to ` key='value'` format.

## What we do NOT claim

  - SVG spec conformance (no DTD validation).
  - Attribute-value escaping (known gap).
  - Visual correctness ("looks right") — human judgment.
  - Termination of `Svg.render` (partial def).
-/
-- Implementation: LeanStats/Plot/Svg.lean

set_option autoImplicit false

namespace LeanStats.Manifests.Plot
open LeanStats.Plot

-- ════════════════════════════════════════════════════════════
-- § User-facing claims
-- ════════════════════════════════════════════════════════════

/-- svgDoc output starts with the SVG namespace declaration. -/
theorem svgdoc_prefix_proof :
  (svgDoc 600 400 (Svg.group [] [])).startsWith "<svg xmlns=" = true := by native_decide

UnitTest svgdoc_prefix :
  (svgDoc 600 400 (Svg.group [] [])).startsWith "<svg xmlns=" = true

/-- Scale of constant data maps any input to rangeMin (degenerate case). -/
theorem scale_constant_proof :
  (Scale.fromData #[5.0] 10 200).apply 5.0 = 10 := by native_decide

UnitTest scale_constant :
  (Scale.fromData #[5.0] 10 200).apply 5.0 = 10

/-- Scale maps domainMin to rangeMin. -/
theorem scale_min_proof :
  (Scale.fromData #[1.0, 5.0] 0 100).apply 1.0 = 0 := by native_decide

UnitTest scale_min :
  (Scale.fromData #[1.0, 5.0] 0 100).apply 1.0 = 0

/-- Scale maps domainMax to rangeMax. -/
theorem scale_max_proof :
  (Scale.fromData #[1.0, 5.0] 0 100).apply 5.0 = 100 := by native_decide

UnitTest scale_max :
  (Scale.fromData #[1.0, 5.0] 0 100).apply 5.0 = 100

/-- Scale midpoint maps to range midpoint (linearity). -/
theorem scale_mid_proof :
  (Scale.fromData #[0.0, 10.0] 0 100).apply 5.0 = 50 := by native_decide

UnitTest scale_mid :
  (Scale.fromData #[0.0, 10.0] 0 100).apply 5.0 = 50

-- ════════════════════════════════════════════════════════════
-- § Internal claims
-- ════════════════════════════════════════════════════════════

/-- Empty group renders to `<g>\n</g>`. -/
theorem empty_group_proof :
  (Svg.group [] []).render = "<g>\n</g>" := by native_decide

UnitTest empty_group :
  (Svg.group [] []).render = "<g>\n</g>"

/-- Scale.fromData captures the min of the input. -/
theorem scale_domain_min_proof :
  (Scale.fromData #[3.0, 1.0, 5.0] 0 100).domainMin = 1.0 := by native_decide

UnitTest scale_domain_min :
  (Scale.fromData #[3.0, 1.0, 5.0] 0 100).domainMin = 1.0

/-- Scale.fromData captures the max of the input. -/
theorem scale_domain_max_proof :
  (Scale.fromData #[3.0, 1.0, 5.0] 0 100).domainMax = 5.0 := by native_decide

UnitTest scale_domain_max :
  (Scale.fromData #[3.0, 1.0, 5.0] 0 100).domainMax = 5.0

/-- Attr renders to key='value' format. -/
theorem attr_render_proof :
  (attr "fill" "red").render = " fill='red'" := by native_decide

UnitTest attr_render :
  (attr "fill" "red").render = " fill='red'"

-- ════════════════════════════════════════════════════════════
-- § Known gaps (permanent axioms)
-- ════════════════════════════════════════════════════════════

/-- KNOWN GAP: attribute-value escaping. The renderer concatenates raw
    strings into `key='value'` without escaping quotes, `<`, `>`, or `&`. -/
Sketch attr_escaping_known_gap

/-- KNOWN GAP: Svg.render is `partial def`. Structurally decreasing on
    the List of children, but termination is not formally proven. -/
Sketch svg_render_partial

end LeanStats.Manifests.Plot
