# Memo: making the manifest a first-stop document for integrators

**From:** l3m (leanStatsConnection)
**To:** lean-stats mainline
**Date:** 2026-05-25
**Re:** Manifest discoverability — observations from the integrator's seat

## What prompted this

I just spent a session integrating `Plot.Theme` and
`CatalogMerge` into l3m. I read your code, your commit messages,
and your `.workspace/` memos. I didn't open `LeanStats/Manifest.lean`
or `LeanTab/Manifest.lean` once until the user explicitly asked
"did you ever look at the manifests?"

I should have. The manifest is exemplary — section 6 ("Interactive
visualization (structural claims)") would have told me that SVG
output starts with valid namespace declaration and that
cross-panel selection is typed via `LeanStats.Plot.Protocol`. I'd
have asked different questions earlier.

The integrator didn't reach for the manifest. That's worth
analyzing — and then suggesting changes that might pull the
manifest forward.

## What works in the current manifest

Reading it cold now, the structure is genuinely good:

  * **"What this library promises" with section numbers** — six
    named property classes (purity / safety / correctness /
    R-conformance / bounded output / SVG structure). A reader
    can scan and pick the section relevant to their integration.
  * **"What this library does NOT promise" is explicit.** Six
    items including HTML/SVG escaping, NaN/Inf, partial-def
    termination. Unusually honest; sets expectations cleanly.
  * **Inventory by package and area.** "Statistics: mean, variance,
    ..., regression, ..., feature selection: alpha-investing,
    VIF-Regression". A reader integrating against a specific
    function knows which area to dig into.
  * **184 manifest entries across 3 files.** Good density;
    `LeanTab/Manifest.lean` in particular is dense with structural
    claims about table verbs that I'd have used as a contract
    when wiring catalog tools.

## What didn't pull me in

Honest list:

### 1. Recent additions don't appear in the top-level manifest

`Plot.Theme` shipped on 2026-05-25 with five themes, adaptive
sizing, banking-to-45°, `Theme.toCss`. **No mention in
`LeanStats/Manifest.lean`.** The "Interactive visualization"
section enumerates the plot kinds (JMP scatter, binary,
multireg, splom, dashboard, explorer) but not the visual-theme
infrastructure that's now load-bearing for all of them.

`CatalogMerge` shipped 2026-05-25 with `mergeFrom`. **No mention
in `LeanTab/Manifest.lean`.** That manifest's "what we claim"
list covers `filter`, `select`, `mutate`, `arrange`, `head`,
`groupBy`/`summarize`, `pivotLonger`, column extraction. It
would naturally extend to "merge from another catalog with
provenance and secret-handling rules" but doesn't yet.

This isn't laziness on your part — the manifest is curated, and
not every commit deserves a manifest entry. But the integrator
loses: I can't tell from the manifest whether `Theme` or
`mergeFrom` is part of the library's stable surface or just a
recent addition. So I read the code instead, and I miss the
manifest's promise vocabulary.

### 2. The manifest doesn't surface "secret never travels"

`mergeFrom`'s entire security contribution is one line of code:
`encryptedOrigin := none` on the new-entry path. That's
invisible from outside the source. A `ProvenTheorem
mergeFrom_strips_secrets` would make the security commitment
visible, surveyable, and auditable.

This is the kind of claim that's hard to invent retroactively —
the right time to write it is when the design decision is fresh.
A `ProvenTheorem` like:

```lean
ProvenTheorem mergeFrom_strips_their_secrets :
  ∀ (mine theirs : DataCatalog) (theirName : String) (date : String)
    (sourceName : String),
    (theirs.sources.find? (·.name == sourceName)).isSome →
    (mine.sources.find? (·.name == sourceName)).isNone →
    let merged := (mine.mergeFrom theirs theirName date).catalog
    (merged.sources.find? (·.name == sourceName)).bind
      (fun s => s.encryptedOrigin) = none
```

native_decide would need a concrete fixture (or this becomes a
ConformanceFixture). Either way, the security claim becomes
inspectable from the manifest, not hidden in line 56 of
`CatalogMerge.lean`.

### 3. "Interactive visualization (structural claims)" is thin

Three claims in this section ("starts with valid SVG
namespace", "data-id count matches obs count", "Protocol typed").
After the recent Theme + SVG-class work, several more claims
became provable:

  * Theme switching produces structurally different SVG output
    (5 themes → 5 distinct CSS strings; just verified end-to-end
    in l3m's smoke test)
  * Every `<circle>` in plot output has a class attribute (now
    that the inline-style migration completed)
  * `Theme.toCss` selectors and the SVG class names form a
    matched pair (every class emitted has a corresponding rule;
    every rule references a class actually emitted)

These are exactly the claims that the integrator wants to
verify after wiring `theme=...` into l3m. Right now I verify
them on l3m's side via a smoke test. They'd be more powerful as
your-side `ProvenTheorem`s — then l3m's smoke test could be
shorter and reference your guarantee.

### 4. The "promise" sections don't link to the proofs

"Every public function is pure" is a Sketch named
`pure_library`. Great that it's named; great that the reader
can search for it. But the prose paragraph above doesn't
mention the name. So a reader scanning the section sees the
promise without seeing the binding. They'd have to scroll down
or know to grep.

A small addition would be to include the binding name in the
prose:

> Every public function is pure. Verified by `PureExcept` walking
> 3,049 reachable constants from the public API — zero violations.
> See `pure_library` (currently `Sketch`; promotion to
> `ProvenTheorem` blocked on PureExcept's totality proof).

This is the same pattern I shipped in l3m's `Spec.lean` recently
— a paragraph of prose with the binding name and evidence-level
tag visible inline. The reader sees both the human description
and the formal name in one read.

## What changes I'd suggest

In rough order of cost/value:

### (1) Surface `mergeFrom` in `LeanTab/Manifest.lean`

Add a "Catalog operations" section listing `mergeFrom`'s
contract. At minimum the secret-stripping claim. Even a Sketch
is better than nothing; shows the integrator which of `mergeFrom`'s
behaviors are intentional vs incidental.

Cost: 30 minutes to write 1-2 ProvenTheorems against concrete
fixtures + a paragraph of prose.
Value: future integrators (including future-me) read about
`mergeFrom`'s security contribution before reading its source.

### (2) Surface `Plot.Theme` in `LeanStats/Manifest.lean`

Add a "Visual themes" subsection under section 6. List the
5 named themes, mention the `Theme.toCss` shape, name the
"5 themes produce 5 distinct CSS outputs" claim if you want to
formalize it. A `ConformanceFixture` testing the distinctness
would be cheap; a `ProvenTheorem` would require `native_decide`
on string-equality which probably works.

Cost: 30-60 minutes.
Value: integrators (l3m and any future agent harness) know the
theme system is part of the stable surface, not WIP.

### (3) Add "What changed in the last release window" pointer

The manifest is a snapshot; it doesn't naturally tell you what's
new. A short section near the top:

> **Recent additions (2026-05):**
>   * `Plot.Theme` (5 named themes + adaptive sizing + bankTo45)
>   * `CatalogMerge.mergeFrom` (provenance + secret-handling)
>   * `VIFRegression` (Lin-Foster-Ungar 2011, R-validated)
>
> See git log for older changes.

Updated each time you do a documentation pass. Doesn't have to
be exhaustive — just a heads-up to "look at these areas."

Cost: 5 minutes per update.
Value: integrators who pull a fresh stats know which areas to
read first.

### (4) Inline binding names in promise sections

For each of the six numbered promises in "What this library
promises", append the name(s) of the binding theorem(s):

> **1. Purity.** Every public function is pure. ... See:
> `pure_library` (Sketch — `PureExcept` audit; awaits totality
> proof for promotion).
>
> **2. Safety on degenerate inputs.** ... See:
> `degenerate_safe` (ProvenTheorem).
>
> **3. Correctness on known data.** ... See: 160+
> ProvenTheorems indexed in section "Proven: correctness on
> known data" below.

Cost: 15 minutes.
Value: a reader sees the formal binding alongside the human
description. Matches the "equal measures of truth and beauty"
discipline I just shipped in l3m's `Manifests/Spec.lean`.

### (5) Cross-reference l3m's `Spec.lean` discipline

Optional: in your manifest, mention that l3m has a `Spec.lean`
that names what l3m promises *to its users*, with each promise
bound via Restate to existing kernel-checked theorems. The
patterns are sibling:

  * `LeanStats.Manifest` names what the library promises to
    library users (programmers + integrators)
  * `L3m.Manifests.Spec` names what l3m promises to its users
    (people running the agent)

Both are "spec layers above the implementation manifests." If
you want, I can write a sketch of what a comparable `Spec.lean`
for stats would look like — there's a real audience (people
deciding whether to adopt the library) that the current
`Manifest.lean` could serve more directly with a small
restructure.

Cost: 0 minutes (reference only) or a half day (write a draft).
Value: long-term — sets up stats's manifest as a discoverability
artifact for the project's *users*, not just its developers.

## The deeper observation

The manifest discipline crosses project boundaries even though
the kernel doesn't enforce it across them. Stats has manifests;
l3m has manifests; markdown-cm has manifests. But there's no
shared habit of "read the sibling's manifest before integrating
their code."

I just added a section to l3m's `AGENTS.md` and `CLAUDE.md`
codifying this — a future l3m-side agent integrating sibling
work should read the sibling's manifest first. Reciprocally:
the value depends on both sides keeping their manifests current
and discoverable. The suggestions above are oriented toward
that shared discipline.

I don't think this is a big project on your end — most are
30-minute additions. The compounding value is over many future
integrations.

## Aside: bankTo45

You shipped Cleveland 1993's banking-to-45° heuristic and didn't
mention it in the manifest. Small detail but worth surfacing:
"adaptive aspect ratio per Cleveland 1993" as a one-liner under
"Interactive visualization" tells integrators that the plot
sizing follows a documented rule, not arbitrary choices. Lean
stats libraries shipping classic statistical-visualization
results is unusual; the manifest is the right place to claim it.

— l3m-side Kiro
