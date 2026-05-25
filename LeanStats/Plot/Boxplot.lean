import LeanStats.Plot.Theme

/-! # LeanStats.Plot.Boxplot — interactive HTML comparison boxplots

Side-by-side vertical boxplots with selection/brushing, shared pointState,
and bidirectional WebSocket on port 9147.
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def boxCss : String :=
  "body{font-family:system-ui,sans-serif;margin:12px;color:#333}" ++
  "h2{margin:0 0 8px;display:inline}" ++
  ".title-bar{display:flex;align-items:center;gap:12px;margin-bottom:8px}" ++
  "#keepBtn{font-size:13px;padding:4px 8px;border:none;border-radius:4px;cursor:pointer;background:#3b82f6;color:#fff}" ++
  ".tooltip{position:fixed;background:#fff;border:1px solid #ccc;border-radius:4px;padding:6px 10px;font-size:11px;pointer-events:none;display:none;z-index:999;box-shadow:0 2px 6px rgba(0,0,0,.15)}"

private def boxJs : String :=
  "var M={t:30,r:20,b:40,l:55},boxW=40,gap=10;\n" ++
  "var totalW=M.l+groups.length*(boxW+gap)-gap+M.r;\n" ++
  "var H=400,ph=H-M.t-M.b;\n" ++
  "var allVals=[];groups.forEach(function(g,gi){g.values.forEach(function(v,vi){allVals.push({v:v,gi:gi,vi:vi})})});\n" ++
  "var yMin=Math.min.apply(null,allVals.map(function(p){return p.v}));\n" ++
  "var yMax=Math.max.apply(null,allVals.map(function(p){return p.v}));\n" ++
  "var pad=(yMax-yMin)*0.05||1;yMin-=pad;yMax+=pad;\n" ++
  "var sy=function(v){return M.t+ph-(v-yMin)/(yMax-yMin)*ph};\n" ++
  "var pointState=[];allVals.forEach(function(){pointState.push({selected:false})});\n" ++
  "var tooltip=document.getElementById('tt');\n" ++
  "function stats(arr){\n" ++
  "  var s=arr.slice().sort(function(a,b){return a-b}),n=s.length;\n" ++
  "  var med=n%2?s[(n-1)/2]:(s[n/2-1]+s[n/2])/2;\n" ++
  "  var q1=s[Math.floor(n*0.25)],q3=s[Math.floor(n*0.75)];\n" ++
  "  var iqr=q3-q1,lo=q1-1.5*iqr,hi=q3+1.5*iqr;\n" ++
  "  var wLo=s[0],wHi=s[n-1];\n" ++
  "  for(var i=0;i<n;i++){if(s[i]>=lo){wLo=s[i];break}}\n" ++
  "  for(var i=n-1;i>=0;i--){if(s[i]<=hi){wHi=s[i];break}}\n" ++
  "  var outliers=[];for(var i=0;i<n;i++)if(s[i]<lo||s[i]>hi)outliers.push(s[i]);\n" ++
  "  return{med:med,q1:q1,q3:q3,wLo:wLo,wHi:wHi,outliers:outliers,min:s[0],max:s[n-1],n:n}\n" ++
  "}\n" ++
  "function draw(){\n" ++
  "  var svg=document.getElementById('boxsvg');\n" ++
  "  var s='';\n" ++
  "  s+='<line class=\"axis\" x1=\"'+M.l+'\" y1=\"'+M.t+'\" x2=\"'+M.l+'\" y2=\"'+(H-M.b)+'\" />';\n" ++
  "  for(var i=0;i<=5;i++){var v=yMin+i/5*(yMax-yMin);var y=sy(v);\n" ++
  "    s+='<line x1=\"'+(M.l-4)+'\" y1=\"'+y+'\" x2=\"'+M.l+'\" y2=\"'+y+'\" class=\"axis\"/>';\n" ++
  "    s+='<text x=\"'+(M.l-8)+'\" y=\"'+(y+3)+'\" text-anchor=\"end\" font-size=\"10\">'+v.toPrecision(3)+'</text>'}\n" ++
  "  var ptIdx=0;\n" ++
  "  groups.forEach(function(g,gi){\n" ++
  "    var st=stats(g.values);\n" ++
  "    var cx=M.l+gi*(boxW+gap)+boxW/2;\n" ++
  "    var x1=cx-boxW/2,x2=cx+boxW/2;\n" ++
  "    s+='<rect x=\"'+x1+'\" y=\"'+sy(st.q3)+'\" width=\"'+boxW+'\" height=\"'+(sy(st.q1)-sy(st.q3))+'\" class=\"box point\" data-gi=\"'+gi+'\" style=\"cursor:pointer\"/>';\n" ++
  "    s+='<line x1=\"'+x1+'\" y1=\"'+sy(st.med)+'\" x2=\"'+x2+'\" y2=\"'+sy(st.med)+'\" class=\"fit\" stroke-width=\"2\"/>';\n" ++
  "    s+='<line x1=\"'+cx+'\" y1=\"'+sy(st.wHi)+'\" x2=\"'+cx+'\" y2=\"'+sy(st.q3)+'\" stroke=\"#333\"/>';\n" ++
  "    s+='<line x1=\"'+cx+'\" y1=\"'+sy(st.q1)+'\" x2=\"'+cx+'\" y2=\"'+sy(st.wLo)+'\" stroke=\"#333\"/>';\n" ++
  "    s+='<line x1=\"'+(cx-boxW/4)+'\" y1=\"'+sy(st.wHi)+'\" x2=\"'+(cx+boxW/4)+'\" y2=\"'+sy(st.wHi)+'\" stroke=\"#333\"/>';\n" ++
  "    s+='<line x1=\"'+(cx-boxW/4)+'\" y1=\"'+sy(st.wLo)+'\" x2=\"'+(cx+boxW/4)+'\" y2=\"'+sy(st.wLo)+'\" stroke=\"#333\"/>';\n" ++
  "    g.values.forEach(function(v,vi){\n" ++
  "      var lo=st.q1-1.5*(st.q3-st.q1),hi=st.q3+1.5*(st.q3-st.q1);\n" ++
  "      if(v<lo||v>hi){\n" ++
  "        var cls=pointState[ptIdx+vi].selected?'point selected':'point';\n" ++
  "        s+='<circle cx=\"'+cx+'\" cy=\"'+sy(v)+'\" r=\"3.5\" class=\"'+cls+'\" data-gi=\"'+gi+'\" data-vi=\"'+vi+'\" data-pi=\"'+(ptIdx+vi)+'\" style=\"cursor:pointer\"/>';\n" ++
  "      }\n" ++
  "    });\n" ++
  "    s+='<text x=\"'+cx+'\" y=\"'+(H-M.b+16)+'\" text-anchor=\"middle\" font-size=\"11\">'+g.name+'</text>';\n" ++
  "    ptIdx+=g.values.length;\n" ++
  "  });\n" ++
  "  svg.innerHTML=s;\n" ++
  "}\n" ++
  "draw();\n" ++
  "var svgEl=document.getElementById('boxsvg');\n" ++
  "svgEl.addEventListener('click',function(e){\n" ++
  "  var box=e.target.closest('.box');\n" ++
  "  if(box){\n" ++
  "    var gi=+box.dataset.gi,base=0;\n" ++
  "    for(var i=0;i<gi;i++)base+=groups[i].values.length;\n" ++
  "    if(!e.shiftKey)pointState.forEach(function(p){p.selected=false});\n" ++
  "    for(var i=0;i<groups[gi].values.length;i++)pointState[base+i].selected=true;\n" ++
  "    sendWs({event:'selection',text:'selected group '+groups[gi].name+' ('+groups[gi].values.length+' points)'});\n" ++
  "    draw();return;\n" ++
  "  }\n" ++
  "  var dot=e.target.closest('circle.point');\n" ++
  "  if(dot){\n" ++
  "    var pi=+dot.dataset.pi;\n" ++
  "    if(!e.shiftKey)pointState.forEach(function(p){p.selected=false});\n" ++
  "    pointState[pi].selected=!pointState[pi].selected;\n" ++
  "    sendWs({event:'selection',text:'toggled outlier point '+pi});\n" ++
  "    draw();return;\n" ++
  "  }\n" ++
  "  pointState.forEach(function(p){p.selected=false});draw();\n" ++
  "  sendWs({event:'selection',text:'selection cleared'});\n" ++
  "});\n" ++
  "svgEl.addEventListener('mousemove',function(e){\n" ++
  "  var box=e.target.closest('.box');\n" ++
  "  var dot=e.target.closest('circle.point');\n" ++
  "  if(box){\n" ++
  "    var gi=+box.dataset.gi,g=groups[gi],st=stats(g.values);\n" ++
  "    tooltip.innerHTML='<b>'+g.name+'</b><br>n='+st.n+'<br>median='+st.med.toPrecision(4)+'<br>Q1='+st.q1.toPrecision(4)+'<br>Q3='+st.q3.toPrecision(4)+'<br>min='+st.min.toPrecision(4)+'<br>max='+st.max.toPrecision(4);\n" ++
  "    tooltip.style.left=(e.clientX+12)+'px';tooltip.style.top=(e.clientY-10)+'px';tooltip.style.display='block';return;\n" ++
  "  }\n" ++
  "  if(dot){\n" ++
  "    var gi=+dot.dataset.gi,vi=+dot.dataset.vi;\n" ++
  "    tooltip.innerHTML='<b>'+groups[gi].name+'</b> outlier<br>value='+groups[gi].values[vi].toPrecision(4);\n" ++
  "    tooltip.style.left=(e.clientX+12)+'px';tooltip.style.top=(e.clientY-10)+'px';tooltip.style.display='block';return;\n" ++
  "  }\n" ++
  "  tooltip.style.display='none';\n" ++
  "});\n" ++
  "svgEl.addEventListener('mouseleave',function(){tooltip.style.display='none'});\n" ++
  "// WebSocket\n" ++
  "var ws;function wsConnect(){\n" ++
  "  try{ws=new WebSocket('ws://localhost:9147')}catch(e){return}\n" ++
  "  ws.onmessage=function(ev){\n" ++
  "    try{var msg=JSON.parse(ev.data);\n" ++
  "      if(msg.cmd==='select'&&msg.indices){msg.indices.forEach(function(i){if(i<pointState.length)pointState[i].selected=true});draw()}\n" ++
  "      if(msg.cmd==='reset'){pointState.forEach(function(p){p.selected=false});draw()}\n" ++
  "    }catch(e){}\n" ++
  "  };\n" ++
  "  ws.onclose=function(){setTimeout(wsConnect,2000)};\n" ++
  "}\n" ++
  "wsConnect();\n" ++
  "function sendWs(msg){if(ws&&ws.readyState===1)ws.send(JSON.stringify(msg))}\n" ++
  "document.getElementById('keepBtn').onclick=function(){\n" ++
  "  var sel=[];pointState.forEach(function(p,i){if(p.selected)sel.push(i)});\n" ++
  "  sendWs({cmd:'keep',indices:sel});\n" ++
  "};\n"

private def floatArrayJs (arr : Array Float) : String :=
  "[" ++ ",".intercalate (arr.toList.map toString) ++ "]"

/-- Generate a self-contained HTML page with interactive comparison boxplots.

Each group is rendered as a vertical boxplot (Q1–Q3 box, median line,
whiskers to 1.5×IQR, outlier dots). Click a box to select all points
in that group; click an outlier to select that point. Hover for summary
statistics. Shared pointState with bidirectional WebSocket (port 9147). -/
def boxplotPage (groups : Array (String × Array Float))
    (yName : String := "y") (title : String := "")
    (theme : LeanStats.Plot.Theme := LeanStats.Plot.Theme.tufte) : String :=
  let groupsJs := "[" ++ ",".intercalate (groups.toList.map fun (name, vals) =>
    "{name:\"" ++ name ++ "\",values:" ++ floatArrayJs vals ++ "}") ++ "]"
  let themeJs := "{pointColor:\"" ++ theme.pointColor ++ "\",selectedColor:\"" ++ theme.selectedColor ++ "\"}"
  "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>" ++ title ++ "</title>" ++
  "<style>" ++ boxCss ++ theme.toCss ++ "</style></head><body>" ++
  "<div class=\"title-bar\"><h2>" ++ (if title == "" then "Boxplot: " ++ yName else title) ++ "</h2>" ++
  "<button id=\"keepBtn\">📌 Keep</button></div>" ++
  "<svg id=\"boxsvg\" width=\"" ++ toString (55 + groups.size * 50) ++ "\" height=\"400\"></svg>" ++
  "<div id=\"tt\" class=\"tooltip\"></div>" ++
  "<script>\nvar groups=" ++ groupsJs ++ ";\nvar theme=" ++ themeJs ++ ";\n" ++
  boxJs ++ "</script></body></html>"

end LeanStats.Plot
