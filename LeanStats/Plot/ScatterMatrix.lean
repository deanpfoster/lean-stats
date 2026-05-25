import LeanStats.Plot.Theme

/-! # LeanStats.Plot.ScatterMatrix — scatterplot matrix (SPLOM) with linked selection

An n×n grid of small panels: off-diagonal scatter plots, diagonal histograms,
shared point state with cross-panel highlighting, and bidirectional WebSocket (port 9147).
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def splomCss (n : Nat) : String :=
  "body{font-family:system-ui,sans-serif;margin:12px;color:#333}" ++
  "h2{margin:0 0 8px;display:inline}" ++
  ".title-bar{display:flex;align-items:center;gap:12px;margin-bottom:8px}" ++
  "#keepBtn{font-size:13px;padding:4px 8px;border:none;border-radius:4px;cursor:pointer;background:#3b82f6;color:#fff}" ++
  s!".grid\{display:grid;grid-template-columns:repeat({n},180px);gap:2px}" ++
  ".cell{width:180px;height:180px;border:1px solid #e0e0e0;border-radius:3px;overflow:hidden}" ++
  ".tooltip{position:fixed;background:#fff;border:1px solid #ccc;border-radius:4px;padding:4px 8px;font-size:11px;pointer-events:none;display:none;z-index:999;box-shadow:0 2px 6px rgba(0,0,0,.15)}"

private def splomJs : String :=
  "var CW=180,CH=180,M={t:12,r:12,b:18,l:24};\n" ++
  "var cw=CW-M.l-M.r,ch=CH-M.t-M.b;\n" ++
  "var n=vars.length,nObs=vars[0].values.length;\n" ++
  "var pointState=[];for(var i=0;i<nObs;i++)pointState.push({selected:false,excluded:false,hidden:false});\n" ++
  "var tooltip=document.getElementById('tt');\n" ++
  "function scaleX(v,min,max){return M.l+(v-min)/(max-min)*cw}\n" ++
  "function scaleY(v,min,max){return M.t+ch-(v-min)/(max-min)*ch}\n" ++
  "function ptColor(i){if(pointState[i].excluded)return'#ccc';if(pointState[i].selected)return'orange';return'steelblue'}\n" ++
  "function ptClass(i){if(pointState[i].excluded)return'point excluded';if(pointState[i].selected)return'point selected';return'point'}\n" ++
  "function drawAll(){var cells=document.querySelectorAll('.cell');cells.forEach(function(c){var r=+c.dataset.row,col=+c.dataset.col;drawCell(r,col,c)})}\n" ++
  "function drawCell(row,col,el){\n" ++
  "  var vals_r=vars[row].values,vals_c=vars[col].values;\n" ++
  "  if(row===col){drawDiag(row,el);return}\n" ++
  "  var xmin=Math.min.apply(null,vals_c),xmax=Math.max.apply(null,vals_c);\n" ++
  "  var ymin=Math.min.apply(null,vals_r),ymax=Math.max.apply(null,vals_r);\n" ++
  "  var pad_x=(xmax-xmin)*0.05||1,pad_y=(ymax-ymin)*0.05||1;\n" ++
  "  xmin-=pad_x;xmax+=pad_x;ymin-=pad_y;ymax+=pad_y;\n" ++
  "  var svg='<svg width=\"'+CW+'\" height=\"'+CH+'\">';\n" ++
  "  svg+='<rect width=\"'+CW+'\" height=\"'+CH+'\" fill=\"#fafafa\" class=\"bg\"/>';\n" ++
  "  svg+='<text x=\"'+M.l+'\" y=\"'+(CH-2)+'\" font-size=\"9\" fill=\"#999\">'+xmin.toFixed(1)+'</text>';\n" ++
  "  svg+='<text x=\"'+(CW-M.r)+'\" y=\"'+(CH-2)+'\" font-size=\"9\" fill=\"#999\" text-anchor=\"end\">'+xmax.toFixed(1)+'</text>';\n" ++
  "  svg+='<text x=\"2\" y=\"'+(M.t+8)+'\" font-size=\"9\" fill=\"#999\">'+ymax.toFixed(1)+'</text>';\n" ++
  "  svg+='<text x=\"2\" y=\"'+(CH-M.b)+'\" font-size=\"9\" fill=\"#999\">'+ymin.toFixed(1)+'</text>';\n" ++
  "  for(var i=0;i<nObs;i++){\n" ++
  "    if(pointState[i].hidden)continue;\n" ++
  "    var cx=scaleX(vals_c[i],xmin,xmax),cy=scaleY(vals_r[i],ymin,ymax);\n" ++
  "    svg+='<circle cx=\"'+cx+'\" cy=\"'+cy+'\" r=\"2.5\" class=\"'+ptClass(i)+'\" data-i=\"'+i+'\"/>';\n" ++
  "  }\n" ++
  "  svg+='</svg>';el.innerHTML=svg;\n" ++
  "}\n" ++
  "function drawDiag(idx,el){\n" ++
  "  var vals=vars[idx].values;\n" ++
  "  var vmin=Math.min.apply(null,vals),vmax=Math.max.apply(null,vals);\n" ++
  "  var nBins=10,bw=(vmax-vmin)/nBins||1;\n" ++
  "  var bins=new Array(nBins).fill(0);\n" ++
  "  var selBins=new Array(nBins).fill(0);\n" ++
  "  for(var i=0;i<nObs;i++){if(pointState[i].hidden)continue;var b=Math.min(Math.floor((vals[i]-vmin)/bw),nBins-1);bins[b]++;if(pointState[i].selected)selBins[b]++}\n" ++
  "  var bmax=Math.max.apply(null,bins)||1;\n" ++
  "  var svg='<svg width=\"'+CW+'\" height=\"'+CH+'\">';\n" ++
  "  svg+='<rect width=\"'+CW+'\" height=\"'+CH+'\" fill=\"#fafafa\" class=\"bg\"/>';\n" ++
  "  svg+='<text x=\"'+(CW/2)+'\" y=\"20\" text-anchor=\"middle\" font-size=\"12\" font-weight=\"bold\">'+vars[idx].name+'</text>';\n" ++
  "  var barW=cw/nBins;\n" ++
  "  for(var i=0;i<nBins;i++){\n" ++
  "    var h=bins[i]/bmax*(ch-20),x=M.l+i*barW,y=M.t+20+(ch-20)-h;\n" ++
  "    svg+='<rect x=\"'+x+'\" y=\"'+y+'\" width=\"'+(barW-1)+'\" height=\"'+h+'\" fill=\"steelblue\" opacity=\"0.5\" data-bin=\"'+i+'\" data-var=\"'+idx+'\" style=\"cursor:pointer\"/>';\n" ++
  "    if(selBins[i]>0){var sh=h*(selBins[i]/bins[i]);svg+='<rect x=\"'+x+'\" y=\"'+(y+h-sh)+'\" width=\"'+(barW-1)+'\" height=\"'+sh+'\" fill=\"#f59e0b\" opacity=\"0.8\" data-bin=\"'+i+'\" data-var=\"'+idx+'\" style=\"cursor:pointer\"/>'}\n" ++
  "  }\n" ++
  "  svg+='</svg>';el.innerHTML=svg;\n" ++
  "}\n" ++
  "drawAll();\n" ++
  "document.querySelector('.grid').addEventListener('click',function(e){\n" ++
  "  var c=e.target.closest('circle');\n" ++
  "  if(c){\n" ++
  "    var idx=+c.dataset.i;\n" ++
  "    if(!e.shiftKey)for(var i=0;i<nObs;i++)pointState[i].selected=false;\n" ++
  "    pointState[idx].selected=!pointState[idx].selected;\n" ++
  "    var nSel=pointState.filter(function(p){return p.selected}).length;\n" ++
  "    if(pointState[idx].selected){\n" ++
  "      var desc='obs '+idx+': '+vars.map(function(v){return v.name+'='+v.values[idx].toPrecision(4)}).join(', ');\n" ++
  "      if(e.shiftKey)sendWs({event:'selection',text:'added '+desc+' (now '+nSel+' selected)'});\n" ++
  "      else sendWs({event:'selection',text:'selected '+desc})\n" ++
  "    }else{sendWs({event:'selection',text:'deselected obs '+idx+' (now '+nSel+' selected)'})}\n" ++
  "    drawAll();return;\n" ++
  "  }\n" ++
  "  var bar=e.target.closest('[data-bin]');\n" ++
  "  if(bar){\n" ++
  "    var binIdx=+bar.dataset.bin,varIdx=+bar.dataset.var;\n" ++
  "    var vals=vars[varIdx].values;\n" ++
  "    var mn=Math.min.apply(null,vals),mx=Math.max.apply(null,vals);\n" ++
  "    var range=mx-mn||1,nBins=10,bw=range/nBins;\n" ++
  "    if(!e.shiftKey)for(var i=0;i<nObs;i++)pointState[i].selected=false;\n" ++
  "    var cnt=0;for(var i=0;i<nObs;i++){\n" ++
  "      var b=Math.floor((vals[i]-mn)/bw);if(b>=nBins)b=nBins-1;\n" ++
  "      if(b===binIdx){pointState[i].selected=true;cnt++}\n" ++
  "    }\n" ++
  "    var lo=(mn+binIdx*bw).toPrecision(3),hi=(mn+(binIdx+1)*bw).toPrecision(3);\n" ++
  "    sendWs({event:'selection',text:cnt+' points selected with '+vars[varIdx].name+' in ['+lo+', '+hi+']'});\n" ++
  "    drawAll();return;\n" ++
  "  }\n" ++
  "  if(e.target.classList.contains('bg')){\n" ++
  "    if(!e.shiftKey){for(var i=0;i<nObs;i++)pointState[i].selected=false;drawAll();\n" ++
  "    sendWs({event:'selection',text:'selection cleared'})}\n" ++
  "  }\n" ++
  "});\n" ++
  "document.querySelector('.grid').addEventListener('mousemove',function(e){\n" ++
  "  var c=e.target.closest('circle');\n" ++
  "  if(c){\n" ++
  "    var idx=+c.dataset.i;\n" ++
  "    var parts=[];\n" ++
  "    if(labels&&labels[idx])parts.push('<b>'+labels[idx]+'</b>');\n" ++
  "    for(var j=0;j<n;j++)parts.push(vars[j].name+': '+vars[j].values[idx].toFixed(2));\n" ++
  "    tooltip.innerHTML=parts.join('<br>');\n" ++
  "    tooltip.style.left=(e.clientX+12)+'px';tooltip.style.top=(e.clientY-10)+'px';tooltip.style.display='block';\n" ++
  "  } else {tooltip.style.display='none'}\n" ++
  "});\n" ++
  "document.querySelector('.grid').addEventListener('mouseleave',function(){tooltip.style.display='none'});\n" ++
  "// WebSocket\n" ++
  "var ws;function wsConnect(){\n" ++
  "  try{ws=new WebSocket('ws://localhost:9147')}catch(e){return}\n" ++
  "  ws.onmessage=function(ev){\n" ++
  "    try{var msg=JSON.parse(ev.data);\n" ++
  "      if(msg.cmd==='select'&&msg.indices){msg.indices.forEach(function(i){if(i<nObs)pointState[i].selected=true});drawAll()}\n" ++
  "      if(msg.cmd==='exclude'&&msg.indices){msg.indices.forEach(function(i){if(i<nObs)pointState[i].excluded=true});drawAll()}\n" ++
  "      if(msg.cmd==='reset'){for(var i=0;i<nObs;i++){pointState[i].selected=false;pointState[i].excluded=false;pointState[i].hidden=false};drawAll()}\n" ++
  "    }catch(e){}\n" ++
  "  };\n" ++
  "  ws.onclose=function(){setTimeout(wsConnect,2000)};\n" ++
  "}\n" ++
  "wsConnect();\n" ++
  "function sendWs(msg){if(ws&&ws.readyState===1)ws.send(JSON.stringify(msg))}\n" ++
  "document.getElementById('keepBtn').onclick=function(){\n" ++
  "  var sel=[];for(var i=0;i<nObs;i++)if(pointState[i].selected)sel.push(i);\n" ++
  "  sendWs({cmd:'keep',indices:sel});\n" ++
  "};\n" ++
  "document.getElementById('invertBtn').onclick=function(){\n" ++
  "  for(var i=0;i<nObs;i++)if(!pointState[i].hidden)pointState[i].selected=!pointState[i].selected;\n" ++
  "  var nSel=pointState.filter(function(p){return p.selected}).length;\n" ++
  "  sendWs({event:'selection',text:'selection inverted (now '+nSel+' selected)'});\n" ++
  "  drawAll();\n" ++
  "};\n"

private def floatArrayToJs (arr : Array Float) : String :=
  "[" ++ ",".intercalate (arr.toList.map toString) ++ "]"

/-- Generate a scatterplot matrix (SPLOM) HTML page with linked cross-panel selection. -/
def scatterMatrix (vars : Array (String × Array Float))
    (labels : Option (Array String) := none)
    (title : String := "")
    (theme : LeanStats.Plot.Theme := LeanStats.Plot.Theme.tufte) : String :=
  let n := vars.size
  let varsJs := "[" ++ ",".intercalate (vars.toList.map fun (name, vals) =>
    "{name:\"" ++ name ++ "\",values:" ++ floatArrayToJs vals ++ "}") ++ "]"
  let labelsJs := match labels with
    | some ls => "[" ++ ",".intercalate (ls.toList.map fun l => "\"" ++ l ++ "\"") ++ "]"
    | none => "null"
  let gridHtml := String.join ((List.range n |>.map fun r =>
    List.range n |>.map fun c =>
      "<div class=\"cell\" data-row=\"" ++ toString r ++ "\" data-col=\"" ++ toString c ++ "\"></div>").flatten)
  "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>" ++ title ++ "</title>" ++
  "<style>" ++ splomCss n ++ theme.toCss ++ "</style></head><body>" ++
  "<div class=\"title-bar\"><h2>" ++ title ++ "</h2><button id=\"keepBtn\">📌 Keep</button><button id=\"invertBtn\" style=\"font-size:13px;padding:4px 8px;border:1px solid #ccc;border-radius:4px;cursor:pointer;margin-left:8px\">⇄ Invert</button></div>" ++
  "<div class=\"grid\">" ++ gridHtml ++ "</div>" ++
  "<div id=\"tt\" class=\"tooltip\"></div>" ++
  "<script>\nvar vars=" ++ varsJs ++ ";\nvar labels=" ++ labelsJs ++ ";\n" ++
  splomJs ++ "</script></body></html>"

end LeanStats.Plot
