# VIF-Regression Conformance

## Reference

Package: `VIF` (CRAN)
Authors: Dongyu Lin, Dean P. Foster, Lyle H. Ungar
Paper: JASA Vol. 106, No. 493: 232-247 (2011)
R script: `Conformance/R/vif_regression.R`

## Status

| Fixture | R output | Lean proof | Status |
|---------|----------|-----------|--------|
| Test 1: signal+noise (n=5, p=3) | Pending R run | `vif_regression_selects_signal` | ⚠️ Proven on expected output, not yet validated against R |
| Test 2: Boston housing | Pending R run | Not yet | ❌ Needs R |
| Test 3: Synthetic (syn dataset) | Pending R run | Not yet | ❌ Needs R |

## To complete conformance

1. Install R + VIF package: `install.packages("VIF")`
2. Run: `Rscript Conformance/R/vif_regression.R`
3. Record output in `Conformance/R/vif_regression_expected.lean`
4. Add ProvenTheorems matching R's output

## What we've proven without R

Our implementation correctly:
- Selects the signal variable (index 0) on y=2x+noise
- Rejects noise (random) and constant predictors
- Uses alpha-investing wealth management (w0, dw)
- Supports dense/sparse modes

These are structural correctness claims. The conformance against
R's specific output on the Boston housing and synthetic datasets
requires running R.

## Notes on potential differences

Our implementation may differ from R's in:
- Subsample selection (we use first N, R may use random)
- Floating-point path (R uses LAPACK, we use our LinAlg.ols)
- Edge case handling (what happens when VIF is infinite)

The conformance test will reveal any such differences.
