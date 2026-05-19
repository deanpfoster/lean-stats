# LeanTab — parallel implementation plan

Each section below is an independent work unit. An agent picks one,
implements the functions, replaces the `UnprovenConjecture` placeholders
in the corresponding manifest with `ProvenTheorem`s (using `native_decide`
on concrete fixtures), and submits.

## Dependencies

All units depend on `LeanTab/Table.lean` (the core type) and
`LeanTab/Verbs.lean` (basic operations). No unit depends on another
unit — they can all proceed in parallel.

## Work units

### 1. Join (`LeanTab/Join.lean`)
**Manifest:** `LeanTab/Manifests/Join.lean`
**Implement:**
- `innerJoin (t1 t2 : Table) (key : String) : Table`
- `leftJoin (t1 t2 : Table) (key : String) : Table`
- `rightJoin (t1 t2 : Table) (key : String) : Table`
- `crossJoin (t1 t2 : Table) : Table`

**Key claims to prove:**
- Inner join row count ≤ product of inputs
- Left join preserves all left rows
- Column count = left + right - 1 (key merged)

---

### 2. Window functions (`LeanTab/Window.lean`)
**Manifest:** `LeanTab/Manifests/Window.lean`
**Implement:**
- `lag (xs : Array Cell) (n : Nat := 1) : Array Cell`
- `lead (xs : Array Cell) (n : Nat := 1) : Array Cell`
- `rowNumber (t : Table) : Array Nat`
- `cumSum (xs : Array Float) : Array Float`
- `runningMean (xs : Array Float) : Array Float`
- `rank (xs : Array Float) : Array Nat`

**Key claims to prove:**
- lag/lead preserve array length
- cumSum last element = total sum
- rowNumber produces 1..n

---

### 3. Missing data (`LeanTab/Missing.lean`)
**Manifest:** `LeanTab/Manifests/Missing.lean`
**Implement:**
- `dropNa (t : Table) (col : String) : Table`
- `fillForward (xs : Array Cell) : Array Cell`
- `fillBackward (xs : Array Cell) : Array Cell`
- `replaceNa (t : Table) (col : String) (val : Cell) : Table`
- `countNa (xs : Array Cell) : Nat`

**Key claims to prove:**
- dropNa reduces rows, preserves cols
- fillForward reduces NA count
- replaceNa eliminates all NAs in target column

---

### 4. String operations (`LeanTab/StringOps.lean`)
**Manifest:** `LeanTab/Manifests/StringOps.lean`
**Implement:**
- `strDetect (xs : Array Cell) (pat : String) : Array Bool`
- `strReplace (xs : Array Cell) (old new_ : String) : Array Cell`
- `strSplit (xs : Array Cell) (sep : String) : Array (Array String)`
- `strToUpper (xs : Array Cell) : Array Cell`
- `strToLower (xs : Array Cell) : Array Cell`
- `strTrim (xs : Array Cell) : Array Cell`
- `strLength (xs : Array Cell) : Array Cell`

**Key claims to prove:**
- All operations preserve array length
- strLength returns non-negative values

---

### 5. CSV and pretty-print (`LeanTab/Csv.lean`, `LeanTab/Pretty.lean`)
**Manifest:** `LeanTab/Manifests/IO.lean`
**Implement:**
- `renderCsv (t : Table) : String`
- `parseCsv (s : String) : Table`
- `prettyPrint (t : Table) (maxRows : Nat := 20) : String`

**Key claims to prove:**
- CSV round-trip preserves dimensions
- renderCsv line count = nRows + 1
- prettyPrint contains all column names

---

### 6. Sample and slice (`LeanTab/Sample.lean`)
**Manifest:** `LeanTab/Manifests/Sample.lean`
**Implement:**
- `slice (t : Table) (lo hi : Nat) : Table`
- `sampleN (t : Table) (n : Nat) (seed : Nat := 42) : Table`
- `sampleFrac (t : Table) (frac : Float) (seed : Nat := 42) : Table`

**Key claims to prove:**
- slice returns exactly hi - lo rows (clamped)
- sampleN returns exactly min(n, nRows) rows
- All preserve column count

---

### 7. Multi-column groupBy (`LeanTab/GroupBy.lean` — extend)
**Manifest:** `LeanTab/Manifests/MultiGroup.lean`
**Implement:**
- `groupByMany (t : Table) (cols : Array String) : Grouped`
  (extend existing `Grouped` type to support composite keys)

**Key claims to prove:**
- Group count ≤ nRows
- Single-column groupByMany = groupBy
- Group sizes sum to total rows

---

## How to implement

1. Read the manifest file for your unit
2. Implement the functions in the specified `.lean` file
3. Import your implementation in the manifest file
4. Replace each `UnprovenConjecture` with a `ProvenTheorem` using
   `native_decide` on a concrete fixture (3-5 rows is enough)
5. Run `lake build LeanTab` — must pass with no errors
6. Add your new file to `LeanTab.lean` imports

## Conventions

- `set_option autoImplicit false` in every file
- All functions in `namespace LeanTab`
- Edge cases return empty/identity (never panic)
- NAs propagate (NA in → NA out) unless the function's purpose is to handle NAs
- Use existing `Cell`, `Column`, `Table` types — don't invent new ones
