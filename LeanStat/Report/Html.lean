import LeanStat.Report.Tooltip

/-! # LeanStat.Report.Html — pure HTML report generator

Produces a self-contained HTML document from a `Report` (title +
sections). Each section can include prose and an optional SVG (e.g.
from `LeanStat.Plot.*`).

Pure: returns a `String`. The caller writes the file via IO. This
keeps `LeanStat` free of capability concerns; report-writing-to-disk
is the consumer's job.
-/

set_option autoImplicit false

namespace LeanStat.Report

structure Section where
  heading : String
  prose : String
  svg : Option String := none
  deriving Repr

structure Report where
  title : String
  subtitle : String
  sections : List Section
  deriving Repr

/-- Minimal CSS for clean layout. -/
def defaultCss : String :=
  "body{font-family:system-ui,sans-serif;margin:2em auto;max-width:900px;line-height:1.5;color:#333}" ++
  "h1{margin-bottom:0}h2{color:#666;font-weight:normal;margin-top:0}" ++
  "section{border:1px solid #e0e0e0;border-radius:6px;padding:16px;margin:16px 0}" ++
  "section h3{margin-top:0}" ++
  "svg{max-width:100%;height:auto}" ++
  tooltipCss

/-- Combined JS for tooltips and click handlers. -/
def defaultJs : String := tooltipJs

/-- Render a single section to HTML. -/
def renderSection (s : Section) : String :=
  "<section><h3>" ++ s.heading ++ "</h3><p>" ++ s.prose ++ "</p>" ++
  (match s.svg with | some svg => svg | none => "") ++
  "</section>"

/-- Generate a self-contained HTML file. -/
def renderReport (r : Report) : String :=
  "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>" ++ r.title ++
  "</title><style>" ++ defaultCss ++ "</style></head><body><h1>" ++ r.title ++
  "</h1><h2>" ++ r.subtitle ++ "</h2>" ++
  (r.sections.map renderSection).foldl (· ++ ·) "" ++
  "<script>" ++ defaultJs ++ "</script></body></html>"

end LeanStat.Report
