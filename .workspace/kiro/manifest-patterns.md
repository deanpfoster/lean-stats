# Manifest patterns for lean-stats

*Concrete examples of how to write good manifest claims for this
specific library. Reference `lean-manifests/templates/MANIFEST_GUIDE.md`
for the principles; this file applies them to lean-stats.*

---

## Pattern 1: Decidable identity claims

For functions that operate on small fixed inputs, prove with
`decide` or `native_decide`:

```lean
-- BAD (placeholder, vacuous):
UnprovenConjecture mean_simple : True

-- GOOD:
ProvenTheorem mean_of_one_two_three :
  mean #[1.0, 2.0, 3.0] = 2.0 := by native_decide

ProvenTheorem mean_of_zeros :
  mean #[0.0, 0.0, 0.0, 0.0, 0.0] = 0.0 := by native_decide

ProvenTheorem variance_of_constant_is_zero :
  variance #[5.0, 5.0, 5.0] = 0.0 := by native_decide
```

These are the cheapest wins. Most functions in `Descriptive.lean`
should have a handful of `native_decide` ProvenTheorems.

## Pattern 2: Test-backed sample claims

For properties that hold over many inputs but aren't trivially
decidable (because of Float precision, division, etc.), use the
`registerTestResults` pattern:

```lean
-- Define a Bool predicate over a sample set
def testCorrelationOnLinear : Bool :=
  let samples := [
    (#[1.0, 2.0, 3.0], #[2.0, 4.0, 6.0]),     -- y = 2x → r ≈ 1
    (#[1.0, 2.0, 3.0], #[3.0, 2.0, 1.0]),     -- y = -x + 4 → r ≈ -1
    (#[1.0, 2.0, 3.0], #[1.0, 1.0, 1.0]),     -- constant → degenerate
    -- ...
  ]
  samples.all fun (xs, ys) =>
    let r := correlation xs ys
    r.abs ≤ 1.0 + 1e-9  -- correlation is in [-1, 1]

registerTestResults correlation_in_range passed 10 total 10
TestedConjecture correlation_in_range :
  testCorrelationOnLinear = true := by native_decide
```

The `registerTestResults` decoration makes the sample size visible
in the build log. Grow the sample set over time; the proof
regenerates.

## Pattern 3: Adversarial corpus for parser/renderer totality

For `Svg.render` (the only `partial def` in the library), use the
adversarial-corpus pattern from `MANIFEST_GUIDE.md` §5a:

```lean
def stressInputs : List Svg := [
  -- deeply nested groups
  Svg.group (List.replicate 100 (Svg.rect 0 0 1 1)),
  -- empty group
  Svg.group [],
  -- many siblings
  Svg.group (List.replicate 1000 (Svg.line 0 0 1 1)),
  -- ...
]

def runRenderStressPure : Bool :=
  stressInputs.all fun s => (Svg.render s).length ≥ 0

ProvenTheorem render_terminates_on_corpus :
  runRenderStressPure = true := by native_decide
```

The kernel runs the corpus during proof check. If `Svg.render`
diverges on any input, the build hangs.

## Pattern 4: Universal claims that decompose

`OLS minimizes squared residuals` is universally quantified and
not directly decidable. But it decomposes into:

1. **Necessary conditions** (which ARE decidable): the slope and
   intercept satisfy the normal equations on a curated input set.
2. **Algebraic identity** (potentially provable): for the OLS
   formula, `∂/∂β SSR = 0` and `∂/∂α SSR = 0` evaluated at the
   computed (α, β) hold.

Start with #1 as `TestedConjecture`. Get to #2 as `ProvenTheorem`
later if time allows.

```lean
-- Test the normal equations on a sample
def normalEquationsHold : Bool :=
  let samples := [...]
  samples.all fun (xs, ys) =>
    match linearRegression xs ys with
    | none => true  -- degenerate; vacuously
    | some fit =>
      let n := xs.size.toFloat
      let xbar := mean xs
      let ybar := mean ys
      let residuals := (xs.zip ys).map fun (x, y) => y - (fit.intercept + fit.slope * x)
      -- normal equations: Σ residuals = 0  ∧  Σ x*residuals = 0
      (residuals.sum.abs < 1e-9) ∧
      ((xs.zip residuals).map (fun (x, r) => x * r)).sum.abs < 1e-9

TestedConjecture ols_satisfies_normal_equations :
  normalEquationsHold = true := by native_decide
```

This is real evidence the regression is OLS, not just "I named it OLS."

## Pattern 5: Output well-formedness

For `renderHtml` and `Svg.render`, the output is a string that
should satisfy structural properties:

```lean
-- Define what "well-formed SVG" means at a structural level
def isWellFormedSvg (s : String) : Bool :=
  s.startsWith "<svg" ∧ s.endsWith "</svg>" ∧ <other checks>

-- Test on a corpus
def renderWellFormed : Bool :=
  testInputs.all fun input => isWellFormedSvg (Svg.render input)

ProvenTheorem render_produces_wellformed_svg :
  renderWellFormed = true := by native_decide
```

This is the safety claim the user actually cares about: "the output
is parseable as SVG." Don't skip it.

## Anti-pattern reminder

DO NOT write claims like:

```lean
-- BAD: vacuous (always provable for any function)
UnprovenConjecture parse_total : ∀ s, ∃ d, parse s = d

-- BAD: True-typed
UnprovenConjecture pure_no_io : True

-- BAD: trivially decidable left as Unproven
UnprovenConjecture mean_of_empty : mean #[] = 0.0
  -- ← this can be `decide`d in seconds; promote it
```

Every claim should ASSERT something falsifiable.

## Headline `Manifest.lean` shape

After per-axis manifests are filled in, the headline file should be
mostly `Restate` invocations:

```lean
import LeanStats.Manifests.Descriptive
import LeanStats.Manifests.Regression
import LeanStats.Manifests.Plot
import LeanStats.Manifests.Report

namespace LeanStats.Manifest
open LeanStats

Restate Descriptive.mean_of_one_two_three from LeanStats.Manifests
Restate Regression.ols_satisfies_normal_equations from LeanStats.Manifests
Restate Plot.render_produces_wellformed_svg from LeanStats.Manifests
-- etc.

end LeanStats.Manifest
```

The headline becomes a **dashboard** — one line per claim, evidence
level visible in the build log via `Restate`. No duplicated full
statements.

## Order of attack

If you're picking up work and don't know where to start:

1. **`Descriptive.lean` claims first** — easiest, mostly
   `native_decide` on small fixtures.
2. **Then `Regression.lean`** — sample-based normal-equations test.
3. **Then `Plot.lean`** — well-formedness corpus + svg_render
   termination.
4. **`Tests.lean`** — t-statistic identity.
5. **`Report.lean`** — escaping (significant new work).

Don't try to do them all in one pass. Do one, commit, build green,
move to the next.

— Kiro (master)
