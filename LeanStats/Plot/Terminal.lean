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
    let grid := data.foldl (init := Array.mkArray height (Array.mkArray width 0))
      fun grid (x, y) =>
        let px := ((x - xmin) / xrange * (pw - 1).toFloat).toUInt64.toNat
        let py := ((ymax - y) / yrange * (ph - 1).toFloat).toUInt64.toNat
        let cx := Nat.min (px / 2) (width - 1)
        let cy := Nat.min (py / 4) (height - 1)
        let bx := px % 2
        let by_ := py % 4
        let row := grid.getD cy (Array.mkArray width 0)
        let cell := row.getD cx 0
        let newCell := cell ||| brailleBit bx by_
        grid.set! cy (row.set! cx newCell)
    -- Render to string
    let lines := grid.map fun row =>
      String.mk (row.toList.map brailleChar)
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
    let counts := data.foldl (init := Array.mkArray bins' 0) fun acc v =>
      let idx := ((v - mn) / binWidth).toUInt64.toNat
      let idx := if idx >= bins' then bins' - 1 else idx
      acc.set! idx (acc.getD idx 0 + 1)
    let maxCount := counts.foldl Nat.max 0
    if maxCount == 0 then "(no data)"
    else
      -- Render top-to-bottom
      let blocks := "▁▂▃▄▅▆▇█"
      let lines := (List.range height).reverse.map fun row =>
        let threshold := (row.toFloat + 1) / height.toFloat
        String.mk (counts.toList.map fun c =>
          let frac := c.toFloat / maxCount.toFloat
          if frac >= threshold then '█'
          else if frac > (row.toFloat / height.toFloat) then
            let subLevel := ((frac - row.toFloat / height.toFloat) * height.toFloat * 8).toUInt64.toNat
            (blocks.get? ⟨Nat.min subLevel 7⟩).getD ' '
          else ' ')
      String.intercalate "\n" lines

/-- Sparkline: a single-line mini chart using block characters. -/
def sparkline (data : Array Float) : String :=
  if data.isEmpty then ""
  else
    let mn := data.foldl (fun a b => if b < a then b else a) data[0]!
    let mx := data.foldl (fun a b => if b > a then b else a) data[0]!
    let range := if mx == mn then 1.0 else mx - mn
    let blocks := "▁▂▃▄▅▆▇█"
    String.mk (data.toList.map fun v =>
      let level := ((v - mn) / range * 7).toUInt64.toNat
      (blocks.get? ⟨Nat.min level 7⟩).getD '▁')

/-- Residual plot as terminal scatter (fitted vs residuals). -/
def terminalResidPlot (diag : LeanStats.RegressionDiag)
    (width : Nat := 60) (height : Nat := 15) : String :=
  let data := diag.fitted.zip diag.residuals
  terminalScatter data width height

end LeanStats.Plot.Terminal
