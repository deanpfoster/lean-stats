import LeanStats.Report.Provenance

/-! # LeanStats.Report.Literate — parse markdown with Lean code chunks

Source format (`.lmd` or `.md`):

```markdown
---
title: My Analysis
author: Foster
date: 2026-05-19
---

# Introduction

We examine the relationship between weight and fuel efficiency.

```{lean caption="Figure 1: Weight vs MPG"}
terminalScatter (table.colFloats "wt" |>.zip (table.colFloats "mpg"))
```

The mean MPG is `{= mean (table.colFloats "mpg")}`.

## Discussion

The relationship appears nonlinear...
```

Rules:
- Everything outside fenced code blocks is prose (markdown)
- ```` ```{lean} ```` starts a code chunk (artifact)
- ```` ```{lean caption="..."} ```` adds a caption
- `` `{= expr}` `` is an inline computed value
- YAML frontmatter (between `---`) sets title/author/date
- The file is the source of truth — edit it like any markdown
-/

set_option autoImplicit false

namespace LeanStats.Report

/-- Look up a key in an association list. -/
private def lookupMeta (metadata : List (String × String)) (key : String) (default : String := "") : String :=
  match metadata.find? (·.1 == key) with
  | some (_, v) => v
  | none => default

/-- Parse a literate markdown document into a Document. -/
partial def parseLiterate (src : String) : Document :=
  let lines := src.splitOn "\n"
  let (metadata, rest) := parseFrontmatter lines
  let blocks := parseBlocks rest []
  { title := lookupMeta metadata "title" "Untitled"
    author := lookupMeta metadata "author"
    date := lookupMeta metadata "date"
    blocks := blocks }
where
  parseFrontmatter (lines : List String) : (List (String × String)) × List String :=
    match lines with
    | "---" :: rest =>
      let (yamlLines, after) := rest.span (· != "---")
      let metadata := yamlLines.filterMap fun line =>
        let parts := line.splitOn ":"
        if parts.length >= 2 then
          some ((parts.getD 0 "").trimAscii.toString,
            (String.intercalate ":" (parts.drop 1)).trimAscii.toString)
        else none
      (metadata, tailD after)
    | _ => ([], lines)
  tailD : List String → List String
    | [] => []
    | _ :: t => t
  parseBlocks (lines : List String) (acc : List Block) : List Block :=
    match lines with
    | [] => acc.reverse
    | line :: rest =>
      if line.startsWith "```{lean" then
        let caption := extractCaption line
        let (codeLines, after) := rest.span (· != "```")
        let code := String.intercalate "\n" codeLines
        let block := Block.artifact code "" caption
        parseBlocks (tailD after) (block :: acc)
      else
        let (proseLines, after) := collectProse (line :: rest) []
        let prose := String.intercalate "\n" proseLines
        if prose.trimAscii.toString != "" then
          parseBlocks after (Block.prose prose :: acc)
        else
          parseBlocks after acc
  collectProse (lines : List String) (acc : List String) : List String × List String :=
    match lines with
    | [] => (acc.reverse, [])
    | line :: rest =>
      if line.startsWith "```{lean" then (acc.reverse, line :: rest)
      else collectProse rest (line :: acc)
  extractCaption (fenceLine : String) : String :=
    let parts := fenceLine.splitOn "caption=\""
    if parts.length >= 2 then
      let afterQuote := parts.getD 1 ""
      (afterQuote.splitOn "\"").getD 0 ""
    else ""

/-- Render a literate source back to its markdown form (for editing). -/
def renderLiterate (doc : Document) : String :=
  let header := "---\ntitle: " ++ doc.title ++
    (if doc.author != "" then "\nauthor: " ++ doc.author else "") ++
    (if doc.date != "" then "\ndate: " ++ doc.date else "") ++
    "\n---\n\n"
  let body := doc.blocks.map fun
    | .prose text => text ++ "\n\n"
    | .artifact code _ caption =>
      let cap := if caption != "" then " caption=\"" ++ caption ++ "\"" else ""
      "```{lean" ++ cap ++ "}\n" ++ code ++ "\n```\n\n"
    | .value code _ label =>
      "`{= " ++ code ++ "}`" ++
      (if label != "" then " (" ++ label ++ ")" else "") ++ "\n\n"
  header ++ body.foldl (· ++ ·) ""

end LeanStats.Report
