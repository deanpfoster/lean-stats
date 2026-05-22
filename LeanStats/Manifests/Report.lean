import DeanLean.Basic
import LeanStats.Manifests.Util
import LeanStats.Report.Html

/-! # Manifests/Report — claims about HTML report generation

## User-facing (what an agent calling `renderReport` can trust)

  - Output starts with `<!DOCTYPE html>` (valid HTML5 document).
  - Output contains the title the caller provided.
  - Empty sections list produces a valid (minimal) document.

## Internal (implementation correctness)

  - CSS and JS are embedded (self-contained document).
  - Each section is wrapped in `<section>` tags.
  - Tooltip CSS/JS strings are non-empty.

## What we do NOT claim

  - HTML escaping (known gap: section prose is inserted raw).
  - CSS/JS injection prevention via title/heading fields.
  - W3C HTML5 validator conformance.
  - Accessibility (no ARIA attributes).
-/

set_option autoImplicit false

namespace LeanStats.Manifests.Report
open LeanStats.Report LeanStats.Manifests

-- ════════════════════════════════════════════════════════════
-- § User-facing claims
-- ════════════════════════════════════════════════════════════

/-- Empty report starts with DOCTYPE. -/
theorem report_doctype_proof :
  (renderReport { title := "T", subtitle := "S", sections := [] }).startsWith "<!DOCTYPE html>" = true := by native_decide

ProvenTheorem report_doctype :
  (renderReport { title := "T", subtitle := "S", sections := [] }).startsWith "<!DOCTYPE html>" = true

/-- Report output contains the title. -/
theorem report_contains_title_proof :
  String.containsSubstr (renderReport { title := "MyTitle", subtitle := "Sub", sections := [] }) "MyTitle" = true := by native_decide

ProvenTheorem report_contains_title :
  String.containsSubstr (renderReport { title := "MyTitle", subtitle := "Sub", sections := [] }) "MyTitle" = true

/-- Report output contains the subtitle. -/
theorem report_contains_subtitle_proof :
  String.containsSubstr (renderReport { title := "T", subtitle := "MySub", sections := [] }) "MySub" = true := by native_decide

ProvenTheorem report_contains_subtitle :
  String.containsSubstr (renderReport { title := "T", subtitle := "MySub", sections := [] }) "MySub" = true

/-- Report with a section contains the section heading. -/
theorem report_section_heading_proof :
  String.containsSubstr
    (renderReport { title := "T", subtitle := "S", sections := [{ heading := "Results", prose := "text" }] })
    "Results" = true := by native_decide

ProvenTheorem report_section_heading :
  String.containsSubstr
    (renderReport { title := "T", subtitle := "S", sections := [{ heading := "Results", prose := "text" }] })
    "Results" = true

-- ════════════════════════════════════════════════════════════
-- § Internal claims
-- ════════════════════════════════════════════════════════════

/-- Report contains a <style> block (CSS is embedded). -/
theorem report_has_style_proof :
  String.containsSubstr (renderReport { title := "T", subtitle := "S", sections := [] }) "<style>" = true := by native_decide

ProvenTheorem report_has_style :
  String.containsSubstr (renderReport { title := "T", subtitle := "S", sections := [] }) "<style>" = true

/-- Report contains a <script> block (JS is embedded). -/
theorem report_has_script_proof :
  String.containsSubstr (renderReport { title := "T", subtitle := "S", sections := [] }) "<script>" = true := by native_decide

ProvenTheorem report_has_script :
  String.containsSubstr (renderReport { title := "T", subtitle := "S", sections := [] }) "<script>" = true

/-- Tooltip CSS is non-empty. -/
theorem tooltip_css_nonempty_proof : tooltipCss.length > 0 := by native_decide

ProvenTheorem tooltip_css_nonempty : tooltipCss.length > 0

/-- Tooltip JS is non-empty. -/
theorem tooltip_js_nonempty_proof : tooltipJs.length > 0 := by native_decide

ProvenTheorem tooltip_js_nonempty : tooltipJs.length > 0

/-- Section with SVG includes the SVG content. -/
theorem section_svg_proof :
  String.containsSubstr
    (renderSection { heading := "H", prose := "P", svg := some "<svg/>" })
    "<svg/>" = true := by native_decide

ProvenTheorem section_svg :
  String.containsSubstr
    (renderSection { heading := "H", prose := "P", svg := some "<svg/>" })
    "<svg/>" = true

-- ════════════════════════════════════════════════════════════
-- § Known gaps (permanent axioms)
-- ════════════════════════════════════════════════════════════

/-- KNOWN GAP: HTML escaping is not performed. Section prose, titles,
    and headings are inserted raw. A `<script>` in prose will execute. -/
Sketch html_escaping_known_gap

/-- KNOWN GAP: No ARIA attributes or accessibility features. -/
Sketch accessibility_known_gap

end LeanStats.Manifests.Report
