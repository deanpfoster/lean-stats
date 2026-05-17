import Lake
open Lake DSL

package «lean-stats» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

-- Path-dep on lean-manifests (which currently exposes itself as
-- `dean_lean` / `DeanLean` due to a rename in progress).
require dean_lean from ".." / "lean-manifests"

@[default_target]
lean_lib «LeanStats» where
