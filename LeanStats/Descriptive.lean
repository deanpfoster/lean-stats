/-! # LeanStats.Descriptive — mean, variance, quantiles

Pure descriptive statistics over `Array Float`. All functions are
total and deterministic; manifest claims about their structural
properties live in `LeanStats/Manifests/Descriptive.lean`.

## What's here

  - `mean`, `variance`, `stdDev`
  - `median`, `quantile`
  - `summary` (combined record)

## What's not here

  - Weighted statistics (TODO)
  - Robust estimators (median absolute deviation, trimmed means) — TODO
  - Anything that needs IO (file reading, etc.) — by design, this is a
    pure library; CSV/file ingestion happens at the consumer layer.
-/

set_option autoImplicit false

namespace LeanStats

def mean (xs : Array Float) : Float :=
  if xs.isEmpty then 0 else xs.foldl (· + ·) 0 / xs.size.toFloat

def variance (xs : Array Float) : Float :=
  let m := mean xs
  if xs.size ≤ 1 then 0
  else (xs.map (fun x => (x - m) ^ 2)).foldl (· + ·) 0 / (xs.size - 1).toFloat

def stdDev (xs : Array Float) : Float := (variance xs).sqrt

def sortArray (xs : Array Float) : Array Float :=
  xs.qsort (· < ·)

def median (xs : Array Float) : Float :=
  if xs.isEmpty then 0
  else
    let s := sortArray xs
    let n := s.size
    if n % 2 == 1 then s[n / 2]!
    else (s[n / 2 - 1]! + s[n / 2]!) / 2

def quantile (xs : Array Float) (q : Float) : Float :=
  if xs.isEmpty then 0
  else
    let s := sortArray xs
    let n := s.size
    let idx := q * (n - 1).toFloat
    let lo := idx.toUInt64.toNat
    let hi := lo + 1
    let frac := idx - lo.toFloat
    if hi ≥ n then s[n - 1]!
    else s[lo]! * (1 - frac) + s[hi]! * frac

structure Summary where
  n : Nat
  mean : Float
  sd : Float
  min : Float
  q25 : Float
  median : Float
  q75 : Float
  max : Float
  deriving Repr

def summary (xs : Array Float) : Summary :=
  let s := sortArray xs
  { n := xs.size
    mean := mean xs
    sd := stdDev xs
    min := if s.isEmpty then 0 else s[0]!
    q25 := quantile xs 0.25
    median := median xs
    q75 := quantile xs 0.75
    max := if s.isEmpty then 0 else s[s.size - 1]! }

end LeanStats
