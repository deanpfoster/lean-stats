import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

def lag (xs : Array Cell) (n : Nat := 1) : Array Cell :=
  (Array.replicate (min n xs.size) Cell.na) ++ (xs.extract 0 (xs.size - n))

def lead (xs : Array Cell) (n : Nat := 1) : Array Cell :=
  (xs.extract n xs.size) ++ (Array.replicate (min n xs.size) Cell.na)

def rowNumber (n : Nat) : Array Cell :=
  (Array.range n).map fun i => Cell.float (Float.ofNat (i + 1))

def cumSum (xs : Array Float) : Array Float :=
  xs.foldl (init := #[]) fun acc x =>
    acc.push (acc.getD (acc.size - 1) 0 + x)

def runningMean (xs : Array Float) : Array Float :=
  (cumSum xs).mapIdx fun i v => v / Float.ofNat (i + 1)

end LeanTab
