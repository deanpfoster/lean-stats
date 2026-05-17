import LeanStat.Descriptive
import LeanStat.Regression
import LeanStat.Tests

import LeanStat.Plot.Svg
import LeanStat.Plot.Scale
import LeanStat.Plot.Axes
import LeanStat.Plot.Scatter
import LeanStat.Plot.Histogram

import LeanStat.Report.Tooltip
import LeanStat.Report.Html

import LeanStat.Manifest

/-! # LeanStat — pure-Lean statistics, plotting, and reporting

A pure Lean 4 library for statistical computation, plotting, and
HTML report generation. All functions are pure; no IO. Designed to
be wrapped by tools (e.g. l3m) that handle file ingestion and output
under a capability-token discipline.

For the headline claims: `LeanStat.Manifest`.
For per-axis claims: `LeanStat.Manifests.<topic>`.
For the source: `LeanStat.Descriptive`, `LeanStat.Regression`,
`LeanStat.Tests`, `LeanStat.Plot.*`, `LeanStat.Report.*`.

## What's here

  - **Descriptive**: mean, variance, stdDev, median, quantile, summary
  - **Regression**: Pearson correlation, linear regression
  - **Tests**: one-sample and two-sample (Welch) t-tests
  - **Plot**: SVG model + scale + axes + scatter + histogram
  - **Report**: HTML report generation with tooltips

## What's NOT here

  - File IO (CSV reading, etc.) — by design, this is a pure library
  - Sampling distributions / p-value tables — TODO
  - Bayesian / GLM / time-series — TODO
  - Color science, perceptual transforms — TODO
  - Anything requiring the network — by design

## Why pure

A pure library can be wrapped as a tool inside a capability-bounded
agent (e.g. l3m). The agent layer handles data ingestion, file
output, network. The library handles correctness. Each layer's
manifest is small and focused: the library promises mathematical
properties; the agent promises safety properties. The user gets
both.

## Status

Initial extraction from l3m's experimental Plot/Stats/Report
directories (2026-05-17). Manifest claims at this stage are mostly
`UnprovenConjecture` placeholders — the functions exist and are
exercised, but the formal claims about their structural and
mathematical properties haven't been written yet. That's the next
work.
-/
