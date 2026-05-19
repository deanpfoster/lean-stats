import LeanStats.Regression

/-! # LeanStats.Transform — variable transformations for linearizing

Stine & Foster Ch. 19–20: before fitting a line, try transformations
to straighten the relationship. The "ladder of powers" (Tukey):

  power > 1  → stretches large values (e.g. x²)
  power = 1  → identity
  power = 0.5 → sqrt (compresses large values mildly)
  power = 0  → log (compresses large values strongly)
  power < 0  → reciprocal family (flips and compresses)

We provide the common transforms plus a general power transform.
All operate element-wise on `Array Float` and handle edge cases
(log of non-positive, sqrt of negative, reciprocal of zero) by
returning 0 for those elements.
-/

set_option autoImplicit false

namespace LeanStats

/-- Natural log transform. Non-positive values → 0. -/
def logTransform (xs : Array Float) : Array Float :=
  xs.map fun x => if x > 0 then x.log else 0

/-- Square root transform. Negative values → 0. -/
def sqrtTransform (xs : Array Float) : Array Float :=
  xs.map fun x => if x ≥ 0 then x.sqrt else 0

/-- Reciprocal transform (1/x). Zero → 0. -/
def recipTransform (xs : Array Float) : Array Float :=
  xs.map fun x => if x != 0 then 1.0 / x else 0

/-- Power transform x^p. Handles x ≤ 0 for fractional p by returning 0. -/
def powerTransform (xs : Array Float) (p : Float) : Array Float :=
  xs.map fun x =>
    if p == 0 then (if x > 0 then x.log else 0)
    else if p == 1 then x
    else if x > 0 then Float.exp (p * x.log)
    else if x == 0 then 0
    else if p == (Float.round p) then x ^ p  -- integer powers OK for negative
    else 0  -- fractional power of negative → 0

/-- Which transform to try. Used by `bestTransform`. -/
inductive TransformKind where
  | identity | log | sqrt | recip | square
  deriving Repr, BEq

/-- Apply a named transform. -/
def applyTransform (xs : Array Float) : TransformKind → Array Float
  | .identity => xs
  | .log => logTransform xs
  | .sqrt => sqrtTransform xs
  | .recip => recipTransform xs
  | .square => xs.map (· ^ 2)

/-- Try each transform on y (response) and pick the one that gives
    the highest R² with x. Returns the best transform kind and R².
    This is the "try straightening" workflow from Stine & Foster. -/
def bestResponseTransform (xs ys : Array Float) : TransformKind × Float :=
  let transforms := #[TransformKind.identity, .log, .sqrt, .recip, .square]
  let results := transforms.map fun t =>
    let yt := applyTransform ys t
    let r := correlation xs yt
    (t, r ^ 2)
  results.foldl (fun best cur => if cur.2 > best.2 then cur else best)
    (.identity, 0)

end LeanStats
