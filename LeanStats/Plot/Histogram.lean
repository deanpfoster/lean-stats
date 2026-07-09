import LeanStats.Plot.Axes

/-! # LeanStats.Plot.Histogram — histogram plot -/

set_option autoImplicit false

namespace LeanStats.Plot

def histogram (data : Array Float) (bins : Nat := 10) (opts : PlotOptions := {}) : Svg :=
  let bins' := if bins == 0 then 1 else bins
  let mn := data.foldl (fun a b => if a < b then a else b) (data.getD 0 0)
  let mx := data.foldl (fun a b => if a > b then a else b) (data.getD 0 0)
  let range := if mx == mn then 1.0 else mx - mn
  let binWidth := range / Float.ofNat bins'
  let counts := Array.replicate bins' 0
  let counts := data.foldl (init := counts) fun acc v =>
    let fi := (v - mn) / binWidth
    let idx := fi.toUInt64.toNat
    let idx := if idx >= bins' then bins' - 1 else idx
    acc.set! idx (acc.getD idx 0 + 1)
  let maxCount := counts.foldl Nat.max 0
  let xScale : Scale :=
    { domainMin := mn
      domainMax := mx
      rangeMin := opts.marginLeft
      rangeMax := opts.marginLeft + opts.plotWidth }
  let yScale : Scale :=
    { domainMin := 0
      domainMax := Float.ofNat maxCount
      rangeMin := opts.marginTop + opts.plotHeight
      rangeMax := opts.marginTop }
  let axes := drawAxes xScale yScale opts
  let barW := opts.plotWidth / Float.ofNat bins'
  let bars := List.range bins' |>.map fun i =>
    let count := counts.getD i 0
    let barH := if maxCount == 0 then 0.0
      else (Float.ofNat count) / (Float.ofNat maxCount) * opts.plotHeight
    let x := opts.marginLeft + Float.ofNat i * barW
    let y := opts.marginTop + opts.plotHeight - barH
    Svg.rect x y barW barH [attr "fill" "steelblue", attr "stroke" "white"]
  Svg.group ([axes] ++ bars) []

end LeanStats.Plot
