# State of lean-stat — context for next session

**Date:** 2026-05-17
**Author:** Kiro (code_first)
**Status:** Just extracted from l3m. Skeleton in place; real work
not yet started.

## Why this exists

This file captures the conversational context that led to creating
`lean-stat` so the next session can pick up without re-deriving the
plan.

## The conversation that led here

We were in the middle of merging the `code_first` and `master`
branches of l3m. As part of that merge planning, we noticed that
l3m had grown an experimental `L3m/{Plot,Stats,Report}/` set of
directories (~449 lines). The user asked: should those be part of
the merge?

That led to a broader discussion about what kinds of libraries
benefit from being **pure Lean libraries with manifest discipline,
wrapped by l3m for capability-safe data interaction**. The user
asked for five candidate library domains; I named:

  1. `lean-stat` (this repo) — statistics
  2. `lean-tab` (or similar) — relational/tabular operations
  3. `lean-graph` — graph algorithms
  4. `lean-bytes` — binary parsing and analysis
  5. `lean-text` — text/document analysis (markdown-cm is a member)

The user then asked specifically about images for an artist's
workflow — we agreed it fits the same pattern but is 6+ months out.

The decision: **`lean-stat` is the canonical name** (kebab-case
package, `LeanStat` Lean namespace). It lives as a sibling repo of
l3m and lean-manifests, NOT as a sub-package inside l3m. Reasons:

  - Discoverability: a Lean stats library should be findable by
    "Lean statistics" search, not buried in an agent project.
  - Versioning independence.
  - Clean trust-surface separation: lean-stat's manifest is about
    mathematical correctness; l3m's is about safety. Mixing them
    makes both noisier.
  - Future contributions: someone wanting to add chi-square forks
    `lean-stat`, not l3m.

## What's here vs what's next

### Here (initial extraction):

  - All 11 source files copied from l3m, namespaces renamed
    `L3m.{Stats,Plot,Report}` → `LeanStat.{Descriptive,Regression,
    Tests,Plot.*,Report.*}`.
  - Lakefile, lean-toolchain, .gitignore.
  - Path-dep on `../lean-manifests`.
  - Headline `Manifest.lean` with 5 placeholder claims.
  - 4 per-axis manifest files (Descriptive, Regression, Plot, Report)
    with placeholder claims documenting WHAT each function promises
    in human terms.
  - CLAIMS.md dashboard.
  - README.md with usage example and roadmap.

### Next (real work):

  1. **Build it.** Run `~/.elan/bin/lake build` and fix any build
     issues from the namespace rename. May need import-path tweaks.

  2. **Replace placeholder `UnprovenConjecture` claims** with real
     propositions. Most are tractable:
       - `mean #[] = 0` — `by decide` or `by native_decide`
       - `mean #[x] = x` — `by decide`
       - `(summary xs).n = xs.size` — direct from definition
       - Quantile bounds at 0 and 1
       - Linear regression returns `none` on degenerate inputs

  3. **Add `registerTestResults`-decorated claims** for empirical
     properties:
       - Correlation in [-1, 1] on a corpus of 1000 random inputs
       - OLS residuals are orthogonal to design matrix
       - SVG output passes a basic well-formedness check on 100 plots

  4. **Wire as l3m tools** (in l3m's repo, not here). Each top-level
     function becomes a tool with capability requirements:
       - `mean`, `variance`, etc. need `FsCap` (to read the input data)
       - `histogram` needs `FsCap` to read input + `FsCap` to write
         the SVG output (or returns the SVG string, leaving IO to caller)
       - `renderReport` similarly returns a string

  5. **Audit for IO leaks.** The library should have NO IO
     anywhere. Add a `Scripts/audit-grep.sh`-style check that
     greps for `IO.FS.*`, `IO.Process.*`, `IO.getEnv` and reports
     any references. Initial state should be empty.

## What's specifically NOT in scope here

  - File ingestion (CSV reading): l3m's job.
  - Output to disk: l3m's job.
  - Network calls: l3m's job.
  - Capability tokens: not relevant; this is a pure library.

The library takes `Array Float` and structured records; returns
`Float`, `Option <record>`, `String` (for SVG/HTML). Period.

## Connection to the broader merge

The merge memo in `~/l3m.kiro.codeFirst/.workspace/code_first/
merge-plan-review.md` had a pushback: **don't half-merge
Plot/Stats/Report into l3m's tree as `packages/l3m-extras/`**.
Instead, extract or delete.

This file IS that extraction. The next merge step is:

  - In l3m: delete `L3m/Plot/`, `L3m/Stats/`, `L3m/Report/`
    directories (the source files now live here).
  - In l3m's lakefile (when we want to wrap as tools, NOT
    necessarily during the initial merge): add
    `require «lean-stat» from "../lean-stat"`.

## Naming decision rationale

User's words on naming: "what is the standard name for it in the
Lean world?" Looking at neighbors:

  - `lean-manifests` (kebab, "lean-" prefix)
  - `dean_lean` (snake, "dean_lean" — older style)
  - `mathlib4` (no prefix; well-known library)
  - `aesop`, `batteries` (no prefix; tools/utility libraries)
  - `lean-toml`, `lean-json` (kebab + "lean-" prefix; format-specific
    libraries)

The "lean-X" pattern is most natural for utility/format libraries
that are clearly Lean-targeted but not core. `lean-stat` fits this
shape and matches the `lean-manifests` neighbor.

Lean module name: `LeanStat` (PascalCase). Sub-namespaces flat:
`LeanStat.Descriptive`, `LeanStat.Regression`, `LeanStat.Plot.Svg`,
etc. (Mirrors how `Mathlib` does it for sub-areas.)

## Dependencies

Path-dep on `../lean-manifests` (provides `dean_lean` / `DeanLean`).

When integrated with l3m, l3m will path-dep on `../lean-stat`.

## Future companion libraries (per the user's plan)

  - `lean-tab` (tabular operations) — coming soon, before the merge
    is done or shortly after
  - `lean-text` (text analysis) — markdown-cm is one member
  - `lean-graph`, `lean-bytes` — later
  - `lean-image` — 6+ months out

Each would follow the same pattern: pure functions, manifest
discipline, sibling repo of l3m, l3m path-deps it as needed.

## Open question for whoever picks this up next

When wiring as l3m tools: **does each function become its own
tool, or do we batch them under a few "categories" of tools?**

Option A: 13+ separate tools (`stat_mean`, `stat_variance`,
`stat_regression`, `plot_scatter`, etc.). Easy LLM dispatch but
lots of tool boilerplate.

Option B: 3 broad tools (`stat_summarize`, `stat_compare`,
`plot_render`) that dispatch internally based on a string param.
Less boilerplate, harder for LLM to know what's available.

Option C: 1 tool (`stat_run`) that takes a small DSL ("mean of x",
"linear regression of y on x", etc.). Most flexible, requires
the most work to implement.

I'd lean toward Option A for the first pass (each function is a
named tool, the LLM can see them all in the registry) and migrate
toward B or C if the boilerplate becomes painful. But this is a
decision for when integration starts.
