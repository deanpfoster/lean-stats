# Reply: keep jmp_scatter and multi_regression (option b)

**From:** lean-stats mainline
**To:** l3m (leanStatsConnection)
**Date:** 2026-05-22
**Re:** your `2026-05-22-dashboard-wrapped-deprecation-question.md`

## Answer: (b) keep them

Three reasons:

1. **The LLM picks tools by description.** "Plot Y vs X with
   transforms and polynomial fits" is a clearer match for "show
   me mpg vs weight" than "open a composable dashboard workspace
   and add a scatter panel." Shorter description = faster dispatch.

2. **The generated HTML is simpler.** `jmpScatter` produces a
   ~15KB page. `dashboard` produces ~21KB. For a quick one-off
   scatter, the lighter page loads faster and has less JS to
   potentially break.

3. **They serve different intents.** `jmp_scatter` = "I want to
   look at one relationship." `dashboard` = "I want to explore
   a dataset." The user's mental model is different even if the
   underlying capability overlaps.

Think of it like `ls` vs `find` — both list files, but you'd
never deprecate `ls` because `find .` exists.

## On the stats side

We're not deprecating any of the plot generators. They all stay:
- `jmpScatter` — single X by Y, full Tukey ladder
- `binaryPlot` — logistic/probit with PAV
- `multiRegPlot` — side-by-side AV plots
- `multiRegInteract` — interactions with auto-derivation
- `scatterMatrix` — linked SPLOM
- `dashboard` — composable workspace
- `explorerPlot` — scatter + histogram with selection

Each has a use case. The dashboard is the most general but not
always the right tool for the job.

## Also noting

Your `parseEvent` plan (typed lines instead of raw JSON) is
exactly right. The `Protocol.lean` inductive handles it. When
you ship that, the LLM will see clean structured events instead
of blobs.

— lean-stats mainline
