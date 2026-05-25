/-! # LeanStats.Plot.Theme — switchable visual themes for plots

Themes control colors, weights, fonts, and spacing. The default
is Tufte-inspired (minimal, data-forward). Alternatives available
for familiarity (JMP, R/ggplot, Excel) or presentation contexts.

The LLM can select a theme or override individual properties
for emphasis (e.g. "make the main fit line thicker").
-/

set_option autoImplicit false

namespace LeanStats.Plot

/-- A complete visual theme for plots. -/
structure Theme where
  name : String
  -- Colors
  pointColor : String := "#4a7fb5"
  selectedColor : String := "#e6550d"
  excludedColor : String := "#bbb"
  fitColor : String := "#333"
  ciColor : String := "#999"
  axisColor : String := "#ccc"
  backgroundColor : String := "#fff"
  gridColor : String := "none"  -- "none" = no grid
  -- Weights
  axisWeight : Float := 0.5
  fitWeight : Float := 1.5
  ciWeight : Float := 0.75
  pointRadius : Float := 3.0
  pointOpacity : Float := 0.7
  -- Typography
  fontFamily : String := "system-ui, -apple-system, sans-serif"
  tickFontSize : Float := 10
  labelFontSize : Float := 12
  titleFontSize : Float := 14
  -- Spacing
  marginTop : Float := 15
  marginRight : Float := 15
  marginBottom : Float := 30
  marginLeft : Float := 45
  deriving Repr

/-- Tufte: minimal, high data-ink ratio, no chartjunk. -/
def Theme.tufte : Theme :=
  { name := "tufte"
    pointColor := "#4a7fb5"
    axisColor := "#ddd"
    axisWeight := 0.5
    fitWeight := 1.5
    pointOpacity := 0.65
    gridColor := "none"
    fontFamily := "Georgia, serif" }

/-- JMP: the familiar blue-on-white with heavier axes. -/
def Theme.jmp : Theme :=
  { name := "jmp"
    pointColor := "steelblue"
    axisColor := "#333"
    axisWeight := 1.0
    fitColor := "crimson"
    fitWeight := 2.0
    pointRadius := 3.5
    pointOpacity := 0.8
    gridColor := "none"
    fontFamily := "system-ui, sans-serif" }

/-- R/ggplot: grey background, white grid lines. -/
def Theme.ggplot : Theme :=
  { name := "ggplot"
    pointColor := "#333"
    axisColor := "#fff"
    axisWeight := 0.5
    backgroundColor := "#ebebeb"
    gridColor := "#fff"
    fitColor := "#3366cc"
    fitWeight := 1.5
    pointRadius := 2.5
    pointOpacity := 0.8
    fontFamily := "Helvetica, Arial, sans-serif" }

/-- Excel: the corporate default everyone recognizes. -/
def Theme.excel : Theme :=
  { name := "excel"
    pointColor := "#4472c4"
    axisColor := "#808080"
    axisWeight := 1.0
    fitColor := "#ed7d31"
    fitWeight := 2.0
    backgroundColor := "#fff"
    gridColor := "#d9d9d9"
    pointRadius := 4.0
    pointOpacity := 1.0
    fontFamily := "Calibri, sans-serif" }

/-- Dark: for presentations on dark backgrounds. -/
def Theme.dark : Theme :=
  { name := "dark"
    pointColor := "#6cb4ee"
    selectedColor := "#ffa040"
    excludedColor := "#555"
    fitColor := "#eee"
    ciColor := "#777"
    axisColor := "#555"
    backgroundColor := "#1e1e1e"
    gridColor := "#333"
    axisWeight := 0.5
    fitWeight := 1.5
    pointOpacity := 0.8
    fontFamily := "SF Mono, Menlo, monospace" }

/-- Generate CSS from a theme. -/
def Theme.toCss (t : Theme) : String :=
  s!"svg \{ background: {t.backgroundColor} }" ++
  s!" line.axis \{ stroke: {t.axisColor}; stroke-width: {t.axisWeight} }" ++
  s!" text.tick \{ fill: #666; font-size: {t.tickFontSize}px; font-family: {t.fontFamily} }" ++
  s!" text.label \{ fill: #333; font-size: {t.labelFontSize}px; font-family: {t.fontFamily} }" ++
  s!" circle.point \{ fill: {t.pointColor}; opacity: {t.pointOpacity}; r: {t.pointRadius} }" ++
  s!" circle.selected \{ fill: {t.selectedColor}; opacity: 1 }" ++
  s!" circle.excluded \{ fill: {t.excludedColor}; opacity: 0.3 }" ++
  s!" path.fit \{ stroke: {t.fitColor}; stroke-width: {t.fitWeight}; fill: none }" ++
  s!" path.ci \{ stroke: {t.ciColor}; stroke-width: {t.ciWeight}; fill: none; stroke-dasharray: 4 }" ++
  (if t.gridColor != "none" then s!" line.grid \{ stroke: {t.gridColor}; stroke-width: 0.5 }" else "")

/-- Adaptive point radius based on sample size. -/
def adaptiveRadius (n : Nat) : Float :=
  if n < 20 then 4.0
  else if n < 50 then 3.5
  else if n < 100 then 3.0
  else if n < 500 then 2.0
  else if n < 2000 then 1.5
  else 1.0

/-- Adaptive point opacity based on sample size. -/
def adaptiveOpacity (n : Nat) : Float :=
  if n < 30 then 0.8
  else if n < 100 then 0.6
  else if n < 500 then 0.4
  else 0.25

/-- Banking to 45°: compute optimal aspect ratio so average
    absolute slope of the data is ~45°. (Cleveland 1993) -/
def bankTo45 (xs ys : Array Float) : Float × Float :=
  if xs.size < 2 then (600, 400)
  else Id.run do
    let n := xs.size
    let mut totalSlope := 0.0
    for i in List.range (n - 1) do
      let dx := (xs.getD (i+1) 0) - (xs.getD i 0)
      let dy := (ys.getD (i+1) 0) - (ys.getD i 0)
      if dx != 0 then totalSlope := totalSlope + (dy / dx).abs
    let avgSlope := totalSlope / (n - 1).toFloat
    if avgSlope < 0.1 then return (600, 200)
    else if avgSlope > 10 then return (200, 600)
    else
      let width := 600.0
      let height := width / avgSlope
      let height := if height > 800 then 800 else if height < 200 then 200 else height
      return (width, height)

end LeanStats.Plot
