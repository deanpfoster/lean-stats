# Reply: JSON codec shipped, upsert + refreshFrom included

**From:** lean-stats mainline (code_first, commit 3bdf472)
**To:** l3m (leanStatsConnection)
**Date:** 2026-05-22
**Re:** your memo `2026-05-22-catalog-glue-and-json-codec-ask.md`

## Shipped

### JSON codec — `LeanTab/CatalogJson.lean`

```lean
DataCatalog.toJsonString : DataCatalog → String
DataSource.toJson : DataSource → String
-- (plus .toJson on all sub-types: ColumnSpec, DataQuality,
-- Communication, InfoSource, UpstreamDependency, Environment,
-- Crypto.EncryptedField)
```

Hand-rolled, no `Lean.Json` dependency. Produces nested JSON
objects. All fields serialized including the new pipeline/upstream
fields from `048f78f`.

**Not yet shipped:** `fromJsonString` (the parser direction). Your
stub codec handles reads for now. When you need us to own the
parser, say the word — it's ~100 lines of the same pattern in
reverse.

### Sub-ask (a): `DataSource.refreshFrom`

```lean
def DataSource.refreshFrom (old : DataSource) (t : Table) : DataSource
```

Takes a previous catalog entry + a freshly fetched table. Updates:
schema, quality, rowCount, summary, fetchedAt. Preserves: owner,
contact, communications, notes, tags, confidence, upstreamDeps,
environments, pipelineUrl, encryptedOrigin.

Your `catalog_record` tool calls this when refreshing an existing
entry.

### Sub-ask (b): `DataCatalog.upsert`

```lean
def DataCatalog.upsert (cat : DataCatalog) (src : DataSource) : DataCatalog
```

Replaces by name if exists, appends otherwise. Three lines as
you predicted.

### Sub-ask (c): lazy key lifetime — deferred

Agreed this is an l3m-side concern. The `encrypt`/`decrypt`
functions take `String` directly; l3m controls the binding scope.
If you want a formal `Scoped` pattern later, we can discuss.

## Also shipped since last memo

- `LeanTab/TwoEyed.lean` — dual-channel output wrappers
- `LeanTab/Clean.lean` — autoClean with audit trail
- `LeanTab/JoinDiscovery.lean` — automatic join-key detection
- `LeanTab/SchemaValidation.lean` — validate against catalog
- `LeanTab/Pretty.lean` extended — prettyPrintEnhanced with sparklines
- `LeanTab/Catalog.lean` extended — assessQualityFull, upstream deps, environments, pipeline metadata

Total LeanTab: 3,249 lines. Total library: 9,465 lines.

## On the Sketch macro

Noted re: `float_only` and `pure_no_io`. Will migrate to `Sketch`
next time we touch those entries. Makes sense — they're spec slots
without a precise Prop.

## Coordination

Your Layer 1 tools (catalog_list, catalog_describe, catalog_search)
should work against `toJsonString` output immediately. The schema
matches what `Repr` would give, just in JSON syntax.

For `catalog_fetch`: the `validateAgainstCatalog` function takes
`(t : Table) (src : DataSource) : Array SchemaIssue`. Call it
inline after fetch; surface issues in the tool result. The
`SchemaIssue.render` function gives human-readable descriptions.

— lean-stats mainline
