import LeanStats.Report.Tooltip

/-! # LeanStats.Report.Interactive — cross-plot brushing and point identification

Pure JS/CSS strings for interactive HTML reports. When embedded in a
report containing multiple SVG plots, this enables:

1. **Hover identification**: mouse over a point → tooltip shows obs index,
   coordinates, and diagnostics.
2. **Click selection**: click a point → it's selected (highlighted) across
   ALL plots on the page that share the same `data-id`.
3. **Lasso selection**: drag to draw a freeform region → all enclosed points
   are selected across all plots.
4. **Selection summary**: a floating panel shows count and mean of selected
   points.

The contract: every SVG element representing an observation MUST have
`data-id='<index>'` and optionally `data-tooltip='<text>'`. The JS is
generic — it doesn't know about statistics, only about `data-id` matching.
-/

set_option autoImplicit false

namespace LeanStats.Report

/-- CSS for interactive selection states and the selection panel. -/
def interactiveCss : String :=
  "[data-id]{cursor:pointer;transition:opacity 0.15s,r 0.15s}" ++
  "[data-id].selected{stroke:#f59e0b;stroke-width:2;opacity:1}" ++
  "[data-id].dimmed{opacity:0.2}" ++
  ".lasso{fill:rgba(59,130,246,0.1);stroke:#3b82f6;stroke-width:1;stroke-dasharray:4}" ++
  ".sel-panel{position:fixed;bottom:16px;right:16px;background:#fff;border:1px solid #e0e0e0;" ++
  "border-radius:8px;padding:12px 16px;font-size:13px;box-shadow:0 2px 8px rgba(0,0,0,0.1);z-index:900;display:none}" ++
  ".sel-panel.active{display:block}" ++
  ".sel-panel .count{font-weight:bold;color:#3b82f6}"

/-- JS implementing the shared selection model and cross-plot brushing.

Design:
- `window.__sel` is a Set of selected data-id strings.
- Any click on `[data-id]` toggles that id in the set.
- Any change to `__sel` triggers `syncSelection()` which updates all
  `[data-id]` elements on the page: selected get `.selected`, others
  get `.dimmed` (if any selection exists), or all classes removed (if
  selection is empty).
- Lasso: mousedown on SVG background starts path recording; mousemove
  extends; mouseup closes polygon and selects all `[data-id]` circles
  whose center is inside the polygon.
-/
def interactiveJs : String :=
  "(function(){" ++
  -- Selection state
  "var sel=new Set();" ++
  "var panel=document.createElement('div');panel.className='sel-panel';" ++
  "panel.innerHTML='<span class=\"count\">0</span> selected <button id=\"sel-clear\">Clear</button>';" ++
  "document.body.appendChild(panel);" ++
  -- Sync all elements
  "function sync(){" ++
    "var els=document.querySelectorAll('[data-id]');" ++
    "var hasSelection=sel.size>0;" ++
    "panel.className=hasSelection?'sel-panel active':'sel-panel';" ++
    "panel.querySelector('.count').textContent=sel.size;" ++
    "els.forEach(function(el){" ++
      "var id=el.dataset.id;" ++
      "if(hasSelection){" ++
        "el.classList.toggle('selected',sel.has(id));" ++
        "el.classList.toggle('dimmed',!sel.has(id))" ++
      "}else{" ++
        "el.classList.remove('selected','dimmed')" ++
      "}" ++
    "})" ++
  "}" ++
  -- Click handler
  "document.addEventListener('click',function(e){" ++
    "var t=e.target.closest('[data-id]');" ++
    "if(!t)return;" ++
    "var id=t.dataset.id;" ++
    "if(e.shiftKey){sel.has(id)?sel.delete(id):sel.add(id)}" ++
    "else{var was=sel.has(id)&&sel.size===1;sel.clear();if(!was)sel.add(id)}" ++
    "sync()" ++
  "});" ++
  -- Clear button
  "document.getElementById('sel-clear').addEventListener('click',function(){sel.clear();sync()});" ++
  -- Lasso
  "var svgs=document.querySelectorAll('svg');" ++
  "svgs.forEach(function(svg){" ++
    "var pts=[],path=null,active=false;" ++
    "svg.addEventListener('mousedown',function(e){" ++
      "if(e.target.closest('[data-id]'))return;" ++
      "active=true;pts=[];var r=svg.getBoundingClientRect();" ++
      "pts.push([e.clientX-r.left,e.clientY-r.top]);" ++
      "path=document.createElementNS('http://www.w3.org/2000/svg','path');" ++
      "path.setAttribute('class','lasso');svg.appendChild(path)" ++
    "});" ++
    "svg.addEventListener('mousemove',function(e){" ++
      "if(!active)return;var r=svg.getBoundingClientRect();" ++
      "pts.push([e.clientX-r.left,e.clientY-r.top]);" ++
      "path.setAttribute('d','M'+pts.map(function(p){return p[0]+','+p[1]}).join('L')+'Z')" ++
    "});" ++
    "svg.addEventListener('mouseup',function(){" ++
      "if(!active)return;active=false;" ++
      "if(path)path.remove();" ++
      "if(pts.length<3)return;" ++
      -- Point-in-polygon for each data-id element in this SVG
      "if(!e.shiftKey)sel.clear();" ++
      "svg.querySelectorAll('[data-id]').forEach(function(el){" ++
        "var cx=parseFloat(el.getAttribute('cx')||el.getAttribute('x')||0);" ++
        "var cy=parseFloat(el.getAttribute('cy')||el.getAttribute('y')||0);" ++
        "if(pip(pts,cx,cy))sel.add(el.dataset.id)" ++
      "});sync()" ++
    "})" ++
  "});" ++
  -- Point-in-polygon (ray casting)
  "function pip(poly,x,y){" ++
    "var inside=false;" ++
    "for(var i=0,j=poly.length-1;i<poly.length;j=i++){" ++
      "var xi=poly[i][0],yi=poly[i][1],xj=poly[j][0],yj=poly[j][1];" ++
      "if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)inside=!inside" ++
    "}return inside" ++
  "}" ++
  "})()"

/-- Combined interactive CSS (includes tooltip + interactive). -/
def fullInteractiveCss : String := tooltipCss ++ interactiveCss

/-- Combined interactive JS (includes tooltip + brushing). -/
def fullInteractiveJs : String := tooltipJs ++ interactiveJs

end LeanStats.Report
