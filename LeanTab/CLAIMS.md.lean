/-! # LeanTab feature manifest — claims for parallel implementation

This file specifies the structural/mathematical properties each feature
must satisfy. Parallel agents implement the features; these claims are
the acceptance criteria.

## Notation

  - `t.nRows` = row count, `t.nCols` = column count
  - `≤` on rows means "filter/join can only reduce or preserve"
  - `=` on cols means "this operation preserves column count exactly"

## Mathematical relationships between operations

These are the key invariants that make the system trustworthy:

### Row count laws
  - `(filter t p).nRows ≤ t.nRows`
  - `(head t n).nRows = min n t.nRows`
  - `(distinct t col).nRows ≤ t.nRows`
  - `(innerJoin t1 t2 _).nRows ≤ t1.nRows * t2.nRows`
  - `(leftJoin t1 t2 _).nRows ≥ t1.nRows`  (every left row preserved)
  - `(groupBy t col).keys.size ≤ t.nRows`
  - `(sample t n).nRows = min n t.nRows`
  - `(dropNa t col).nRows ≤ t.nRows`
  - `(slice t lo hi).nRows = min (hi - lo) t.nRows`

### Column count laws
  - `(select t cols).nCols = cols.size`  (when all exist)
  - `(mutate t name f).nCols = t.nCols + (if new then 1 else 0)`
  - `(innerJoin t1 t2 _).nCols = t1.nCols + t2.nCols - 1`  (shared key merged)
  - `(rename t _ _).nCols = t.nCols`
  - `(arrange t _).nCols = t.nCols`
  - `(filter t _).nCols = t.nCols`
  - `(pivotLonger t cols).nRows = t.nRows * cols.size`
  - `(pivotLonger t cols).nCols = t.nCols - cols.size + 2`

### Content preservation laws
  - `(arrange t col).nRows = t.nRows`  (sort doesn't lose rows)
  - `(rename t old new).colData new = t.colData old`  (rename preserves data)
  - `filter t (fun _ => true) = t`  (identity filter)
  - `head t t.nRows = t`  (head of all = identity)
  - `select t t.colNames = t`  (select all = identity)

### Aggregate laws
  - `(summarize g "n" col aggN).colFloats "n" |>.foldl (·+·) 0 = t.nRows`
    (group counts sum to total rows)
  - `aggMin cells ≤ aggMax cells`  (min ≤ max)
  - `aggMean cells` is between `aggMin cells` and `aggMax cells`

### Join laws
  - `innerJoin t1 t2 key ⊆ crossJoin t1 t2`  (inner join is a subset of cross)
  - `leftJoin t t empty key = t`  (left join with empty right = original)
  - `innerJoin t t key = t`  (self-join on key = identity, when key is unique)

### Reshape laws (pivotLonger ∘ pivotWider ≈ id)
  - `pivotWider (pivotLonger t cols) nameCol valCol ≈ t`  (round-trip)
  - `(pivotLonger t cols).nRows * 1 = t.nRows * cols.size`

### Window function laws
  - `lag xs 1 |>.size = xs.size`  (preserves length)
  - `cumSum xs |>.back = sum xs`  (last cumsum = total)
  - `rowNumber t |>.size = t.nRows`  (one number per row)

### String operation laws
  - `strDetect xs pat |>.size = xs.size`  (returns Bool per element)
  - `strReplace xs old new |>.size = xs.size`  (preserves length)

### Missing data laws
  - `(dropNa t col).nRows + (count NAs in col) = t.nRows`
  - `fillForward xs |>.filter (· == .na) |>.size ≤ xs.filter (· == .na) |>.size`
    (fill reduces NAs)

### CSV round-trip
  - `parseCsv (renderCsv t) ≈ t`  (parse ∘ render ≈ id)

### Pretty-print
  - `(prettyPrint t).splitOn "\n" |>.length ≥ t.nRows + 1`  (header + rows)
-/
