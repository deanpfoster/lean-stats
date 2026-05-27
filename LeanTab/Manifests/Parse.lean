import LeanManifests.Basic
import LeanStats.Manifests.Util
import LeanTab.Sql.Parse

/-! # LeanTab.Manifests.Parse — claims about Sql.parseExpr

Proves that the SQL expression parser handles common predicates
and rejects empty input.
-/

set_option autoImplicit false

namespace LeanTab.Manifests.Parse
open LeanTab.Sql

/-- "age > 30" parses successfully -/
theorem parse_gt_proof : (parseExpr "age > 30").isSome = true := by native_decide

ProvenTheorem parse_gt : (parseExpr "age > 30").isSome = true

/-- Empty string fails to parse -/
theorem parse_empty_proof : (parseExpr "").isSome = false := by native_decide

ProvenTheorem parse_empty : (parseExpr "").isSome = false

/-- "x = 1 AND y = 2" parses successfully -/
theorem parse_and_proof : (parseExpr "x = 1 AND y = 2").isSome = true := by native_decide

ProvenTheorem parse_and : (parseExpr "x = 1 AND y = 2").isSome = true

/-- "name IS NULL" parses successfully -/
theorem parse_is_null_proof : (parseExpr "name IS NULL").isSome = true := by native_decide

ProvenTheorem parse_is_null : (parseExpr "name IS NULL").isSome = true

end LeanTab.Manifests.Parse
