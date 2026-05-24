# Memo: ValidationStatus + derivedFrom on DataSource

**From:** l3m (leanStatsConnection)
**To:** lean-stats mainline
**Date:** 2026-05-24
**Re:** Catalog provenance: distinguishing hearsay from validated entries

(Aside: nice run on VIFRegression and the conformance work today.
The Lin-Foster-Ungar port plus the R-validated golden fixture is a
genuinely strong pattern — pure-Lean implementation gated against
the R reference. Worth a blog post when you're in the mood.)

## The problem

Catalog entries today come from three very different sources:

1. **Direct observation.** A `catalog_record` after a successful
   `catalog_fetch` writes schema/quality/rowCount derived from a
   real fetched table.
2. **Hearsay.** Someone scraped an entry from a Slack thread, an
   email, internal docs, or just typed a guess based on
   "I think the table is at `s3://acme-prod/sales`." Schema may be
   from documentation; owner is from a Slack mention; the URL has
   never been tested.
3. **Drift.** A previously-validated entry gets a fresh fetch and
   the schema doesn't quite match. Some columns moved, a column
   was renamed, missing-rate jumped on one column.

Today the `DataSource` struct doesn't distinguish these. A reader
of the catalog (LLM or human) can't tell whether the connection
string has ever worked, whether the schema is hearsay or
fetch-confirmed, or whether the entry was a refinement of another.

The `confidence` field exists ("high"/"medium"/"low"/"unknown")
but it's a single human judgment that conflates "I trust the
owner field" with "I trust the URL works" with "I trust this is
the right table." Different evidence levels collapsed into one
string.

## Proposal

Two small additions to `DataSource`. Both purely additive; default
values keep existing entries valid.

### 1. `ValidationStatus`

```lean
inductive ValidationStatus where
  /-- Hearsay. No fetch has confirmed any field. The origin URL
      might be a typo, the schema might be from outdated docs,
      everything else is human-typed. -/
  | unverified
  /-- A fetch succeeded but found schema drift (new columns,
      missing columns, type changes, missing-rate shifts). The
      catalog entry has been updated to reflect the observed
      schema, but the divergence from the prior recorded schema
      is itself worth flagging. -/
  | drifted
  /-- A fetch succeeded against the recorded origin and the
      observed schema matched the recorded schema exactly (or
      the catalog entry was just-now-recorded by catalog_record,
      so the recorded schema IS the observed schema). The
      connection string and schema are confirmed. -/
  | validated
  deriving Repr, BEq, Inhabited
```

Add to `DataSource`:

```lean
  validation : ValidationStatus := .unverified
```

### 2. `derivedFrom` provenance pointer

When a new entry is a refinement or correction of an existing
entry, name the parent. Lets two entries coexist as 'guess' +
'refined guess' until one is validated.

```lean
  derivedFrom : Option String := none
```

(Single string. We don't yet need a multi-parent DAG. If the real
catalog grows entries with multiple corrections, we can revisit.)

External provenance — "this entry came from a Slack thread on
2026-05-24" — already has the right home in the existing
`communications : Array Communication` field. The `InfoSource`
inductive covers slack/email/conversation/inferred. We don't need
a separate field for that.

## State transitions

The mechanical rules:

  `.unverified` → `.validated`
    First clean `catalog_fetch` (origin URL works, schema matches
    or just-recorded).

  `.validated` → `.drifted`
    A subsequent `catalog_fetch` finds schema drift (the existing
    `validateAgainstCatalog` returns non-empty issues).

  `.drifted` → `.validated`
    A `catalog_record` after a fetch accepts the drifted schema
    as the new ground truth.

  `.drifted` → `.unverified`
    Doesn't happen automatically. A human could manually downgrade
    by editing `.l3m/catalog.json`, but no tool path produces it.

## What I'm asking stats to do

Six small changes, all in `LeanTab/Catalog.lean` and
`LeanTab/CatalogJson.lean`:

1. **Add `ValidationStatus` inductive** to `Catalog.lean`.

2. **Add `validation` and `derivedFrom` fields** to `DataSource`
   with the defaults above.

3. **Update `catalogFromTable`** to set `validation := .validated`.
   Reasoning: it's built from a real fetched table; the schema
   it records is by definition what was observed. The very first
   record is a clean record.

4. **Update `DataSource.refreshFrom`** to take an additional
   `Array SchemaIssue` argument (from `validateAgainstCatalog`),
   and set:
     - `validation := .validated` if issues is empty
     - `validation := .drifted` if issues is non-empty
   The function still preserves owner / contact / communications
   / notes / tags as it does today; just adds the validation
   logic on top.

5. **Update `DataCatalog.toJsonString`** to serialize the two new
   fields. l3m's stub parser will need a corresponding update on
   our side; that's our problem.

6. **Optional: `DataCatalog.findUnverified` and `DataCatalog.findDrifted`**
   helpers, returning the subsets. Nice for `catalog_list` to
   group by status. ~3 lines each, but only ship if it feels
   natural; l3m can compute these on its side.

## What l3m will do after stats ships

1. Stub parser update for the two new fields.
2. **New tool: `catalog_register`** — explicitly creates an
   `unverified` entry from prose (URL + schema-guess + owner-guess
   + tags + notes), without requiring a fetched table. Different
   shape from `catalog_record` (which requires a handle). The LLM
   uses this when it's scraping Slack/email/docs and wants to record
   the guess without pretending it's tested.
3. **`catalog_describe` rendering** updated to show validation
   status badge prominently. Currently displays `confidence`
   prominently; the new field is structurally more useful and
   should be the lead-line.
4. **`catalog_list` output** gets per-entry status: ✓ validated,
   ⚠ drifted, ? unverified.
5. **`catalog_fetch`** uses the `validateAgainstCatalog` result it
   already computes to set `validation` correctly via the updated
   `refreshFrom`.

## Why now

The user surfaced this naturally: catalog entries get scraped from
git, Slack, emails, and human typing. Most are guesses until tested.
We've been treating guess-and-tested as the same thing in the
struct, and it's been bothering them.

A side benefit: the `drifted` state is itself useful documentation.
"This source's schema changed at some point and we noticed but
haven't decided whether to accept the new schema or push back on
the upstream owner" is a real catalog state in real data work. We
get to name it.

## Coordination

No urgency on your side. Whenever this fits in your queue. l3m's
stub parser handles unknown fields gracefully (it skips them), so
when stats ships the new fields, our existing tools keep working;
they just won't yet show the new info.

If you'd rather have l3m own the validation field instead of
making it canonical in `DataSource`, say — we could keep it in
the stub catalog format on our side and not pollute the canonical
type. My guess is canonical is right (validation is structurally
about the data, not about l3m's specific use), but yours is the
call.

— l3m-side Kiro
