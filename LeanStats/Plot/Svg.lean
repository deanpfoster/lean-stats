/-! # LeanStats.Plot.Svg — core SVG type and renderer

Pure SVG element model and renderer. We model only the shapes we
actually need (circle, rect, line, text, path, group) and render
them to a string. No DOM, no streaming, no parsing.

Rationale: charts produced by `LeanStats` are short documents (KB
range), often embedded in HTML reports. A simple inductive `Svg`
type with a `render : Svg → String` is the right shape for that
use case.

The `Svg.render` function is `partial def` because it recurses on
`Svg.group children`. The recursion structurally decreases on the
list of children; we could prove termination, but a manifest claim
backed by `native_decide` on a curated corpus is enough for now.
See `Manifests/Plot.lean`.
-/
-- Manifest claims: LeanStats/Manifests/Plot.lean

set_option autoImplicit false

namespace LeanStats.Plot

inductive Attr where
  | mk : String → String → Attr
  deriving Repr

def attr (k v : String) : Attr := .mk k v

def Attr.render : Attr → String
  | .mk k v => s!" {k}='{v}'"

def renderAttrs (attrs : List Attr) : String :=
  String.join (attrs.map Attr.render)

inductive Svg where
  | circle (cx cy r : Float) (attrs : List Attr)
  | rect (x y w h : Float) (attrs : List Attr)
  | line (x1 y1 x2 y2 : Float) (attrs : List Attr)
  | text (x y : Float) (content : String) (attrs : List Attr)
  | path (d : String) (attrs : List Attr)
  | group (children : List Svg) (attrs : List Attr)
  deriving Repr

partial def Svg.render : Svg → String
  | .circle cx cy r attrs =>
    s!"<circle cx='{cx}' cy='{cy}' r='{r}'{renderAttrs attrs}/>"
  | .rect x y w h attrs =>
    s!"<rect x='{x}' y='{y}' width='{w}' height='{h}'{renderAttrs attrs}/>"
  | .line x1 y1 x2 y2 attrs =>
    s!"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}'{renderAttrs attrs}/>"
  | .text x y content attrs =>
    s!"<text x='{x}' y='{y}'{renderAttrs attrs}>{content}</text>"
  | .path d attrs =>
    s!"<path d='{d}'{renderAttrs attrs}/>"
  | .group children attrs =>
    let inner := String.join (children.map (fun c => "\n" ++ c.render))
    s!"<g{renderAttrs attrs}>{inner}\n</g>"

def svgDoc (width height : Float) (content : Svg) : String :=
  s!"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {width} {height}' width='{width}' height='{height}'>\n{content.render}\n</svg>"

end LeanStats.Plot
