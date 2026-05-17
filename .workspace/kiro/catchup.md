# Catchup: starting fresh in lean-stats

*This file is for a kiro instance landing in `~/lean-stats.kiro/`
without the conversation history that produced it. Read this
before doing anything substantive.*

---

## Where you are

You're in `~/lean-stats.kiro/`, which is the `kiro` branch worktree
of a sibling-of-l3m repository called `lean-stats`. The repo
provides pure-Lean statistics, plotting, and HTML reporting,
intended to be wrapped by capability-bounded agents like l3m.

There are three worktrees of this repo:
- `~/lean-stats.kiro/` — your worktree (branch `kiro`)
- `~/lean-stats.code_first/` — code_first's worktree (branch `code_first`)
- `~/lean-stats.git/` — bare hub

Both branches forked from `mainline` at commit `289badc`. Build
clean.

## What exists today

Code_first did the initial extraction from l3m's experimental
`Plot/Stats/Report` directories. The repo has:

- 11 source files (Descriptive, Regression, Tests, Plot/*, Report/*)
- 5 manifest files (Manifest.lean + Manifests/{Descriptive, Regression, Plot, Report}.lean)
- ~440 LOC of Lean code
- Manifest skeleton in place; most claims are `UnprovenConjecture`
  placeholders that need real propositions written

This is a **young library**. The discipline is set up; the work is
filling in the claims and proving them.

## What `lean-stats` is for

Read `README.md` and `STATE.md` first. Short version: this is a
stats library that l3m (and any other Lean project) can depend on.
Pure functions all the way down (no IO except `Svg.render` which is
documented partial). Manifest-driven: every function eventually has
a manifest claim about what it promises.

## Why it matters (the big picture)

l3m's evolving mission (per `~/l3m.kiro/mission.md`) is to support
domain experts who don't read code but need evidence-backed
correctness. Pure-Lean libraries with rich manifest discipline are
**the substrate** for that. lean-stats is the canonical example:

- A statistician (R/Python user) wants to fit a regression
- They prompt l3m
- l3m calls `LeanStats.linearRegression` from this library
- The function has a manifest claim: `regression_least_squares`
  (OLS minimizes sum of squared residuals)
- l3m surfaces that to the user: "I used a function proven to
  minimize squared residuals on this data. Here's the result."
- The user gets evidence, not vibes

For this to work, lean-stats's manifest needs to **actually be
trustworthy**. That means: real propositions, real proofs, no
vacuous claims, no theater.

## What needs doing (in rough priority)

Do NOT just start coding. Read `STATE.md` and `CLAIMS.md` first.
Then in priority order:

1. **Replace placeholder claims with real propositions.** Currently
   most manifest entries are `UnprovenConjecture pure_no_io : True`
   and similar — vacuous, exactly what `MANIFEST_GUIDE.md` warns
   against. Use real types. The `MANIFEST_GUIDE.md` (in lean-manifests
   at `templates/MANIFEST_GUIDE.md`) is required reading for the
   patterns; §5a (vacuous totality) and §5b (trivially decidable)
   apply directly.

2. **Add `decide` / `native_decide` proofs where applicable.**
   `mean #[1.0, 2.0, 3.0] = 2.0` is decidable. Promote to
   `ProvenTheorem` if the proof goes through.

3. **Add `registerTestResults` decoration** for sample-based claims
   following markdown-cm's pattern. E.g., for `correlation`, run
   on a curated input set, register the test count, declare a
   `TestedConjecture`. See `MANIFEST_GUIDE.md` §3.

4. **HTML / SVG escaping.** Currently absent. Real safety property
   the library should guarantee. Worth writing as a typed claim
   (e.g., `no_script_in_output : ∀ d, scriptCount (renderHtml d) = 0`).

5. **Student's t CDF / p-value table.** Tests currently return
   t-statistic only. P-values would let users do real hypothesis
   testing.

DO NOT add features beyond the manifest discipline. The library is
small; the value is in making the existing functions trustworthy,
not in adding more functions yet.

## Lean gotchas (from l3m's catchup; carry over)

- Imports MUST come before `/-! -/` docstrings
- `String.containsSubstr` doesn't exist; use `(s.splitOn sub).length > 1`
- UTF-8 strings are byte-indexed; `s.get ⟨i⟩` breaks on multi-byte
  chars. Use `String.Pos` with `s.next`.
- `{ default with ... }` does NOT apply default field values. Use
  explicit constructor.
- Lean docstrings (`/-- ... -/`) before macros like `UnprovenConjecture`
  fail at parse time. Use `--` line comments.
- `set_option autoImplicit false` is project default. Explicit type
  parameters required everywhere.
- `IO.Process.spawn` with `stdin := .piped` deadlocks without
  `takeStdin` and draining stderr (we don't use this pattern in
  lean-stats currently; flagging in case)

## Build commands

```bash
source ~/.elan/env
cd ~/lean-stats.kiro
lake build           # full build
lake build LeanStats # the lib target
```

## Cross-branch coordination

Code_first is currently driving the master ↔ code_first merge of
l3m (NOT involved in lean-stats). Once that merge lands, we expect
both kiro and code_first attention will return to lean-stats.

For now: you're working alone in this repo. Communicate with
code_first via `.workspace/code_first/` if needed; check
`.workspace/kiro/` for memos to you.

## Workflow conventions

- COMMIT EACH PHASE. Don't let work pile up.
- `lake build` should be green before every commit.
- Add `registerTestResults` whenever you add a test-backed claim,
  so the build log shows progress.
- Strip workplan metadata (`@[depends_on]`, `@[estimated_minutes]`,
  `@[entry_point]`) when promoting an `UnprovenConjecture` to a
  proven status.
- Use `Restate` from lean-manifests to forward claims from the
  per-axis manifests up to `Manifest.lean` rather than duplicating.

## What l3m looks like now (relevant context)

l3m at `~/l3m.kiro/` has:
- 122 ProvenTheorems, 17 ManifestAxioms, 8 DerivedConjectures
- Capability layer (FsCap, ProcessCap, NetCap, EnvCap, ConsoleCap, WorktreeCap, TmuxCap)
- Reviewer cascade (PVD-inspired LLM oversight)
- Spawn architecture for parallel agents
- Audit-grep for source-structure invariants
- Tag `pre-merge-master-final` at commit `e9035d2`

These details matter only insofar as they explain what kind of
thing lean-stats is paired with: a kernel-verified agent that will
be the calling-side. Lean-stats provides correctness; l3m provides
safety. Don't confuse the responsibilities.

## Mission alignment

If you're going to optimize for ONE thing while working in
lean-stats: make every published function have an honest, falsifiable
manifest claim that the agent can summarize to a non-coder user.

The user will never read the proof. The agent will never read the
proof. But somewhere in the chain, the claim has to be real, or the
whole story falls apart. That's where lean-stats earns its rent.

— Kiro (master, writing for kiro instance starting in lean-stats)
2026-05-17
