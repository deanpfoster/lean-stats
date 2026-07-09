import LeanStats.Descriptive
import LeanStats.Diagnostics

/-! # LeanStats.Plot.Terminal — Unicode terminal plots

Renders charts as plain strings using Unicode braille/block characters.
Works in any terminal, any tmux version. No escape sequences, no
external dependencies — just String output.

Braille characters (U+2800–U+28FF) give 2×4 pixel resolution per
character cell. An 80×24 area gives 160×96 "pixels."

Block characters (▁▂▃▄▅▆▇█) give 1×8 vertical resolution per cell.
Good for histograms and sparklines.
-/

set_option autoImplicit false

namespace LeanStats.Plot.Terminal

/-- Braille dot positions: (col 0-1, row 0-3) → bit index.
    Col 0: bits 0,1,2,6  Col 1: bits 3,4,5,7 -/
private def brailleBit (col row : Nat) : UInt8 :=
  match col, row with
  | 0, 0 => 0x01 | 0, 1 => 0x02 | 0, 2 => 0x04 | 0, 3 => 0x40
  | 1, 0 => 0x08 | 1, 1 => 0x10 | 1, 2 => 0x20 | 1, 3 => 0x80
  | _, _ => 0

/-- Render a braille character from a bitmask. -/
private def brailleChar (bits : UInt8) : Char :=
  Char.ofNat (0x2800 + bits.toNat)

/-- Scatter plot rendered as Unicode braille. Returns a multi-line string.
    `width` and `height` are in character cells (actual resolution is 2x × 4x). -/
def terminalScatter (data : Array (Float × Float))
    (width : Nat := 60) (height : Nat := 20) : String :=
  if data.isEmpty then "(empty)"
  else
    let xs := data.map Prod.fst
    let ys := data.map Prod.snd
    let xmin := xs.foldl (fun a b => if b < a then b else a) xs[0]!
    let xmax := xs.foldl (fun a b => if b > a then b else a) xs[0]!
    let ymin := ys.foldl (fun a b => if b < a then b else a) ys[0]!
    let ymax := ys.foldl (fun a b => if b > a then b else a) ys[0]!
    let xrange := if xmax == xmin then 1.0 else xmax - xmin
    let yrange := if ymax == ymin then 1.0 else ymax - ymin
    let pw := width * 2   -- pixel width
    let ph := height * 4  -- pixel height
    -- Rasterize points into a grid
    let grid := data.foldl (init := Array.replicate height (Array.replicate width 0))
      fun grid (x, y) =>
        let px := ((x - xmin) / xrange * (pw - 1).toFloat).toUInt64.toNat
        let py := ((ymax - y) / yrange * (ph - 1).toFloat).toUInt64.toNat
        let cx := Nat.min (px / 2) (width - 1)
        let cy := Nat.min (py / 4) (height - 1)
        let bx := px % 2
        let by_ := py % 4
        let row := grid.getD cy (Array.replicate width 0)
        let cell := row.getD cx 0
        let newCell := cell ||| brailleBit bx by_
        grid.set! cy (row.set! cx newCell)
    -- Render to string
    let lines := grid.map fun row =>
      String.ofList (row.toList.map brailleChar)
    String.intercalate "\n" lines.toList

/-- Histogram rendered as Unicode block characters (▁▂▃▄▅▆▇█). -/
def terminalHistogram (data : Array Float)
    (bins : Nat := 40) (height : Nat := 10) : String :=
  if data.isEmpty then "(empty)"
  else
    let bins' := if bins == 0 then 1 else bins
    let mn := data.foldl (fun a b => if b < a then b else a) data[0]!
    let mx := data.foldl (fun a b => if b > a then b else a) data[0]!
    let range := if mx == mn then 1.0 else mx - mn
    let binWidth := range / bins'.toFloat
    -- Count per bin
    let counts := data.foldl (init := Array.replicate bins' 0) fun acc v =>
      let idx := ((v - mn) / binWidth).toUInt64.toNat
      let idx := if idx >= bins' then bins' - 1 else idx
      acc.set! idx (acc.getD idx 0 + 1)
    let maxCount := counts.foldl Nat.max 0
    if maxCount == 0 then "(no data)"
    else
      -- Render top-to-bottom
      let blocks : Array Char := #['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
      let lines := (List.range height).reverse.map fun row =>
        let threshold := (row.toFloat + 1) / height.toFloat
        String.ofList (counts.toList.map fun c =>
          let frac := c.toFloat / maxCount.toFloat
          if frac >= threshold then '█'
          else if frac > (row.toFloat / height.toFloat) then
            let subLevel := ((frac - row.toFloat / height.toFloat) * height.toFloat * 8).toUInt64.toNat
            (blocks[Nat.min subLevel 7]?).getD ' '
          else ' ')
      String.intercalate "\n" lines

/-- Sparkline: a single-line mini chart using block characters. -/
def sparkline (data : Array Float) : String :=
  if data.isEmpty then ""
  else
    let mn := data.foldl (fun a b => if b < a then b else a) data[0]!
    let mx := data.foldl (fun a b => if b > a then b else a) data[0]!
    let range := if mx == mn then 1.0 else mx - mn
    let blocks : Array Char := #['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
    String.ofList (data.toList.map fun v =>
      let level := ((v - mn) / range * 7).toUInt64.toNat
      (blocks[Nat.min level 7]?).getD '▁')

/-- Residual plot as terminal scatter (fitted vs residuals). -/
def terminalResidPlot (diag : LeanStats.RegressionDiag)
    (width : Nat := 60) (height : Nat := 15) : String :=
  let data := diag.fitted.zip diag.residuals
  terminalScatter data width height

/-- Dotplot: each observation as a dot stacked at its value.
    Good for small n (< 50) where you want to see every point. -/
def terminalDotplot (data : Array Float) (width : Nat := 60) : String :=
  if data.isEmpty then "(empty)"
  else
    let mn := data.foldl (fun a b => if b < a then b else a) data[0]!
    let mx := data.foldl (fun a b => if b > a then b else a) data[0]!
    let range := if mx == mn then 1.0 else mx - mn
    -- Bin each value into a column
    let bins := data.foldl (init := Array.replicate width 0) fun acc v =>
      let idx := ((v - mn) / range * (width - 1).toFloat).toUInt64.toNat
      let idx := if idx >= width then width - 1 else idx
      acc.set! idx (acc.getD idx 0 + 1)
    let maxStack := bins.foldl Nat.max 0
    if maxStack == 0 then "(no data)"
    else
      -- Render top-down: each row shows dots where count >= row level
      let rows := (List.range maxStack).reverse.map fun row =>
        String.ofList (bins.toList.map fun c =>
          if c > row then '•' else ' ')
      let axis := String.ofList (List.replicate width '─')
      let label := s!"  {mn}                                              {mx}"
      String.intercalate "\n" (rows ++ [axis, label])

/-- Boxplot: five-number summary as ASCII art.
    Shows median, quartiles, whiskers, and outliers (*). -/
def terminalBoxplot (data : Array Float) (width : Nat := 60) (label : String := "") : String :=
  if data.isEmpty then "(empty)"
  else
    let sorted := data.qsort (· < ·)
    let n := sorted.size
    let q1 := sorted[n / 4]!
    let med := sorted[n / 2]!
    let q3 := sorted[3 * n / 4]!
    let iqr := q3 - q1
    let wLo := q1 - 1.5 * iqr
    let wHi := q3 + 1.5 * iqr
    -- Actual whisker endpoints (nearest data within fence)
    let lo := sorted.foldl (fun best v => if v >= wLo && v < best then v else best) q1
    let hi := sorted.foldl (fun best v => if v <= wHi && v > best then v else best) q3
    let mn := sorted[0]!
    let mx := sorted[n - 1]!
    let dispMin := if mn < wLo then mn else lo
    let dispMax := if mx > wHi then mx else hi
    let range := if dispMax == dispMin then 1.0 else dispMax - dispMin
    let pos (v : Float) : Nat :=
      let p := ((v - dispMin) / range * (width - 1).toFloat).toUInt64.toNat
      if p >= width then width - 1 else p
    -- Build the line using folds
    let line := (Array.range width).map fun i =>
      let pLo := pos lo
      let pQ1 := pos q1
      let pQ3 := pos q3
      let pHi := pos hi
      let pMed := pos med
      -- Check outliers
      let isOutlier := sorted.any fun v => (v < wLo || v > wHi) && pos v == i
      if isOutlier then '*'
      else if i == pMed then '┃'
      else if i == pQ1 then '├'
      else if i == pQ3 then '┤'
      else if i >= pLo && i <= pHi then '─'
      else ' '
    let lbl := if label == "" then "  " else s!"  {label} "
    lbl ++ String.ofList line.toList

/-- Side-by-side dotplots for comparing groups.
    Each group gets its own row, all on the same scale. -/
def terminalGroupDotplot (groups : Array (String × Array Float)) (width : Nat := 50) : String :=
  if groups.isEmpty then "(empty)"
  else
    -- Find global min/max
    let allVals := groups.foldl (fun acc (_, vs) => acc ++ vs) #[]
    if allVals.isEmpty then "(no data)"
    else
      let mn := allVals.foldl (fun a b => if b < a then b else a) allVals[0]!
      let mx := allVals.foldl (fun a b => if b > a then b else a) allVals[0]!
      let range := if mx == mn then 1.0 else mx - mn
      -- Find max label width for alignment
      let maxLabelW := groups.foldl (fun best (name, _) => Nat.max best name.length) 0
      let pad (s : String) : String := s ++ String.ofList (List.replicate (maxLabelW - s.length) ' ')
      -- Render each group
      let rows := groups.toList.map fun (name, vals) =>
        let dots := Array.replicate width ' '
        let dots := vals.foldl (fun acc v =>
          let idx := ((v - mn) / range * (width - 1).toFloat).toUInt64.toNat
          let idx := if idx >= width then width - 1 else idx
          acc.set! idx '•') dots
        s!"  {pad name} │{String.ofList dots.toList}│"
      let axis := s!"  {pad ""} └{String.ofList (List.replicate width '─')}┘"
      let label := s!"  {pad ""} {mn}{String.ofList (List.replicate (width - 12) ' ')}{mx}"
      String.intercalate "\n" (rows ++ [axis, label])

/-- Side-by-side boxplots for comparing groups. -/
def terminalGroupBoxplot (groups : Array (String × Array Float)) (width : Nat := 50) : String :=
  if groups.isEmpty then "(empty)"
  else
    let allVals := groups.foldl (fun acc (_, vs) => acc ++ vs) #[]
    if allVals.isEmpty then "(no data)"
    else
      let mn := allVals.foldl (fun a b => if b < a then b else a) allVals[0]!
      let mx := allVals.foldl (fun a b => if b > a then b else a) allVals[0]!
      let maxLabelW := groups.foldl (fun best (name, _) => Nat.max best name.length) 0
      let pad (s : String) : String := s ++ String.ofList (List.replicate (maxLabelW - s.length) ' ')
      let rows := groups.toList.map fun (name, vals) =>
        let bp := terminalBoxplot vals width name
        bp
      let label := s!"  {pad ""}{mn}{String.ofList (List.replicate (width - 12) ' ')}{mx}"
      String.intercalate "\n" (rows ++ [label])

/-- Formatted regression summary (Minitab-style). -/
def regressionTable (diag : LeanStats.RegressionDiag) (xName : String := "x") (yName : String := "y") : String :=
  let eq := s!"  {yName} = {diag.intercept} + {diag.slope} {xName}"
  let n := diag.n
  let adjR2 := 1.0 - (1.0 - diag.r2) * (n.toFloat - 1.0) / (n.toFloat - 2.0)
  let header := s!"The regression equation is\n{eq}\n"
  let table := s!"Predictor      Coef       SE\n" ++
    s!"Constant   {diag.intercept}   {diag.se}\n" ++
    s!"{xName}         {diag.slope}   {diag.se}\n"
  let summary := s!"\nS = {diag.se}   R² = {diag.r2}   R²(adj) = {adjR2}\n" ++
    s!"n = {n}   Durbin-Watson = {diag.durbinWatson}"
  header ++ "\n" ++ table ++ summary

end LeanStats.Plot.Terminal
