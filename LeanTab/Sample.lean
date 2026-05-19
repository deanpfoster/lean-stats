import LeanTab.Table

set_option autoImplicit false

namespace LeanTab
open Table

/-- Rows from index `lo` (inclusive) to `hi` (exclusive), clamped to valid range. -/
def slice (t : Table) (lo hi : Nat) : Table :=
  let n := t.nRows
  let lo' := min lo n
  let hi' := min hi n
  let hi' := max lo' hi'
  let indices := (Array.range (hi' - lo')).map (· + lo')
  { columns := t.columns.map fun c =>
      { c with data := indices.map fun i => c.data.getD i .na } }

/-- LCG step: next = (1103515245 * seed + 12345) % 2147483647 -/
private def lcgNext (seed : Nat) : Nat :=
  (1103515245 * seed + 12345) % 2147483647

/-- Generate `n` unique indices in [0, bound) using LCG with fuel. -/
private def uniqueIndices (n bound : Nat) (seed : Nat) : Array Nat :=
  let n := min n bound
  let fuel := n * bound + bound
  go fuel n bound seed #[]
where
  go (fuel remaining bound seed : Nat) (acc : Array Nat) : Array Nat :=
    match fuel with
    | 0 => acc
    | fuel' + 1 =>
      if remaining == 0 then acc
      else
        let s := lcgNext seed
        let idx := s % bound
        if acc.contains idx then go fuel' remaining bound s acc
        else go fuel' (remaining - 1) bound s (acc.push idx)

/-- Deterministic pseudo-random sample of `n` rows (without replacement). -/
def sampleN (t : Table) (n : Nat) (seed : Nat := 42) : Table :=
  let bound := t.nRows
  let indices := uniqueIndices n bound seed
  { columns := t.columns.map fun c =>
      { c with data := indices.map fun i => c.data.getD i .na } }

/-- Sample floor(frac * nRows) rows. -/
def sampleFrac (t : Table) (frac : Float) (seed : Nat := 42) : Table :=
  let n := (frac * t.nRows.toFloat).toUInt32.toNat
  sampleN t n seed

end LeanTab
