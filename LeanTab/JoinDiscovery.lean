import LeanTab.Table
set_option autoImplicit false
namespace LeanTab

structure JoinCandidate where
  col1 : String
  col2 : String
  matchRate : Float
  sampleMatches : Array String
  deriving Repr

private def cellToKey : Cell → Option String
  | .str v => some v
  | .float v => some (toString v)
  | .na => none

private def computeMatchRate (c1 c2 : Column) : JoinCandidate :=
  let t2Set := c2.data.foldl (fun s c =>
    match cellToKey c with | some k => s.insert k | none => s) (Std.HashSet.empty)
  let (matched, total, samples) := c1.data.foldl (fun (m, t, samps) c =>
    match cellToKey c with
    | some k =>
      if t2Set.contains k then
        let samps' := if samps.size < 3 then samps.push k else samps
        (m + 1, t + 1, samps')
      else (m, t + 1, samps)
    | none => (m, t, samps)) (0, 0, #[])
  let rate := if total == 0 then 0.0 else Float.ofNat matched / Float.ofNat total
  { col1 := c1.name, col2 := c2.name, matchRate := rate, sampleMatches := samples }

def discoverJoinKeys (t1 t2 : Table) : Array JoinCandidate :=
  let pairs := t1.columns.foldl (fun acc c1 =>
    t2.columns.foldl (fun acc2 c2 =>
      if c1.name == c2.name then acc2.push (c1, c2) else acc2) acc) #[]
  let candidates := pairs.map fun (c1, c2) => computeMatchRate c1 c2
  let filtered := candidates.filter (·.matchRate > 0.1)
  filtered.qsort (·.matchRate > ·.matchRate)

def JoinCandidate.render (jc : JoinCandidate) : String :=
  let pct := toString (Float.round (jc.matchRate * 100))
  let samples := String.intercalate ", " jc.sampleMatches.toList
  s!"{jc.col1} ↔ {jc.col2}: {pct}% match (sample: {samples})"

def suggestJoins (t1 t2 : Table) : String :=
  let candidates := discoverJoinKeys t1 t2
  if candidates.isEmpty then "No join candidates found (matchRate > 10%)."
  else
    let lines := candidates.map (·.render)
    String.intercalate "\n" lines.toList

end LeanTab
