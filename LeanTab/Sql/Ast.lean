import LeanTab.Table

/-! # LeanTab.Sql.Ast — SQL abstract syntax tree

A minimal SQL AST covering the core of SELECT queries:

  SELECT [columns | *]
  FROM table [JOIN table ON condition]
  WHERE condition
  GROUP BY columns [HAVING condition]
  ORDER BY column [ASC|DESC]
  LIMIT n

Expressions cover column references, literals, arithmetic, comparisons,
logical operators, and aggregate functions.

This is the AST only — no parsing. Queries are constructed programmatically
(by an agent, or eventually by a parser in `LeanTab.Sql.Parse`).
-/

set_option autoImplicit false

namespace LeanTab.Sql

/-- SQL scalar expression. -/
inductive Expr where
  /-- Column reference by name. -/
  | col (name : String)
  /-- Float literal. -/
  | litFloat (v : Float)
  /-- String literal. -/
  | litStr (v : String)
  /-- NULL. -/
  | null
  /-- Arithmetic: +, -, *, / -/
  | add (l r : Expr)
  | sub (l r : Expr)
  | mul (l r : Expr)
  | div (l r : Expr)
  /-- Comparison. -/
  | eq (l r : Expr)
  | neq (l r : Expr)
  | lt (l r : Expr)
  | gt (l r : Expr)
  | le (l r : Expr)
  | ge (l r : Expr)
  /-- Logical. -/
  | and (l r : Expr)
  | or (l r : Expr)
  | not (e : Expr)
  /-- IS NULL / IS NOT NULL. -/
  | isNull (e : Expr)
  | isNotNull (e : Expr)
  /-- BETWEEN. -/
  | between (e lo hi : Expr)
  /-- IN (list of literals). -/
  | inList (e : Expr) (vals : List Expr)
  deriving Repr

/-- Aggregate function. -/
inductive AggFn where
  | count | sum | avg | min | max
  | countStar  -- COUNT(*)
  deriving Repr, BEq

/-- A select item: either a plain expression or an aggregate. -/
inductive SelectItem where
  /-- expr AS alias -/
  | expr (e : Expr) (alias_ : Option String := none)
  /-- AGG(expr) AS alias -/
  | agg (fn : AggFn) (e : Expr) (alias_ : String)
  /-- SELECT * -/
  | star
  deriving Repr

/-- Sort direction. -/
inductive SortDir where
  | asc | desc
  deriving Repr, BEq

/-- ORDER BY clause item. -/
structure OrderItem where
  col : String
  dir : SortDir := .asc
  deriving Repr

/-- JOIN type. -/
inductive JoinKind where
  | inner | left | right | cross
  deriving Repr, BEq

/-- A JOIN clause. -/
structure JoinClause where
  kind : JoinKind
  table : String
  on_ : Option Expr := none  -- None for CROSS JOIN
  deriving Repr

/-- A complete SELECT query. -/
structure Query where
  select_ : List SelectItem
  from_ : String
  joins : List JoinClause := []
  where_ : Option Expr := none
  groupBy : List String := []
  having : Option Expr := none
  orderBy : List OrderItem := []
  limit : Option Nat := none
  deriving Repr

end LeanTab.Sql
