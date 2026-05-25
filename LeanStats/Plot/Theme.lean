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
  -- Structural flags
  /-- "inline" (Tufte: label on the line) or "box" (legend in a box below) -/
  legendStyle : String := "inline"
  /-- "none", "subtle" (1px light), "full" (dark border around plot) -/
  borderStyle : String := "none"
  /-- "none", "horizontal", "full" (both directions) -/
  gridStyle : String := "none"
  /-- "minimal" (ticks only), "lines" (full axis lines), "frame" (box around plot) -/
  axisStyle : String := "minimal"
  /-- "filled", "open", "filled-border" -/
  pointStyle : String := "filled"
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
    fontFamily := "Georgia, serif"
    legendStyle := "inline"
    borderStyle := "none"
    gridStyle := "none"
    axisStyle := "minimal"
    pointStyle := "filled" }

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
    fontFamily := "system-ui, sans-serif"
    legendStyle := "box"
    borderStyle := "subtle"
    gridStyle := "none"
    axisStyle := "lines"
    pointStyle := "filled" }

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
    fontFamily := "Helvetica, Arial, sans-serif"
    legendStyle := "box"
    borderStyle := "none"
    gridStyle := "full"
    axisStyle := "minimal"
    pointStyle := "filled" }

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
    fontFamily := "Calibri, sans-serif"
    legendStyle := "box"
    borderStyle := "full"
    gridStyle := "horizontal"
    axisStyle := "frame"
    pointStyle := "filled-border" }

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
    fontFamily := "SF Mono, Menlo, monospace"
    legendStyle := "inline"
    borderStyle := "subtle"
    gridStyle := "horizontal"
    axisStyle := "lines"
    pointStyle := "filled" }

/-- Generate CSS from a theme. -/
def Theme.toCss (t : Theme) : String :=
  let border := match t.borderStyle with
    | "none" => "svg{border:none}"
    | "subtle" => "svg{border:1px solid #e8e8e8;border-radius:4px}"
    | _ => "svg{border:1px solid #999;border-radius:2px}"
  let grid := match t.gridStyle with
    | "horizontal" => s!"line.grid\{stroke:{t.gridColor};stroke-width:0.5}"
    | "full" => s!"line.grid\{stroke:{t.gridColor};stroke-width:0.5}"
    | _ => ""
  let point := match t.pointStyle with
    | "open" => s!"circle.point\{fill:none;stroke:{t.pointColor};stroke-width:1;opacity:{t.pointOpacity}}"
    | "filled-border" => s!"circle.point\{fill:{t.pointColor};stroke:#fff;stroke-width:0.5;opacity:{t.pointOpacity}}"
    | _ => s!"circle.point\{fill:{t.pointColor};opacity:{t.pointOpacity}}"
  s!"{border}" ++
  s!" svg\{background:{t.backgroundColor}}" ++
  s!" line.axis\{stroke:{t.axisColor};stroke-width:{t.axisWeight}}" ++
  s!" text.tick\{fill:#666;font-size:{t.tickFontSize}px;font-family:{t.fontFamily}}" ++
  s!" text.label\{fill:#333;font-size:{t.labelFontSize}px;font-family:{t.fontFamily};cursor:pointer}" ++
  s!" {point}" ++
  s!" circle.selected\{fill:{t.selectedColor};opacity:1}" ++
  s!" circle.excluded\{fill:{t.excludedColor};opacity:0.3}" ++
  s!" path.fit\{stroke:{t.fitColor};stroke-width:{t.fitWeight};fill:none}" ++
  s!" path.ci\{stroke:{t.ciColor};stroke-width:{t.ciWeight};fill:none;stroke-dasharray:4}" ++
  s!" {grid}" ++
  s!" .legend\{font-family:{t.fontFamily};font-size:12px}" ++
  s!" h2\{font-family:{t.fontFamily}}"

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

/-- Generate SVG rug marks along the X axis (bottom edge). -/
def rugX (xs : Array Float) (sx : Float → Float) (yPos : Float) (color : String := "#666") : String :=
  xs.foldl (fun acc x =>
    let px := sx x
    acc ++ s!"<line x1=\"{px}\" y1=\"{yPos}\" x2=\"{px}\" y2=\"{yPos - 4}\" stroke=\"{color}\" stroke-width=\"0.5\" opacity=\"0.4\"/>\n"
  ) ""

/-- Generate SVG rug marks along the Y axis (left edge). -/
def rugY (ys : Array Float) (sy : Float → Float) (xPos : Float) (color : String := "#666") : String :=
  ys.foldl (fun acc y =>
    let py := sy y
    acc ++ s!"<line x1=\"{xPos}\" y1=\"{py}\" x2=\"{xPos + 4}\" y2=\"{py}\" stroke=\"{color}\" stroke-width=\"0.5\" opacity=\"0.4\"/>\n"
  ) ""

/-- Draw axis lines spanning only the data range (Tufte range frame). -/
def rangeFrame (xMin xMax yMin yMax : Float) (sx sy : Float → Float) (color : String := "#999") : String :=
  let x1 := sx xMin; let x2 := sx xMax
  let y1 := sy yMin; let y2 := sy yMax
  s!"<line x1=\"{x1}\" y1=\"{y1}\" x2=\"{x2}\" y2=\"{y1}\" stroke=\"{color}\" stroke-width=\"0.75\"/>\n" ++
  s!"<line x1=\"{x1}\" y1=\"{y1}\" x2=\"{x1}\" y2=\"{y2}\" stroke=\"{color}\" stroke-width=\"0.75\"/>\n"

/-- Expand a range to include zero if the includeZero flag is set. -/
def expandToZero (mn mx : Float) (includeZero : Bool) : Float × Float :=
  if !includeZero then (mn, mx)
  else (if mn < 0 then mn else 0, if mx > 0 then mx else 0)

/-- Generate a vertical histogram SVG (bars go horizontal, stacked vertically).
    For use as a marginal distribution panel beside a scatter plot. -/
def verticalHistogram (data : Array Float) (sy : Float → Float)
    (xOffset : Float) (width : Float := 40) (bins : Nat := 10)
    (color : String := "steelblue") : String :=
  if data.size == 0 || bins == 0 then ""
  else
    let mn := data.foldl (fun acc v => if v < acc then v else acc) (data.getD 0 0)
    let mx := data.foldl (fun acc v => if v > acc then v else acc) (data.getD 0 0)
    let range := mx - mn
    if range == 0 then ""
    else
      let binWidth := range / bins.toFloat
      let counts := data.foldl (fun (acc : Array Nat) v =>
        let idx := ((v - mn) / binWidth).toUInt64.toNat
        let idx := if idx >= bins then bins - 1 else idx
        acc.set! idx ((acc.getD idx 0) + 1)
      ) (Array.mkArray bins 0)
      let maxCount := counts.foldl (fun acc c => if c > acc then c else acc) 0
      if maxCount == 0 then ""
      else Id.run do
        let mut svg := ""
        for i in List.range bins do
          let c := counts.getD i 0
          let binLo := mn + i.toFloat * binWidth
          let binHi := binLo + binWidth
          let yTop := sy binHi
          let yBot := sy binLo
          let h := (yBot - yTop).abs
          let barW := width * c.toFloat / maxCount.toFloat
          svg := svg ++ s!"<rect x=\"{xOffset}\" y=\"{if yTop < yBot then yTop else yBot}\" width=\"{barW}\" height=\"{h}\" fill=\"{color}\" opacity=\"0.5\"/>\n"
        return svg

end LeanStats.Plot
