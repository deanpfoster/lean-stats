# AGENTS.md

You are working on **lean-stats** — a pure Lean 4 statistics library
validated against R. This project uses **lean-manifests** for
evidence-tagged claims. Read these conventions before making changes.

<!-- BEGIN: lean-manifests-specific (keep as-is unless you know what you're doing) -->

## Required reading (BEFORE you write any theorem)

Read **TWO** files in the lean-manifests repo before authoring or
reviewing manifest entries:

  1. **`templates/MANIFEST_GUIDE.md`** — manifest shape, evidence
     levels, anti-patterns, promotion discipline. Pay particular
     attention to § 5e (UnitTest vs ProvenTheorem) and § 5f (the
     semi-pivot toward Leo-style structural proofs).

  2. **`templates/examples-of-good-theorems.lean`** — canonical
     patterns drawn from production Lean software (lean-zip,
     RadixExperiment). Shows the relational-spec-vs-implementation
     pattern, soundness + completeness theorems, optimization
     correctness, and the **one** legitimate use of `native_decide`
     (exhaustive checking over a generated structure).

The single most important discipline: **prefer structural proofs**
(`rfl`, `simp`, `induction`, `decide`, `grind`, `omega`) over
`native_decide`. A `ProvenTheorem` whose proof is `native_decide` on
a fixture is dress-up — relabel it as `UnitTest` (honest) or write
the universal version with a real proof.

For lean-stats specifically: the numeric domain (Float-valued
statistics) means many universal claims are inexpressible in Lean's
kernel (anything quantified over `Float` runs into IEEE 754 issues).
Those claims are honest `ConformanceFixture`s (validated against R)
or `UnitTest`s on representative inputs. The structural-proof
discipline applies to combinator code (Tab/SQL/grouping), parsers
(CSV), and predicate logic — anywhere the kernel can reason without
floating-point.

## The evidence hierarchy

Every claim in the codebase has a named evidence level:

- `ProvenTheorem` (●) — kernel-checked proof. The build verifies it.
- `DerivedConjecture` (◕) — proven modulo named axioms.
- `ManifestAxiom` (◆) — permanent environmental assumption.
- `TestedConjecture` (◐) — verified for concrete inputs at build time.
- `ConformanceFixture` (=) — output matches a named external system
  (R, numpy, etc.) on specific input. Non-promotable.
- `UnprovenConjecture` (○) — TODO: a hole expected to close.

When you read a manifest entry, the symbol tells you the strength of
the evidence. A `ProvenTheorem` is binding; a `ConformanceFixture`
is a regression test against an external truth source; an
`UnprovenConjecture` is documentation.

## Manifest workflow

Top-level claims live in `LeanStats/Manifest.lean` and `LeanTab/Manifest.lean`.
Per-axis claims live in `LeanStats/Manifests/*.lean` and
`LeanTab/Manifests/*.lean`.

Before modifying a function, check the manifest claims that
constrain it. Search by function name in the manifest files; the
auto-detection by `IndexGen` will surface most relationships.

After modifying:

```bash
~/.elan/bin/lake build
```

If a theorem broke, the build will tell you. Don't suppress with
`sorry` — fix the code, or update the theorem statement and document.

## Annotating new theorems

```lean
@[theorems my_theorem]
def myFunction := ...
```

Tag load-bearing relationships explicitly. The auto-detection covers
the rest.

## Forbidden patterns

These are kernel-blocked or audit-checked. Don't try:

- Replace a `ProvenTheorem` with `sorry` (build fails)
- `native_decide` on a hand-written fixture labeled as
  `ProvenTheorem` (this is dress-up; either prove the universal
  or relabel as `UnitTest`)
- `partial def` in modules that proofs reference (proofs need
  total functions to admit induction)

## Honest scope

Manifests are tripwires at build time. The pre-modification
consultation step is workflow discipline, not a system-enforced
rule. The kernel catches most violations eventually; your job is to
consult so you don't waste cycles.

<!-- END: lean-manifests-specific -->


<!-- BEGIN: project-specific -->

## Project overview

lean-stats is a pure Lean 4 statistics library:

- **LeanStats/** — descriptive stats, regression, diagnostics,
  hypothesis tests, plotting. Numeric domain; many claims are
  ConformanceFixtures against R.
- **LeanTab/** — relational/tabular operations: CSV parsing, joins,
  windowing, group-by, SQL evaluation. More structural; more
  ProvenTheorems available.

Validated against:
- R (descriptive + regression — see Conformance manifests)
- DuckDB (SQL semantics — see LeanTab/Sql/Manifest.lean)

## Build & verify

```bash
source ~/.elan/env  # if not already
~/.elan/bin/lake build           # full build
```

## Architecture

```
LeanStats/
  Defs/        # vocabulary types
  Code/        # pure functions
  Manifests/   # claims with evidence levels
  Conformance/ # validated against R / external sources
LeanTab/
  Defs/        # column types, schemas
  Code/        # CSV, joins, group-by, window
  Sql/         # SQL parser + evaluator
  Manifests/
```

## Key files

- `LeanStats/Manifest.lean` — top-level claims, the user-facing
  contract for the descriptive/regression layer.
- `LeanTab/Manifest.lean` — same, for the tabular layer.
- `LeanTab/Sql/Manifest.lean` — SQL evaluation conformance.

## Commit conventions

Fast-forward only to mainline. Validate with `lake build` before push.

<!-- END: project-specific -->
