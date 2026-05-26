import LeanTab.Table
set_option autoImplicit false
namespace LeanTab

/-- Date as integer days since epoch 2000-01-01. -/
structure Date where
  daysSinceEpoch : Int  -- 2000-01-01 = day 0
  deriving Repr, BEq, Ord

/-- Time as Float seconds since midnight. -/
structure Time where
  secondsSinceMidnight : Float  -- 0.0 to 86400.0
  deriving Repr, BEq

/-- DateTime combining Date, Time, and timezone offset. -/
structure DateTime where
  date : Date
  time : Time
  tzOffsetMinutes : Int := 0
  deriving Repr, BEq

-- ═══════════════════════════════════════════════════════════════
-- Date helpers
-- ═══════════════════════════════════════════════════════════════

def isLeapYear (y : Int) : Bool :=
  y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)

def daysInMonth (y : Int) (m : Int) : Int :=
  if m == 2 then (if isLeapYear y then 29 else 28)
  else if m == 4 || m == 6 || m == 9 || m == 11 then 30
  else 31

def daysInYear (y : Int) : Int := if isLeapYear y then 366 else 365

/-- Days from 2000-01-01 to start of year y. -/
private partial def daysToYearFwd (yr : Int) (target : Int) (acc : Int) : Int :=
  if yr >= target then acc else daysToYearFwd (yr + 1) target (acc + daysInYear yr)

private partial def daysToYearBwd (yr : Int) (target : Int) (acc : Int) : Int :=
  if yr < target then acc else daysToYearBwd (yr - 1) target (acc - daysInYear yr)

private def daysToYear (y : Int) : Int :=
  if y >= 2000 then daysToYearFwd 2000 y 0
  else daysToYearBwd (y - 1) y 0

/-- Days from start of year to start of month m (1-indexed). -/
private partial def daysToMonthAux (y : Int) (mo : Int) (target : Int) (acc : Int) : Int :=
  if mo >= target then acc else daysToMonthAux y (mo + 1) target (acc + daysInMonth y mo)

private def daysToMonth (y : Int) (m : Int) : Int := daysToMonthAux y 1 m 0

def Date.fromYMD (y m d : Int) : Date :=
  { daysSinceEpoch := daysToYear y + daysToMonth y m + (d - 1) }

private partial def yearFromDaysFwd (y : Int) (d : Int) : Int × Int :=
  if d < daysInYear y then (y, d) else yearFromDaysFwd (y + 1) (d - daysInYear y)

private partial def yearFromDaysBwd (y : Int) (d : Int) : Int × Int :=
  let y' := y - 1
  let d' := d + daysInYear y'
  if d' >= 0 then (y', d') else yearFromDaysBwd y' d'

private partial def monthFromDaysAux (y : Int) (m : Int) (d : Int) : Int × Int :=
  let dm := daysInMonth y m
  if d < dm then (m, d) else monthFromDaysAux y (m + 1) (d - dm)

def Date.toYMD (dt : Date) : Int × Int × Int :=
  let (y, remDays) :=
    if dt.daysSinceEpoch >= 0 then yearFromDaysFwd 2000 dt.daysSinceEpoch
    else yearFromDaysBwd 2000 dt.daysSinceEpoch
  let (m, d) := monthFromDaysAux y 1 remDays
  (y, m, d + 1)

/-- 0=Monday ... 6=Sunday. 2000-01-01 was a Saturday (5). -/
def Date.dayOfWeek (d : Date) : Nat :=
  let r := (d.daysSinceEpoch + 5) % 7
  (if r < 0 then r + 7 else r).toNat

def Date.addDays (d : Date) (n : Int) : Date :=
  { daysSinceEpoch := d.daysSinceEpoch + n }

def Date.diffDays (a b : Date) : Int :=
  a.daysSinceEpoch - b.daysSinceEpoch

private def padInt (n : Int) (width : Nat) : String :=
  let s := toString (if n < 0 then -n else n)
  let pad := String.mk (List.replicate (width - s.length) '0')
  (if n < 0 then "-" else "") ++ pad ++ s

def Date.toString (d : Date) : String :=
  let (y, m, day) := d.toYMD
  s!"{padInt y 4}-{padInt m 2}-{padInt day 2}"

instance : ToString Date := ⟨Date.toString⟩

private def parseNat (s : String) : Option Nat :=
  let cs := s.toList
  if cs.isEmpty then none
  else if cs.all Char.isDigit then some (s.toNat!)
  else none

private def parseInt (s : String) : Option Int :=
  if s.isEmpty then none
  else if s.get 0 == '-' then
    parseNat (s.drop 1) |>.map fun n => -(Int.ofNat n)
  else parseNat s |>.map Int.ofNat

def Date.fromString (s : String) : Option Date :=
  let parts := s.splitOn "-"
  if s.startsWith "-" then
    match parts with
    | "" :: rest =>
      match rest with
      | yStr :: mStr :: dStr :: [] =>
        match parseInt ("-" ++ yStr), parseNat mStr, parseNat dStr with
        | some y, some m, some d => some (Date.fromYMD y m d)
        | _, _, _ => none
      | _ => none
    | _ => none
  else
    match parts with
    | yStr :: mStr :: dStr :: [] =>
      match parseInt yStr, parseNat mStr, parseNat dStr with
      | some y, some m, some d => some (Date.fromYMD y m d)
      | _, _, _ => none
    | _ => none

-- ═══════════════════════════════════════════════════════════════
-- Time helpers
-- ═══════════════════════════════════════════════════════════════

def Time.fromHMS (h m s : Nat) : Time :=
  { secondsSinceMidnight := Float.ofNat (h * 3600 + m * 60 + s) }

def Time.toHMS (t : Time) : Nat × Nat × Nat :=
  let total := t.secondsSinceMidnight.toUInt32.toNat
  let h := total / 3600
  let m := (total % 3600) / 60
  let s := total % 60
  (h, m, s)

def Time.toString (t : Time) : String :=
  let (h, m, s) := t.toHMS
  s!"{padInt h 2}:{padInt m 2}:{padInt s 2}"

instance : ToString Time := ⟨Time.toString⟩

-- ═══════════════════════════════════════════════════════════════
-- DateTime helpers
-- ═══════════════════════════════════════════════════════════════

def DateTime.toUTC (dt : DateTime) : DateTime :=
  if dt.tzOffsetMinutes == 0 then dt
  else
    let totalSec := dt.time.secondsSinceMidnight - Float.ofInt (dt.tzOffsetMinutes * 60)
    if totalSec < 0 then
      { date := dt.date.addDays (-1),
        time := { secondsSinceMidnight := totalSec + 86400.0 },
        tzOffsetMinutes := 0 }
    else if totalSec >= 86400.0 then
      { date := dt.date.addDays 1,
        time := { secondsSinceMidnight := totalSec - 86400.0 },
        tzOffsetMinutes := 0 }
    else
      { date := dt.date, time := { secondsSinceMidnight := totalSec }, tzOffsetMinutes := 0 }

def DateTime.toTimezone (dt : DateTime) (offsetMin : Int) : DateTime :=
  let utc := dt.toUTC
  let totalSec := utc.time.secondsSinceMidnight + Float.ofInt (offsetMin * 60)
  if totalSec < 0 then
    { date := utc.date.addDays (-1),
      time := { secondsSinceMidnight := totalSec + 86400.0 },
      tzOffsetMinutes := offsetMin }
  else if totalSec >= 86400.0 then
    { date := utc.date.addDays 1,
      time := { secondsSinceMidnight := totalSec - 86400.0 },
      tzOffsetMinutes := offsetMin }
  else
    { date := utc.date, time := { secondsSinceMidnight := totalSec }, tzOffsetMinutes := offsetMin }

private def formatTzOffset (offsetMin : Int) : String :=
  if offsetMin == 0 then "Z"
  else
    let sign := if offsetMin < 0 then "-" else "+"
    let abs := if offsetMin < 0 then -offsetMin else offsetMin
    let h := abs / 60
    let m := abs % 60
    s!"{sign}{padInt h 2}:{padInt m 2}"

def DateTime.toString (dt : DateTime) : String :=
  s!"{dt.date}T{dt.time}{formatTzOffset dt.tzOffsetMinutes}"

instance : ToString DateTime := ⟨DateTime.toString⟩

def DateTime.toFloat (dt : DateTime) : Float :=
  let utc := dt.toUTC
  Float.ofInt utc.date.daysSinceEpoch + utc.time.secondsSinceMidnight / 86400.0

def DateTime.fromFloat (f : Float) : DateTime :=
  let days := f.floor
  let frac := f - days
  { date := { daysSinceEpoch := Int.ofNat days.toUInt64.toNat },
    time := { secondsSinceMidnight := frac * 86400.0 },
    tzOffsetMinutes := 0 }

/-- Find char in string starting from a byte offset. Returns byte offset or string length. -/
private partial def findCharAfter (s : String) (c : Char) (startByte : Nat) : Nat :=
  let bytes := s.length
  let rec go (i : Nat) : Nat :=
    if i >= bytes then bytes
    else if s.get ⟨i⟩ == c then i
    else go (i + 1)
  go startByte

def DateTime.fromString (s : String) : Option DateTime := do
  let tIdx := s.posOf 'T'
  if tIdx == s.endPos then none
  else
    let datePart := s.extract 0 tIdx
    let rest := s.extract (s.next tIdx) s.endPos
    let date ← Date.fromString datePart
    -- find timezone separator
    let restLen := rest.length
    let (timePart, tzPart) :=
      let plusIdx := findCharAfter rest '+' 0
      if plusIdx < restLen then
        (rest.extract 0 ⟨plusIdx⟩, rest.extract ⟨plusIdx⟩ rest.endPos)
      else
        let minusIdx := findCharAfter rest '-' 8
        if minusIdx < restLen then
          (rest.extract 0 ⟨minusIdx⟩, rest.extract ⟨minusIdx⟩ rest.endPos)
        else if rest.endsWith "Z" then
          (rest.dropRight 1, "Z")
        else
          (rest, "")
    let timeParts := timePart.splitOn ":"
    match timeParts with
    | hStr :: mStr :: sStr :: [] =>
      let h ← parseNat hStr
      let m ← parseNat mStr
      let sec ← parseNat sStr
      let time := Time.fromHMS h m sec
      let tz ← if tzPart == "" || tzPart == "Z" then some (0 : Int)
        else
          let sign : Int := if tzPart.get 0 == '-' then -1 else 1
          let tzBody := tzPart.drop 1
          let tzParts := tzBody.splitOn ":"
          match tzParts with
          | thStr :: tmStr :: [] =>
            match parseNat thStr, parseNat tmStr with
            | some th, some tm => some (sign * (Int.ofNat th * 60 + Int.ofNat tm))
            | _, _ => none
          | _ => none
      some { date, time, tzOffsetMinutes := tz }
    | _ => none

-- ═══════════════════════════════════════════════════════════════
-- Cell integration
-- ═══════════════════════════════════════════════════════════════

def Cell.toDate : Cell → Option Date
  | .str s => Date.fromString s
  | _ => none

def Cell.fromDate (d : Date) : Cell := .str d.toString

def Cell.toDateTime : Cell → Option DateTime
  | .str s => DateTime.fromString s
  | _ => none

def Cell.fromDateTime (dt : DateTime) : Cell := .str dt.toString

-- ═══════════════════════════════════════════════════════════════
-- Table column helper
-- ═══════════════════════════════════════════════════════════════

def Table.parseDateColumn (t : Table) (colName : String) (_fmt : String := "iso") : Table :=
  let cols := t.columns.map fun c =>
    if c.name == colName then
      { c with data := c.data.map fun cell =>
          match cell.toDate with
          | some d => Cell.fromDate d
          | none => cell }
    else c
  { columns := cols }

end LeanTab
