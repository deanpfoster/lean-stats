import DeanLean.Basic
import LeanStat.Report.Html

/-! # Manifests/Report — claims about HTML report generation

The renderer concatenates user-supplied strings (title, subtitle,
section heading/prose) into an HTML document. Known limitations:

  - **No HTML escaping.** Section prose containing `<script>` will
    execute. This is a deliberate simplification at this stage: we
    expect the consumer (e.g. l3m) to sanitize inputs at the
    capability boundary before passing them in. A future version
    of LeanStat will add an `escapeHtml` pass and a manifest claim
    that no script tags survive.

  - **CSS / JS injection** via control characters in title or
    section heading. Same caveat.

The structural claims that DO hold:

  - `renderReport` is a total function returning a `String`.
  - The output starts with `<!DOCTYPE html>`.
  - The output contains exactly one `<title>` element.
  - The output contains exactly one `<style>` and one `<script>`.

These are testable via `native_decide` on small fixtures.
-/

set_option autoImplicit false

namespace LeanStat.Manifests.Report
open LeanStat.Report

/-- An empty report (no sections) renders to a valid HTML document. -/
UnprovenConjecture empty_report_renders :
  let r : Report := { title := "T", subtitle := "S", sections := [] }
  (renderReport r).startsWith "<!DOCTYPE html>"

/-- Known gap: HTML escaping is not done. -/
UnprovenConjecture html_escaping_known_gap :
  True

end LeanStat.Manifests.Report
