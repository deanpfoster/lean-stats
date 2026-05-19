# Bivariate Moment Ladder — summarizing scatter plots for LLMs

## The idea

Every scatter plot of (X, Y) with n points can be summarized by its
**cross-moments** E(X^a Y^b) for a+b ≤ 4. These 15 quantities tell
you everything a linear-algebra-based summary can say about the joint
distribution. Most of the time, most of them are boring (consistent
with bivariate normal). We only report the ones that are **surprising**.

## The ladder (a+b = 0 to 4)

| Order | Moment | Name | What it tells you |
|-------|--------|------|-------------------|
| 0 | 1 | n | Sample size |
| 1 | E(X) | mean_x | Location of X |
| 1 | E(Y) | mean_y | Location of Y |
| 2 | E(X²) → SD(X) | sd_x | Spread of X |
| 2 | E(Y²) → SD(Y) | sd_y | Spread of Y |
| 2 | E(XY) → r | correlation | Linear association |
| 3 | E(X³) → skew_x | skew_x | Asymmetry of X |
| 3 | E(X²Y) | curvature | Nonlinearity: residuals curve |
| 3 | E(XY²) | heteroscedasticity | Fan shape: spread changes with X |
| 3 | E(Y³) → skew_y | skew_y | Asymmetry of Y |
| 4 | E(X⁴) → kurt_x | kurtosis_x | Heavy tails in X |
| 4 | E(X³Y) | nonlinearity | Cubic departure from line |
| 4 | E(X²Y²) | white_se | Robust SE correction term |
| 4 | E(XY³) | visual_slope | Apparent slope in bounding box |
| 4 | E(Y⁴) → kurt_y | kurtosis_y | Heavy tails in Y |

## Standardized form

All moments are computed on **standardized** data:
  x_i* = (x_i - mean_x) / sd_x
  y_i* = (y_i - mean_y) / sd_y

So the order-2 moments are always (1, 1, r) by construction.
The interesting ones are order 3 and 4, which are 0 for bivariate normal.

## When to report

Under bivariate normality, each standardized moment has a known
sampling distribution. We report a moment only when it's
**statistically distinguishable from the normal reference value**.

Reference values (bivariate normal):
- skew_x, skew_y: 0 (SE ≈ √(6/n))
- curvature: 0 (SE ≈ √(1/n) roughly)
- heteroscedasticity: 0 (SE ≈ √(1/n))
- kurtosis_x, kurtosis_y: 3 (excess = 0, SE ≈ √(24/n))
- nonlinearity: 0
- white_se: 1 + 2r² (for bivariate normal)
- visual_slope: 3r (for bivariate normal)

Rule: report if |observed - reference| > 2 × SE.

## Significant figures (Foster & Stine)

Don't report mean_x = 72144.23847. Report mean_x = 72000.
The number of significant figures is determined by the SE:
  sig_figs(mean_x) = digits where SE < 0.5 × last digit

For n = 100, sd_x = 30000:
  SE(mean_x) = 30000/√100 = 3000
  → report mean_x to nearest 1000: "72,000"

Same principle for all moments:
  SE(r) ≈ 1/√n → for n=100, report r to 1 decimal: "r = 0.87"
  SE(skew) ≈ √(6/n) → for n=100, SE ≈ 0.24 → report to 1 decimal

## Examples

### Example 1: Perfect linear (y = 2x + noise)
n=100, x ~ N(5, 2), y = 2x + N(0, 1)

Summary (what the LLM sees):
```
n: 100
x: 5.0 ± 2.0, y: 11 ± 4.1
r: 0.97
```
(Nothing else reported — all higher moments consistent with normal.)

### Example 2: Curved (y = x²)
n=200, x ~ N(0, 1), y = x² + N(0, 0.5)

Summary:
```
n: 200
x: 0.0 ± 1.0, y: 1.0 ± 1.5
r: 0.0
curvature: 1.4 (strong — residuals from linear fit are U-shaped)
kurtosis_y: 6.2 (excess = 3.2 — heavy right tail in Y)
```

### Example 3: Heteroscedastic (fan shape)
n=150, x ~ U(0, 10), y = x + N(0, x)

Summary:
```
n: 150
x: 5.0 ± 2.9, y: 5.0 ± 3.8
r: 0.76
heteroscedasticity: 0.8 (spread of Y increases with X)
skew_y: 0.6 (mild right skew from the fan)
```

### Example 4: Outlier-contaminated
n=50, x ~ N(0, 1), y = x + N(0, 0.3), plus 2 outliers at (5, -3)

Summary:
```
n: 50
x: 0.2 ± 1.1, y: 0.1 ± 0.8
r: 0.82
kurtosis_x: 5.1 (excess = 2.1 — heavy tails, likely outliers)
kurtosis_y: 4.8 (excess = 1.8)
nonlinearity: -0.4 (outliers pull the cubic term)
```

### Example 5: Visual slope illusion
n=100, x ~ N(0, 1), y ~ N(0, 5), r = 0.5

Summary:
```
n: 100
x: 0.0 ± 1.0, y: 0.0 ± 5.0
r: 0.50
visual_slope: 2.1 (expected 1.5 for normal; line looks steeper than r suggests
  because Y's scale is 5× wider than X's in the bounding box)
```

The visual_slope moment captures the "the graph LOOKS like a strong
relationship but r is only 0.5" phenomenon. It's E(XY³)/E(Y⁴) in
standardized form, which for normal is 3r but can differ when the
marginals are non-normal or the aspect ratio is extreme.

## Implementation plan

1. Compute all 15 standardized moments from (xs, ys)
2. Compute SE for each under normality assumption
3. Flag those where |observed - reference| > 2 × SE
4. Report only the flagged ones, with significant figures
5. Always report: n, means (with sig figs), SDs, r
6. Conditionally report: skew, curvature, hetero, kurtosis, etc.

The output is the "text view" of a scatter plot — what the LLM reads
instead of pixels. Budget-aware: at minimum just n + r, at maximum
the full moment ladder with interpretations.

## Connection to diagnostics

These moments map directly to regression diagnostics:
- curvature → "try a transformation" (Stine & Foster Ch. 19)
- heteroscedasticity → "use robust SEs" or "transform Y"
- kurtosis → "check for outliers"
- nonlinearity → "the relationship isn't polynomial-2 either"
- visual_slope → "be careful interpreting the graph's appearance"

The LLM can use these to decide next steps without human prompting.
