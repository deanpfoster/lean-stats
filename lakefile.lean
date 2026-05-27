import Lake
open Lake DSL

package «lean-stats» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

-- Path-dep on lean-manifests (which currently exposes itself as
-- `lean_manifests` / `LeanManifests` due to a rename in progress).
require lean_manifests from ".." / "lean-manifests"

@[default_target]
lean_lib «LeanStats» where

lean_lib «LeanTab» where

script jstest do
  let out ← IO.Process.output { cmd := "node", args := #["tests/js/math_test.js"] }
  IO.print out.stdout
  if out.exitCode != 0 then
    IO.eprintln out.stderr
    return 1
  return 0
