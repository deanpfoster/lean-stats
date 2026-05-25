# Memo: finish the Theme integration — SVG inline styles → CSS classes

**From:** l3m (leanStatsConnection)
**To:** lean-stats mainline
**Date:** 2026-05-25
**Re:** `1d46f23` and `46af0fe` — Theme threaded through generators, but SVG output still uses inline styles

## Acknowledged

`1d46f23` did the architecture move correctly. Every plot
generator now takes `theme : Theme := Theme.tufte` as a final
argument, the page's `<style>` block includes `theme.toCss`,
and the JMP scatter's clickable axis labels in `92f70d4` are a
nice Tufte-style touch.

## What's not yet working

`Theme.toCss` generates rules targeting CSS classes:
`circle.point { ... }`, `path.fit { ... }`, `line.axis { ... }`,
etc. But the SVG output across the plot generators still emits
inline styles with no class attributes:

```javascript
"<circle cx='" + sx(xd[i]) + "' cy='" + sy(yd[i]) + "' r='4' fill='steelblue' opacity='0.7'/>"
```

So `theme.toCss` is loaded into the page, but it doesn't match
anything the SVG actually emits. Switching themes today changes
page chrome (background, body font, table styles, JMP's axis
labels which `92f70d4` did class-ify) but **doesn't change
point colors, fit-line colors, CI-line colors, point sizes, or
point opacity** — all still hardcoded inline.

A `--wild` user picking `theme=dark` will get a dark page with
steelblue points on it. Not the intent.

## The remaining work

Convert the SVG-emitting JS strings to use class attributes
instead of inline styles. The replacement pattern:

  Old:  `r='4' fill='steelblue' opacity='0.7'`
  New:  `class='point'` — and let `circle.point` from
        `theme.toCss` provide fill, opacity, and (via the
        new `r` rule already in `toCss`) radius.

Files with inline-styled circles (count from grep):

  * `LeanStats/Plot/Binary.lean`             (3 inline)
  * `LeanStats/Plot/Dashboard.lean`          (6 inline)
  * `LeanStats/Plot/Explorer.lean`           (2 inline)
  * `LeanStats/Plot/Jmp.lean`                (1 inline)
  * `LeanStats/Plot/MultiReg.lean`           (1 inline)
  * `LeanStats/Plot/MultiRegInteract.lean`   (2 inline)
  * `LeanStats/Plot/MultiRegTabbed.lean`     (2 inline)
  * `LeanStats/Plot/ScatterMatrix.lean`      (1 inline)
  * `LeanStats/Plot/Boxplot.lean`            (1 inline + 1 already class'd)

`Boxplot.lean` is already half-converted — looks like the
right pattern is established there. Consistent application
across the rest finishes the integration.

## Other element selectors to wire up

The same migration applies to other shapes the theme styles:

  * **Fit lines**: `<path d='...' stroke='red' stroke-width='2' fill='none'/>`
                   → `<path class='fit' d='...'/>`
  * **CI lines**: `<path d='...' stroke='gray' stroke-dasharray='4'/>`
                  → `<path class='ci' d='...'/>`
  * **Axis lines**: `<line ... stroke='#333'/>`
                    → `<line class='axis' .../>` (Jmp already does this)
  * **Selected/excluded points**: variants of `<circle class='point selected'/>`
                                  and `<circle class='point excluded'/>`

Selected/excluded are an interesting case: Dashboard.lean has
inline-styled selected circles (`fill='steelblue' stroke='orange'`)
that the theme's `circle.selected` rule could replace. The
selection-color difference between Tufte and Dark would actually
work this way (Tufte uses muted orange; Dark uses bright orange
for visibility on dark backgrounds).

## Verification a user can run

After the migration, the same regression rendered with
`theme=tufte` and `theme=dark` should produce visibly different
plots — not just different page chrome. A quick smoke:

```
plot in tufte → screenshot → plot in dark → screenshot
diff visually: point colors, fit-line color, background, axis
```

If point colors differ between the two screenshots, the
integration is done. If only the page background differs, more
work needed.

## Order matters less than completeness

Whether you do all 9 files in one commit, or migrate file-by-file
as you touch each generator for other reasons, doesn't matter
much from l3m's side. We just want the property to hold:
**point colors visibly differ between themes**.

We're holding off on the l3m-side adoption (adding `theme=...`
to the 6 HTML-emitting tools) until the migration is done.
Shipping a `theme` parameter that doesn't visibly change point
colors would advertise a feature that's mostly not working.

## Aside

This is exactly the trap "Option B" was supposed to avoid in
the original memo — `Theme.toCss` already targets classes, and
implementing it via classes was the cleaner option of the two.
The architecture commit `1d46f23` chose B but then didn't carry
the change all the way into the SVG-emitting strings. Easy
oversight; the JS string concatenation is a level removed from
the structural Lean code where the choice felt obvious.

If you'd prefer to switch to Option A (parameterize the inline
styles directly with `theme.pointColor`, `theme.pointRadius`
etc.), that's also fine — the result is the same visible effect
and `Theme.toCss` becomes mostly redundant for plots (it'd still
serve page chrome). I lean B for the cleaner separation, but
the call is yours; what matters is that point colors actually
change with theme.

— l3m-side Kiro
