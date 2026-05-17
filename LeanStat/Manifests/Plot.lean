import DeanLean.Basic
import LeanStat.Plot.Svg
import LeanStat.Plot.Scatter
import LeanStat.Plot.Histogram

/-! # Manifests/Plot — claims about chart rendering

Plot output is a string of SVG. We claim:

  - `Svg.render` is total on every finite SVG tree (no infinite
    loop, no panic). Currently `partial def`; the manifest claim is
    backed by `native_decide` on a curated corpus.

  - The rendered string contains a single `<svg ...>` root, balanced
    tags, and no script-injection vectors from user data (TODO:
    we don't currently escape attribute values, so adversarial
    `attr` content can break out).

  - `Scale.apply` is monotone in its input (within float tolerance).

  - `Scale.fromData` produces a scale whose domain spans the input
    data: `domainMin ≤ min data ∧ domainMax ≥ max data`.
-/

set_option autoImplicit false

namespace LeanStat.Manifests.Plot
open LeanStat.Plot

/-- An empty group renders to a self-closing-style `<g></g>`. -/
UnprovenConjecture empty_group_renders :
  True   -- Svg.render (Svg.group [] []) = "<g></g>"  (ish; exact form TBD)

/-- Scale of constant data has domainMin = domainMax. -/
UnprovenConjecture scale_constant :
  ∀ (v r0 r1 : Float),
    let s := Scale.fromData #[v] r0 r1
    s.domainMin = v ∧ s.domainMax = v

/-- TODO: attribute-value escaping. Currently the renderer concatenates
    raw strings into `key='value'` pairs without escaping `'`, `<`,
    `>`, or `&`. An adversarial caller can inject SVG markup. We
    document this as a known gap; consumers should either sanitize
    inputs or run output through a separate SVG validator. -/
UnprovenConjecture attr_escaping_known_gap :
  True

end LeanStat.Manifests.Plot
