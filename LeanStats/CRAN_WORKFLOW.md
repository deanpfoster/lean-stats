# CRAN Import Workflow — on-demand R function porting

## The problem

R has 20,000+ packages. We don't want all of them. We want to
pull specific functions when needed, with correctness guarantees.

## The workflow

When a user (or LLM) says "I need lasso regression" or "port
glmnet::cv.glmnet":

### Step 1: Read the R source

The LLM reads the R function's source code from CRAN/GitHub.
It understands:
- Input types (what R calls: numeric vector, data.frame, formula)
- Output types (what R returns: list with named elements)
- Algorithm (what it actually computes)
- Edge cases (what happens with NA, empty input, etc.)

### Step 2: Translate to Lean

The LLM writes a pure Lean implementation:
- Map R types → Lean types (numeric vector → Array Float, etc.)
- Implement the algorithm
- Handle edge cases (return Option or safe defaults)
- Place in appropriate module (LeanStats/ or LeanTab/)

### Step 3: Validate against R

Using our Conformance framework (DeanLean.Conformance.R):

```lean
-- Golden fixture (checked in, always compiles):
private def xs := #[1.0, 2.0, 3.0, 4.0, 5.0]
private def ys := #[2.1, 4.0, 5.9, 8.1, 10.0]
-- R says: glmnet(xs, ys, lambda=0.1)$beta = 1.97
private def expected := 1.97

theorem conforms_r_glmnet_proof :
  approxEq (ourGlmnet xs ys 0.1).beta expected 0.01 = true := by native_decide
```

For bulk validation (not checked in):
```lean
-- Spec (checked in): how to generate test cases
def glmnet_spec : RSpec :=
  { name := "glmnet_lasso"
    rCodeTemplate := "library(glmnet); fit <- glmnet(matrix(c({xs}),ncol=1), c({ys}), lambda={lambda}); cat(coef(fit)[2])"
    count := 50
    tolerance := 0.01 }
```

### Step 4: Register

- Add to the appropriate `.lean` file
- Add a ProvenTheorem on the golden fixture
- Add the function to `auditEntryPoint` (purity check)
- Add to `Interface.lean` (Signature for l3m)
- Update `Eval.lean` dispatch table (if it should be callable by string)

## Type mapping (R → Lean)

| R type | Lean type |
|--------|-----------|
| `numeric` (vector) | `Array Float` |
| `integer` | `Array Nat` or `Array Int` |
| `character` | `Array String` |
| `logical` | `Array Bool` |
| `data.frame` | `LeanTab.Table` |
| `matrix` | `LeanStats.LinAlg.Matrix` |
| `list` (named) | Custom structure |
| `formula` (y ~ x1 + x2) | Implicit in function args |
| `NA` | `Option` or `Cell.na` |
| `factor` | `Array String` + `dummyCode` |
| `NULL` | `Option.none` |

## What's automatable vs manual

| Step | Automatable? | How |
|------|-------------|-----|
| Read R source | Yes | LLM reads from GitHub/CRAN |
| Understand algorithm | Yes | LLM parses R code |
| Write Lean implementation | Yes | LLM generates code |
| Generate golden fixture | Partially | LLM writes R script, human runs it |
| Prove fixture matches | Yes | native_decide |
| Bulk conformance | Yes | `lake run conformance:refresh` |

The LLM can do steps 1-3 autonomously. Step 4 (running R to get
expected values) needs IO — l3m runs the R script and captures output.

## Example: porting `cor.test`

Already done! Our `correlationTest` is a port of R's `cor.test`:
- Same algorithm (t-test on r, Fisher z-transform for CI)
- Same output shape (r, t-stat, df, CI)
- Validated on fixtures

## Example: what porting `lm` looked like

Our `linearRegression` + `regressionDiag` together cover R's `lm` + `summary.lm`:
- `linearRegression` = `lm(y ~ x)` (coefficients, R²)
- `regressionDiag` = `summary(lm(...))` (residuals, leverage, Cook's D, DW)
- `regressionConfInt` = `confint(lm(...))`
- `predictCI` / `predictPI` = `predict(lm(...), interval="confidence"/"prediction")`

## Priority queue for next ports

Based on Stine's courses + common data science needs:

1. **`step`** (stepwise via AIC) → we have `alphaInvesting` (better)
2. **`glm` (Poisson, negative binomial)** → extend our binary logistic
3. **`kmeans`** → clustering (new module)
4. **`prcomp` / `princomp`** → PCA (uses LinAlg.svd)
5. **`ts` / `arima`** → time series (new module)
6. **`survival::survfit`** → Kaplan-Meier (new module)
7. **`lme4::lmer`** → mixed effects (hard, future)

## The discipline

Every ported function gets:
1. A golden fixture (ProvenTheorem)
2. A conformance spec (for bulk validation)
3. An entry in auditEntryPoint (purity verified)
4. A Signature in Interface.lean (type contract with l3m)
5. A doc-comment saying "equivalent to R's `package::function`"
