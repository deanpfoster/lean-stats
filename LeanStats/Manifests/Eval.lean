import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanStats.Eval

/-! # LeanStats.Manifests.Eval — claims about evalString

Proves that the expression evaluator correctly dispatches known
functions and rejects unknown ones / wrong arg counts.
-/
-- Implementation: LeanStats/Eval.lean

set_option autoImplicit false

namespace LeanStats.Manifests.Eval
open LeanStats.Eval

private def isOk (r : Except String String) : Bool := r.isOk
private def isErr (r : Except String String) : Bool := !r.isOk
private def resultContains (r : Except String String) (needle : String) : Bool :=
  match r with
  | .ok s => LeanStats.Manifests.String.containsSubstr s needle
  | .error _ => false

/-- evalString "mean([1, 2, 3])" returns .ok -/
theorem eval_mean_ok_proof : isOk (evalString "mean([1, 2, 3])") = true := by native_decide

ProvenTheorem eval_mean_ok : isOk (evalString "mean([1, 2, 3])") = true

/-- evalString "variance([2, 4, 4, 4, 5, 5, 7, 9])" returns .ok -/
theorem eval_variance_ok_proof : isOk (evalString "variance([2, 4, 4, 4, 5, 5, 7, 9])") = true := by native_decide

ProvenTheorem eval_variance_ok : isOk (evalString "variance([2, 4, 4, 4, 5, 5, 7, 9])") = true

/-- evalString "correlation([1,2,3], [1,2,3])" returns .ok containing "1" -/
theorem eval_correlation_ok_proof : resultContains (evalString "correlation([1,2,3], [1,2,3])") "1" = true := by native_decide

ProvenTheorem eval_correlation_ok : resultContains (evalString "correlation([1,2,3], [1,2,3])") "1" = true

/-- evalString "blorp([1])" returns .error (unknown function) -/
theorem eval_unknown_fn_proof : isErr (evalString "blorp([1])") = true := by native_decide

ProvenTheorem eval_unknown_fn : isErr (evalString "blorp([1])") = true

/-- evalString "mean()" returns .error (wrong arg count) -/
theorem eval_wrong_args_proof : isErr (evalString "mean()") = true := by native_decide

ProvenTheorem eval_wrong_args : isErr (evalString "mean()") = true

end LeanStats.Manifests.Eval
