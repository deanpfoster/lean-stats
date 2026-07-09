import LeanStats.Regression

/-! # LeanStats.Manifests.Util — shared utilities for manifest proofs

## Float equality in executable manifest tests

Float in Lean 4 has `BEq` and bit conversion, but not `DecidableEq`.
Manifest tests that compare computed floats should therefore compare
`Float.toBits` explicitly instead of manufacturing propositional equality.

This is intentionally weaker than `x = y`: it says the executable result has
the same bit pattern as the expected literal. That is the faithful thing Lean
can check here without a formal theorem relating Float bits to propositional
equality.

## String.containsSubstr

Lean 4.16 doesn't ship `String.containsSubstr`. We define it via
`splitOn` for use in report/plot manifest proofs.
-/

set_option autoImplicit false

namespace LeanStats.Manifests

/-- Bit-level equality for concrete Float test results. -/
def floatBitsEq (a b : Float) : Bool :=
  a.toBits == b.toBits

private def floatListBitsEq : List Float → List Float → Bool
  | [], [] => true
  | x :: xs, y :: ys => floatBitsEq x y && floatListBitsEq xs ys
  | _, _ => false

/-- Bit-level equality for arrays of concrete Float test results. -/
def floatArrayBitsEq (xs ys : Array Float) : Bool :=
  floatListBitsEq xs.toList ys.toList

/-- Bit-level equality for optional concrete Float test results. -/
def optionFloatBitsEq : Option Float → Option Float → Bool
  | some x, some y => floatBitsEq x y
  | none, none => true
  | _, _ => false

/-- Bit-level equality for optional arrays of concrete Float test results. -/
def optionFloatArrayBitsEq : Option (Array Float) → Option (Array Float) → Bool
  | some xs, some ys => floatArrayBitsEq xs ys
  | none, none => true
  | _, _ => false

/-- Bit-level equality for concrete `LinearFit` test results. -/
def linearFitBitsEq (a b : LeanStats.LinearFit) : Bool :=
  floatBitsEq a.slope b.slope &&
  floatBitsEq a.intercept b.intercept &&
  floatBitsEq a.r2 b.r2 &&
  a.n == b.n

/-- Bit-level equality for optional concrete `LinearFit` test results. -/
def optionLinearFitBitsEq : Option LeanStats.LinearFit → Option LeanStats.LinearFit → Bool
  | some x, some y => linearFitBitsEq x y
  | none, none => true
  | _, _ => false

/-- Check if `needle` is a substring of `haystack`. -/
def String.containsSubstr (haystack needle : String) : Bool :=
  (haystack.splitOn needle).length > 1

end LeanStats.Manifests
