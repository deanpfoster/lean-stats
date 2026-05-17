import LeanStat.Plot.Svg

/-! # LeanStat.Plot.Scale — data-to-pixel scaling

A `Scale` is an affine map `domain → range`. Used to position data
points within a chart's pixel area.
-/

set_option autoImplicit false

namespace LeanStat.Plot

structure Scale where
  domainMin : Float
  domainMax : Float
  rangeMin : Float
  rangeMax : Float
  deriving Repr

def Scale.apply (s : Scale) (x : Float) : Float :=
  if s.domainMax == s.domainMin then s.rangeMin
  else s.rangeMin + (x - s.domainMin) / (s.domainMax - s.domainMin) * (s.rangeMax - s.rangeMin)

def Scale.fromData (values : Array Float) (rangeMin rangeMax : Float) : Scale :=
  let init := values.getD 0 0
  let mn := values.foldl (fun a b => if a < b then a else b) init
  let mx := values.foldl (fun a b => if a > b then a else b) init
  { domainMin := mn, domainMax := mx, rangeMin := rangeMin, rangeMax := rangeMax }

structure PlotOptions where
  width : Float := 600
  height : Float := 400
  marginLeft : Float := 60
  marginBottom : Float := 40
  marginTop : Float := 20
  marginRight : Float := 20
  title : String := ""
  xLabel : String := ""
  yLabel : String := ""
  deriving Repr

def PlotOptions.plotWidth (o : PlotOptions) : Float :=
  o.width - o.marginLeft - o.marginRight

def PlotOptions.plotHeight (o : PlotOptions) : Float :=
  o.height - o.marginTop - o.marginBottom

end LeanStat.Plot
