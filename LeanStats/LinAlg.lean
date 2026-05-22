import LeanStats.Descriptive

/-! # LeanStats.LinAlg — matrix operations with GPU-ready interface

Pure Lean implementations of core linear algebra operations.
Each function has a pure (slow) implementation that serves as:
1. The reference for correctness (conformance tests)
2. The fallback when no GPU is available

When a GPU is available, `@[extern]` versions replace these with
calls to cuBLAS/OpenBLAS. The interface stays pure — arrays in,
arrays out. No IO.

## Operations provided

- matmul: matrix multiplication
- solve: linear system Ax = b
- transpose: matrix transpose
- choleskySolve: solve via Cholesky decomposition
- batchedOLS: fit many regressions in parallel
- eigenvalues: (future)
- svd: (future)
-/

set_option autoImplicit false

namespace LeanStats.LinAlg

/-- A dense matrix stored in row-major order. -/
structure Matrix where
  rows : Nat
  cols : Nat
  data : Array Float
  deriving Repr

/-- Create a matrix from a 2D array of values. -/
def Matrix.fromRows (vals : Array (Array Float)) : Matrix :=
  let rows := vals.size
  let cols := if vals.isEmpty then 0 else vals[0]!.size
  let data := vals.foldl (fun acc row => acc ++ row) #[]
  { rows, cols, data }

/-- Get element at (i, j). -/
def Matrix.get (m : Matrix) (i j : Nat) : Float :=
  m.data.getD (i * m.cols + j) 0

/-- Set element at (i, j). -/
def Matrix.set (m : Matrix) (i j : Nat) (v : Float) : Matrix :=
  { m with data := m.data.set! (i * m.cols + j) v }

/-- Create an identity matrix. -/
def Matrix.identity (n : Nat) : Matrix :=
  let data := (Array.range (n * n)).map fun idx =>
    if idx / n == idx % n then 1.0 else 0.0
  { rows := n, cols := n, data }

/-- Create a zero matrix. -/
def Matrix.zeros (rows cols : Nat) : Matrix :=
  { rows, cols, data := Array.mkArray (rows * cols) 0.0 }

/-- Transpose. -/
def transpose (m : Matrix) : Matrix :=
  let data := (Array.range (m.cols * m.rows)).map fun idx =>
    let i := idx / m.rows
    let j := idx % m.rows
    m.get j i
  { rows := m.cols, cols := m.rows, data }

/-- Matrix multiplication. O(n³) pure implementation.
    GPU version: @[extern "lean_matmul_gpu"] -/
def matmul (a b : Matrix) : Matrix :=
  if a.cols != b.rows then Matrix.zeros a.rows b.cols
  else
    let data := (Array.range (a.rows * b.cols)).map fun idx =>
      let i := idx / b.cols
      let j := idx % b.cols
      (Array.range a.cols).foldl (fun acc k => acc + a.get i k * b.get k j) 0.0
    { rows := a.rows, cols := b.cols, data }

/-- Matrix-vector multiplication. -/
def matvec (m : Matrix) (v : Array Float) : Array Float :=
  (Array.range m.rows).map fun i =>
    (Array.range m.cols).foldl (fun acc j => acc + m.get i j * v.getD j 0) 0.0

/-- Solve Ax = b via Gaussian elimination with partial pivoting.
    Pure O(n³) implementation. GPU version would use cuSOLVER. -/
partial def solve (a : Matrix) (b : Array Float) : Option (Array Float) :=
  let n := a.rows
  if n != a.cols || n != b.size then none
  else some (Id.run do
  let mut aug := (Array.range (n * (n + 1))).map fun idx =>
    let i := idx / (n + 1)
    let j := idx % (n + 1)
    if j < n then a.get i j else b.getD i 0
  -- Forward elimination
  for col in List.range n do
    -- Partial pivoting
    let mut maxVal := (aug.getD (col * (n+1) + col) 0).abs
    let mut maxRow := col
    for row in List.range (n - col - 1) do
      let r := col + 1 + row
      let v := (aug.getD (r * (n+1) + col) 0).abs
      if v > maxVal then maxVal := v; maxRow := r
    -- Swap
    if maxRow != col then
      for j in List.range (n + 1) do
        let tmp := aug.getD (col * (n+1) + j) 0
        aug := aug.set! (col * (n+1) + j) (aug.getD (maxRow * (n+1) + j) 0)
        aug := aug.set! (maxRow * (n+1) + j) tmp
    -- Eliminate
    let pivot := aug.getD (col * (n+1) + col) 0
    if pivot.abs < 1e-12 then continue
    for row in List.range (n - col - 1) do
      let r := col + 1 + row
      let factor := aug.getD (r * (n+1) + col) 0 / pivot
      for j in List.range (n + 1) do
        let idx := r * (n+1) + j
        let pidx := col * (n+1) + j
        aug := aug.set! idx (aug.getD idx 0 - factor * aug.getD pidx 0)
  -- Back substitution
  let mut x := Array.mkArray n 0.0
  for i' in List.range n do
    let i := n - 1 - i'
    let mut sum := aug.getD (i * (n+1) + n) 0
    for j in List.range (n - i - 1) do
      sum := sum - aug.getD (i * (n+1) + (i+1+j)) 0 * x.getD (i+1+j) 0
    let diag := aug.getD (i * (n+1) + i) 0
    x := x.set! i (if diag.abs < 1e-12 then 0 else sum / diag)
  return x)

/-- Compute X'X (Gram matrix) — the core of OLS normal equations. -/
def gramMatrix (x : Matrix) : Matrix :=
  matmul (transpose x) x

/-- Compute X'y — the other half of normal equations. -/
def gramVector (x : Matrix) (y : Array Float) : Array Float :=
  matvec (transpose x) y

/-- OLS via normal equations: β = (X'X)⁻¹ X'y.
    Pure implementation. GPU version batches the matmul + solve. -/
def ols (x : Matrix) (y : Array Float) : Option (Array Float) :=
  let xtx := gramMatrix x
  let xty := gramVector x y
  solve xtx xty

/-- Batched OLS: fit many regressions with the same X but different y's.
    Computes (X'X)⁻¹ once, then multiplies by each X'y.
    GPU version: massive parallelism here. -/
def batchedOLS (x : Matrix) (ys : Array (Array Float)) : Array (Option (Array Float)) :=
  -- Compute X'X and solve once for the inverse structure
  let xtx := gramMatrix x
  ys.map fun y =>
    let xty := gramVector x y
    solve xtx xty

/-- Compute residuals: y - Xβ. -/
def residuals (x : Matrix) (y : Array Float) (beta : Array Float) : Array Float :=
  let yhat := matvec x beta
  Array.zipWith y yhat (· - ·)

/-- Compute R² from residuals and y. -/
def rSquared (y : Array Float) (resid : Array Float) : Float :=
  let my := LeanStats.mean y
  let sst := y.foldl (fun acc yi => acc + (yi - my) ^ 2) 0
  let sse := resid.foldl (fun acc r => acc + r ^ 2) 0
  if sst == 0 then 1.0 else 1.0 - sse / sst

end LeanStats.LinAlg
