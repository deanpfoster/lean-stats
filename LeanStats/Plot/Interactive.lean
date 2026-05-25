import LeanStats.Plot.Axes
import LeanStats.Diagnostics

/-! # LeanStats.Plot.Interactive — data-id tagged SVG renderers

Modified plot renderers that emit `data-id` and `data-tooltip` on each
observation element. These are the plots that participate in cross-plot
brushing when embedded in an interactive report.

Contract: observation `i` gets `data-id='i'` in EVERY plot. The JS
in `LeanStats.Report.Interactive` uses this to synchronize selection
across all SVGs on the page.
-/
-- Manifest claims: LeanStats/Manifests/Interactive.lean

set_option autoImplicit false

namespace LeanStats.Plot

/-- Format a Float to 2 decimal places (simple truncation). -/
private def fmt2 (x : Float) : String :=
  let s := toString (Float.round (x * 100) / 100)
  s

/-- Scatter plot with data-id and data-tooltip on each point.
    Tooltip shows: "obs i: (x, y)". -/
def interactiveScatter (data : Array (Float × Float))
    (opts : PlotOptions := {}) : Svg :=
  let xs := data.map Prod.fst
  let ys := data.map Prod.snd
  let xScale := Scale.fromData xs opts.marginLeft (opts.marginLeft + opts.plotWidth)
  let yScale := Scale.fromData ys (opts.marginTop + opts.plotHeight) opts.marginTop
  let axes := drawAxes xScale yScale opts
  let points := (List.range data.size).map fun i =>
    let (x, y) := data.getD i (0, 0)
    Svg.circle (xScale.apply x) (yScale.apply y) 4
      [attr "fill" "steelblue",
       attr "data-id" (toString i),
       attr "data-tooltip" s!"obs {i}: ({fmt2 x}, {fmt2 y})"]
  Svg.group ([axes] ++ points) []

/-- Scatter with regression line, data-id on each point.
    Tooltip includes residual and Cook's D when diagnostics are provided. -/
def interactiveFittedLine (xs ys : Array Float)
    (diag : LeanStats.RegressionDiag) (opts : PlotOptions := {}) : Svg :=
  let xScale := Scale.fromData xs opts.marginLeft (opts.marginLeft + opts.plotWidth)
  let yScale := Scale.fromData ys (opts.marginTop + opts.plotHeight) opts.marginTop
  let axes := drawAxes xScale yScale opts
  let points := (List.range xs.size).map fun i =>
    let x := xs.getD i 0
    let y := ys.getD i 0
    let resid := diag.residuals.getD i 0
    let cook := diag.cooksD.getD i 0
    let tip := s!"obs {i}: ({fmt2 x}, {fmt2 y}) resid={fmt2 resid} Cook's D={fmt2 cook}"
    Svg.circle (xScale.apply x) (yScale.apply y) 4
      [attr "fill" "steelblue",
       attr "data-id" (toString i),
       attr "data-tooltip" tip]
  let xmin := xScale.domainMin
  let xmax := xScale.domainMax
  let line := Svg.line
    (xScale.apply xmin) (yScale.apply (diag.slope * xmin + diag.intercept))
    (xScale.apply xmax) (yScale.apply (diag.slope * xmax + diag.intercept))
    [attr "stroke" "crimson", attr "stroke-width" "2"]
  Svg.group ([axes, line] ++ points) []

/-- Residuals vs fitted plot with data-id. -/
def interactiveResidVsFitted (diag : LeanStats.RegressionDiag)
    (opts : PlotOptions := {}) : Svg :=
  let fitted := diag.fitted
  let resid := diag.residuals
  let xScale := Scale.fromData fitted opts.marginLeft (opts.marginLeft + opts.plotWidth)
  let yScale := Scale.fromData resid (opts.marginTop + opts.plotHeight) opts.marginTop
  let axes := drawAxes xScale yScale opts
  let points := (List.range diag.n).map fun i =>
    let f := fitted.getD i 0
    let r := resid.getD i 0
    Svg.circle (xScale.apply f) (yScale.apply r) 4
      [attr "fill" "steelblue",
       attr "data-id" (toString i),
       attr "data-tooltip" s!"obs {i}: fitted={fmt2 f} resid={fmt2 r}"]
  -- Zero line
  let zeroY := yScale.apply 0
  let zeroLine := Svg.line
    opts.marginLeft zeroY (opts.marginLeft + opts.plotWidth) zeroY
    [attr "stroke" "#999", attr "stroke-dasharray" "4"]
  Svg.group ([axes, zeroLine] ++ points) []

/-- Normal Q-Q plot of residuals with data-id. -/
def interactiveQQ (diag : LeanStats.RegressionDiag)
    (opts : PlotOptions := {}) : Svg :=
  let qqData := LeanStats.residQQ diag
  let theoretical := qqData.map Prod.fst
  let observed := qqData.map Prod.snd
  let xScale := Scale.fromData theoretical opts.marginLeft (opts.marginLeft + opts.plotWidth)
  let yScale := Scale.fromData observed (opts.marginTop + opts.plotHeight) opts.marginTop
  let axes := drawAxes xScale yScale opts
  -- We need to map back to original observation indices (sorted order)
  let sortedIndices := (Array.range diag.n).qsort fun a b =>
    diag.residuals.getD a 0 < diag.residuals.getD b 0
  let points := (List.range qqData.size).map fun i =>
    let (t, o) := qqData.getD i (0, 0)
    let origIdx := sortedIndices.getD i i
    Svg.circle (xScale.apply t) (yScale.apply o) 4
      [attr "fill" "steelblue",
       attr "data-id" (toString origIdx),
       attr "data-tooltip" s!"obs {origIdx}: theoretical={fmt2 t} observed={fmt2 o}"]
  -- Reference line (y = x scaled)
  let mn := if (theoretical.getD 0 0) < (observed.getD 0 0) then theoretical.getD 0 0 else observed.getD 0 0
  let mx := if (theoretical.getD (theoretical.size - 1) 0) > (observed.getD (observed.size - 1) 0)
    then theoretical.getD (theoretical.size - 1) 0 else observed.getD (observed.size - 1) 0
  let refLine := Svg.line
    (xScale.apply mn) (yScale.apply mn)
    (xScale.apply mx) (yScale.apply mx)
    [attr "stroke" "#999", attr "stroke-dasharray" "4"]
  Svg.group ([axes, refLine] ++ points) []

/-- Count occurrences of a substring in a string. Used by manifests to
    verify data-id count matches n. -/
def countDataIds (svg : String) : Nat :=
  -- Count occurrences of "data-id='" in the rendered string
  (svg.splitOn "data-id='").length - 1

end LeanStats.Plot
