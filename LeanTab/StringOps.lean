import LeanTab.Table

set_option autoImplicit false

namespace LeanTab

def strDetect (xs : Array Cell) (pat : String) : Array Bool :=
  xs.map fun c => match c with
    | .str s => (s.splitOn pat).length > 1
    | _ => false

def strReplace (xs : Array Cell) (old new_ : String) : Array Cell :=
  xs.map fun c => match c with
    | .str s => .str (String.intercalate new_ (s.splitOn old))
    | other => other

def strToUpper (xs : Array Cell) : Array Cell :=
  xs.map fun c => match c with
    | .str s => .str (s.map Char.toUpper)
    | other => other

def strToLower (xs : Array Cell) : Array Cell :=
  xs.map fun c => match c with
    | .str s => .str (s.map Char.toLower)
    | other => other

def strTrim (xs : Array Cell) : Array Cell :=
  xs.map fun c => match c with
    | .str s => .str s.trimAscii.toString
    | other => other

def strLength (xs : Array Cell) : Array Cell :=
  xs.map fun c => match c with
    | .str s => .float (Float.ofNat s.length)
    | _ => .na

end LeanTab
