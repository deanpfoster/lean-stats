import LeanStat.Plot.Scale

/-! # LeanStat.Plot.Axes — axis drawing with tick marks -/

set_option autoImplicit false

namespace LeanStat.Plot

def drawAxes (xScale yScale : Scale) (opts : PlotOptions) : Svg :=
  let plotW := opts.plotWidth
  let plotH := opts.plotHeight
  let ml := opts.marginLeft
  let mt := opts.marginTop
  -- X axis
  let xAxis := Svg.line ml (mt + plotH) (ml + plotW) (mt + plotH)
    [attr "stroke" "black"]
  -- Y axis
  let yAxis := Svg.line ml mt ml (mt + plotH)
    [attr "stroke" "black"]
  -- 5 tick marks on each axis
  let nTicks : Nat := 5
  let xTicks := List.range nTicks |>.map fun i =>
    let frac := (Float.ofNat i) / (Float.ofNat (nTicks - 1))
    let px := ml + frac * plotW
    let val := xScale.domainMin + frac * (xScale.domainMax - xScale.domainMin)
    Svg.group [
      Svg.line px (mt + plotH) px (mt + plotH + 5) [attr "stroke" "black"],
      Svg.text px (mt + plotH + 15) (toString (Float.round (val * 10) / 10)) [attr "font-size" "10", attr "text-anchor" "middle"]
    ] []
  let yTicks := List.range nTicks |>.map fun i =>
    let frac := (Float.ofNat i) / (Float.ofNat (nTicks - 1))
    let py := mt + plotH - frac * plotH
    let val := yScale.domainMin + frac * (yScale.domainMax - yScale.domainMin)
    Svg.group [
      Svg.line (ml - 5) py ml py [attr "stroke" "black"],
      Svg.text (ml - 8) py (toString (Float.round (val * 10) / 10)) [attr "font-size" "10", attr "text-anchor" "end"]
    ] []
  -- Labels
  let labels : List Svg :=
    (if opts.title != "" then
      [Svg.text (opts.width / 2) 15 opts.title [attr "font-size" "14", attr "text-anchor" "middle"]]
    else []) ++
    (if opts.xLabel != "" then
      [Svg.text (ml + plotW / 2) (opts.height - 5) opts.xLabel [attr "font-size" "12", attr "text-anchor" "middle"]]
    else []) ++
    (if opts.yLabel != "" then
      [Svg.text 12 (mt + plotH / 2) opts.yLabel [attr "font-size" "12", attr "text-anchor" "middle", attr "transform" s!"rotate(-90,12,{mt + plotH / 2})"]]
    else [])
  Svg.group ([xAxis, yAxis] ++ xTicks ++ yTicks ++ labels) []

end LeanStat.Plot
