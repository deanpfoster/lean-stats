import LeanStats.Plot.Axes
import LeanStats.Diagnostics

/-! # LeanStats.Plot.FittedLine — scatter + regression line overlay

The signature JMP output: data points as circles, regression line
drawn through them. Optionally highlights outliers/influential points.
-/

set_option autoImplicit false

namespace LeanStats.Plot

/-- Scatter plot with regression line overlay. Outlier indices are
    drawn in red; all other points in steelblue. -/
def fittedLinePlot (xs ys : Array Float) (diag : LeanStats.RegressionDiag)
    (outliers : Array Nat := #[]) (opts : PlotOptions := {}) : Svg :=
  let xScale := Scale.fromData xs opts.marginLeft (opts.marginLeft + opts.plotWidth)
  let yScale := Scale.fromData ys (opts.marginTop + opts.plotHeight) opts.marginTop
  let axes := drawAxes xScale yScale opts
  -- Data points
  let points := (List.range xs.size).map fun i =>
    let x := xs.getD i 0
    let y := ys.getD i 0
    let color := if outliers.contains i then "crimson" else "steelblue"
    Svg.circle (xScale.apply x) (yScale.apply y) 3 [attr "fill" color]
  -- Regression line
  let xmin := xScale.domainMin
  let xmax := xScale.domainMax
  let ymin := diag.slope * xmin + diag.intercept
  let ymax := diag.slope * xmax + diag.intercept
  let line := Svg.line
    (xScale.apply xmin) (yScale.apply ymin)
    (xScale.apply xmax) (yScale.apply ymax)
    [attr "stroke" "crimson", attr "stroke-width" "2"]
  Svg.group ([axes, line] ++ points) []

end LeanStats.Plot
