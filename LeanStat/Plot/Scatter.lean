import LeanStat.Plot.Axes

/-! # LeanStat.Plot.Scatter — scatter plot -/

set_option autoImplicit false

namespace LeanStat.Plot

def scatterPlot (data : Array (Float × Float)) (opts : PlotOptions := {}) : Svg :=
  let xs := data.map Prod.fst
  let ys := data.map Prod.snd
  let xScale := Scale.fromData xs opts.marginLeft (opts.marginLeft + opts.plotWidth)
  let yScale := Scale.fromData ys (opts.marginTop + opts.plotHeight) opts.marginTop
  let axes := drawAxes xScale yScale opts
  let points := data.toList.map fun (x, y) =>
    Svg.circle (xScale.apply x) (yScale.apply y) 3 [attr "fill" "steelblue"]
  Svg.group ([axes] ++ points) []

end LeanStat.Plot
