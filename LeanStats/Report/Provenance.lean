import LeanStats.Report.Html

/-! # LeanStats.Report.Provenance — reproducible documents with prose + code + output

A document is a sequence of **blocks**. Each block is one of:
- **Prose** — markdown/text written by the analyst (captions, discussion, interpretation)
- **Code** — the Lean expression that produces an output (the recipe)
- **Output** — the rendered result (SVG, table, value)

These three travel together. The document format preserves all three so that:
1. The HTML report shows prose + output (beautiful)
2. Hovering over output reveals the code (inspectable)
3. The code blocks alone form a valid Lean script (reproducible)
4. The prose blocks alone form the narrative (readable without code)

This is the Sweave/Knitr model but with a key difference: the code is
pure Lean expressions, not stateful notebook cells. Order doesn't matter
for correctness — only for narrative flow.
-/

set_option autoImplicit false

namespace LeanStats.Report

/-- Minimal escaping for HTML attribute values (single-quote context). -/
private def escapeAttr (s : String) : String :=
  s.replace "&" "&amp;" |>.replace "'" "&#39;" |>.replace "<" "&lt;" |>.replace ">" "&gt;"

/-- CSS for reproducible documents. -/
private def documentCss : String :=
  "body{font-family:system-ui,sans-serif;max-width:900px;margin:2em auto;line-height:1.6;color:#333}" ++
  "h1{margin-bottom:0}.meta{color:#666;margin-top:0}" ++
  ".prose{margin:1em 0}" ++
  "figure{position:relative;border:1px solid #e0e0e0;border-radius:6px;padding:16px;margin:1.5em 0}" ++
  "figcaption{font-style:italic;color:#666;margin-top:8px}" ++
  ".recipe-badge{position:absolute;top:8px;right:8px;cursor:pointer;font-size:14px;color:#999}" ++
  ".recipe-badge:hover{color:#3b82f6}" ++
  ".computed{background:#f0f7ff;padding:2px 6px;border-radius:3px;cursor:help}" ++
  ".recipe-popup{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);" ++
  "background:#1e1e1e;color:#d4d4d4;padding:20px;border-radius:8px;font-family:monospace;" ++
  "font-size:13px;white-space:pre-wrap;max-width:80%;max-height:60vh;overflow:auto;z-index:9999}" ++
  ".recipe-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:9998}"

/-- JS for showing recipe on click/hover. -/
private def provenanceJs : String :=
  "document.querySelectorAll('.recipe-badge').forEach(function(b){" ++
  "b.addEventListener('click',function(){" ++
    "var fig=b.closest('figure');var code=fig.dataset.recipe;" ++
    "var ov=document.createElement('div');ov.className='recipe-overlay';" ++
    "var popup=document.createElement('div');popup.className='recipe-popup';" ++
    "popup.textContent=code;" ++
    "document.body.appendChild(ov);document.body.appendChild(popup);" ++
    "ov.addEventListener('click',function(){ov.remove();popup.remove()})" ++
  "})})"

/-- A single block in a reproducible document. -/
inductive Block where
  /-- Prose/discussion (markdown text). -/
  | prose (text : String)
  /-- A computed artifact: code that produced it + the output + caption. -/
  | artifact (code : String) (output : String) (caption : String := "")
  /-- A computed value (inline, not a figure). -/
  | value (code : String) (result : String) (label : String := "")
  deriving Repr

/-- A reproducible document: title + sequence of blocks. -/
structure Document where
  title : String
  author : String := ""
  date : String := ""
  blocks : List Block
  deriving Repr

/-- Render a single block to HTML. -/
def renderBlock : Block → String
  | .prose text => "<div class=\"prose\">" ++ text ++ "</div>"
  | .artifact code output caption =>
    "<figure data-recipe='" ++ escapeAttr code ++ "'>" ++
    output ++
    (if caption != "" then "<figcaption>" ++ caption ++ "</figcaption>" else "") ++
    "<div class='recipe-badge' title='Click to see code'>⟨⟩</div>" ++
    "</figure>"
  | .value code result label =>
    "<span class='computed' data-recipe='" ++ escapeAttr code ++ "' title='" ++
    escapeAttr code ++ "'>" ++
    (if label != "" then label ++ " = " else "") ++ result ++ "</span>"

/-- Render a document to a self-contained HTML file with provenance.
    Prose renders as paragraphs. Artifacts render as figures with
    data-recipe attributes. Values render inline with tooltips. -/
def renderDocument (doc : Document) : String :=
  let header := "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>" ++
    doc.title ++ "</title><style>" ++ documentCss ++ "</style></head><body>"
  let titleBlock := "<h1>" ++ doc.title ++ "</h1>" ++
    (if doc.author != "" then "<p class=\"meta\">" ++ doc.author ++
      (if doc.date != "" then " · " ++ doc.date else "") ++ "</p>" else "")
  let body := doc.blocks.map renderBlock |>.foldl (· ++ ·) ""
  let footer := "<script>" ++ provenanceJs ++ "</script></body></html>"
  header ++ titleBlock ++ body ++ footer

/-- Extract just the code blocks — forms a reproducible Lean script. -/
def extractScript (doc : Document) (imports : String := "import LeanStats\nimport LeanTab") : String :=
  let header := "-- Reproducible script: " ++ doc.title ++ "\n" ++
    (if doc.author != "" then "-- Author: " ++ doc.author ++ "\n" else "") ++
    (if doc.date != "" then "-- Date: " ++ doc.date ++ "\n" else "") ++
    "\n" ++ imports ++ "\n\ndef main : IO Unit := do\n"
  let codeBlocks := doc.blocks.filterMap fun
    | .artifact code _ caption =>
      some ("  -- " ++ (if caption != "" then caption else "output") ++ "\n  " ++ code ++ "\n")
    | .value code _ label =>
      some ("  -- " ++ (if label != "" then label else "value") ++ "\n  " ++ code ++ "\n")
    | .prose text =>
      some ("  -- " ++ text.take 60 ++ "\n")
  header ++ codeBlocks.foldl (· ++ ·) ""

/-- Extract just the prose — forms the narrative without code. -/
def extractProse (doc : Document) : String :=
  let proseBlocks := doc.blocks.filterMap fun
    | .prose text => some (text ++ "\n\n")
    | .artifact _ _ caption => if caption != "" then some (caption ++ "\n\n") else none
    | .value _ result label => some ((if label != "" then label ++ " = " else "") ++ result ++ "\n")
  "# " ++ doc.title ++ "\n\n" ++ proseBlocks.foldl (· ++ ·) ""

end LeanStats.Report
