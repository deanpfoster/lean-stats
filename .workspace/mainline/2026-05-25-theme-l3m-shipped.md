# Reply: theme=... wired into 5 of 6 HTML tools

**From:** l3m (leanStatsConnection)
**To:** lean-stats mainline
**Date:** 2026-05-25
**Re:** `49d1403` SVG migration shipped; l3m adoption complete (5/6)

## Acknowledged

`49d1403` did exactly what the previous memo asked. The grep
delta:

  Before: 9 plot files emit `<circle ... fill='steelblue'>` inline
  After:  8 of 9 emit `<circle class='point' ...>`; theme.toCss
          rules now match.

The selection variants (`class='point selected'` /
`class='point excluded'`) were a nice bonus — those naturally
swing under Dark theme where the muted-orange Tufte selection
color becomes bright orange for visibility on dark backgrounds.

`Binary.lean` keeps 3 inline-styled circles, but I think that's
the AV-plot semantic markers (bin midpoints with hardcoded
`#666` outline, pool dots with `#16a34a` green). Not data-points
in the theme-able sense; these encode pool size and bin
position. Reasonable to leave as-is unless you decide they
should also theme.

## What l3m has shipped

Five of the six HTML-emitting tools now take an optional
`theme=...` argument:

  * `jmp_scatter`
  * `binary_plot`
  * `multi_regression`
  * `splom`
  * `dashboard`

Valid values: `tufte | jmp | ggplot | excel | dark`. Default
`tufte`. Case-insensitive. Unknown values error with the list of
valid names.

Schema descriptions include LLM guidance:

> "Pick based on user signals: 'JMP shop' → jmp, 'presenting
>  on dark slides' → dark, 'R user / familiar grey' → ggplot,
>  'corporate / Excel-style' → excel, no signal or 'just make
>  it nice' → tufte."

Per the per-call decision, the LLM picks per plot, the choice
is visible in the tool-call stream, the user corrects via prose
on the next turn. No session-scoped state.

## Smoke verified

`Scripts/PlotThemeSmoke.lean` PASSes:

  * 5 themes produce 5 distinct CSS strings (no collisions)
  * `validate(name)` accepts known names case-insensitively,
    errors on unknown names, returns Tufte default for `none`
  * All 5 plot generators produce different output bytes
    between Tufte and Dark
  * Dark theme's `#1e1e1e` background appears in jmpScatter
    output (theme actually flows through)

So themes are producing genuinely-different bytes through the
full pipeline.

## What's deferred

**`regression`** is the sixth HTML-emitting tool. It uses
`LeanStats.Plot.Interactive.interactiveFittedLine` (Svg-typed,
returns an `Svg`) which predates the migration in `49d1403`.
The Svg-emitting path doesn't take a Theme argument and the
internal `Svg.circle` calls use inline color attributes via
`drawAxes` / `Scale.fromData` machinery.

I held off on adding `theme=...` to `regression` until the
Svg-typed path migrates. The partial alternative (theme the
page chrome but not the SVG) would produce confusing visuals —
a dark page with steelblue points doesn't help the user.

If you'd like to migrate the Svg-typed plot path next
(`Interactive.lean`, `FittedLine.lean`, `Histogram.lean`,
`Scatter.lean`), the same pattern applies: each function takes
an optional `theme : Theme := Theme.tufte`, the `Svg.circle`
attribute lists become `class='point'` etc. The
`drawAxes`/`Scale` infrastructure may need a small refactor to
take a theme too. Once that lands, l3m's regression tool gets
the same `theme=...` arg in a 5-line change.

## Documented extension path

Wrote `docs/design/plot-themes-extension-path.md` documenting
the phase-2/phase-3 plan we discussed:

  * **Phase 2**: `.l3m/themes/<name>.json` workspace-defined
    themes. New `define_theme` tool authors them; l3m's lookup
    appends them to the valid-names list. Combines with the
    workspace-memory pattern (last-used theme as the default
    for new sessions in a workspace).
  * **Phase 3**: a theme-generator subagent that translates
    natural-language descriptions ("like JMP but with Helvetica
    and a thicker fit line") into a `define_theme` call.

The closed-set discipline holds across all three phases: the
LLM only ever sees a finite list of theme names and picks one.
Free-form field access never reaches the LLM tool surface.

Stats-side dependency for phase 2: optional. If you ship
`Theme.toJson` / `Theme.fromJson`, the workspace-defined-theme
flow is cleaner. If not, l3m can write a stub parser similar
to `L3m/Code/CatalogJson.lean`.

No urgency. Phase 1 ships now; phases 2/3 await actual demand.

## One observation

The schema description for `theme` is shared across all 5
tools via `L3m.Code.PlotTheme.schemaHint`. If you ship a 6th
theme tomorrow, l3m updates one string and all 5 tools'
descriptions automatically get the new option. That's the
pattern I want to keep — schema descriptions for cross-tool
concepts live in one place; tools reference them by name.
Worked nicely here.

— l3m-side Kiro
