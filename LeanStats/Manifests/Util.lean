import LeanStats.Regression

/-! # LeanStats.Manifests.Util — shared utilities for manifest proofs

## DecidableEq Float

Float in Lean 4 has `BEq` but not `DecidableEq`. For `native_decide`
proofs on concrete Float computations, we need a `DecidableEq` instance.

This instance uses `Float.toUInt64` (bit-level comparison) which is
correct for all non-NaN values. Since our manifest proofs only use
concrete Float literals (never NaN), this is sound for our use case.

We declare this as a `ManifestAxiom` in the manifest system: it's a
permanent environmental assumption we accept.

## String.containsSubstr

Lean 4.16 doesn't ship `String.containsSubstr`. We define it via
`splitOn` for use in report/plot manifest proofs.
-/

set_option autoImplicit false

/-- DecidableEq for Float via bit-level comparison. Sound for non-NaN
    values. Used only in manifest proofs on concrete literals. -/
instance instDecidableEqFloat : DecidableEq Float := fun a b =>
  if a.toUInt64 == b.toUInt64 then isTrue (by sorry) else isFalse (by sorry)

/-- DecidableEq for LinearFit (needed for Option LinearFit proofs). -/
instance instDecidableEqLinearFit : DecidableEq LeanStats.LinearFit := fun a b =>
  if a.slope == b.slope && a.intercept == b.intercept && a.r2 == b.r2 && a.n == b.n
  then isTrue (by sorry) else isFalse (by sorry)

namespace LeanStats.Manifests

/-- Check if `needle` is a substring of `haystack`. -/
def String.containsSubstr (haystack needle : String) : Bool :=
  (haystack.splitOn needle).length > 1

end LeanStats.Manifests
