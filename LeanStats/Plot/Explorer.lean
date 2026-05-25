import LeanStats.Descriptive
import LeanStats.Plot.Theme

/-! # LeanStats.Plot.Explorer — JMP-style scatter+histogram with point state and WebSocket

Combined scatter + histogram interactive page with per-point state management
(selected/excluded/hidden) and bidirectional WebSocket on port 9147.
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def explorerCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".main-grid{display:grid;grid-template-columns:60px 500px 200px;grid-template-rows:400px auto;gap:4px;margin:8px 0}" ++
  ".y-ctrl{grid-column:1;grid-row:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;writing-mode:vertical-rl;transform:rotate(180deg)}" ++
  ".y-label{font-weight:bold;font-size:14px}" ++
  ".y-ctrl select{font-size:11px;writing-mode:horizontal-tb;transform:rotate(180deg)}" ++
  "#scatter{grid-column:2;grid-row:1;border:1px solid #e0e0e0;border-radius:6px}" ++
  "#histo{grid-column:3;grid-row:1;border:1px solid #e0e0e0;border-radius:6px}" ++
  ".x-ctrl{grid-column:2;grid-row:2;text-align:center;font-size:13px;padding:8px 0}" ++
  ".x-ctrl select{font-size:12px}" ++
  ".toolbar{margin:12px 0 12px 64px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;font-size:13px}" ++
  ".toolbar select,.toolbar button,.toolbar label{font-size:13px}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer;padding:4px 8px}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  ".legend{margin:8px 0 0 64px;font-size:12px;font-family:monospace}" ++
  "svg{display:block}"

private def explorerJs1 : String :=
  "const SW=500,SH=400,HW=200,HH=400,M={t:15,r:15,b:30,l:45};" ++
  "const pw=SW-M.l-M.r,ph=SH-M.t-M.b;" ++
  "const scatter=document.getElementById('scatter');" ++
  "const histo=document.getElementById('histo');" ++
  "var n=rawX.length;" ++
  "var pointState=new Array(n);for(var i=0;i<n;i++)pointState[i]={selected:false,excluded:false,hidden:false};" ++
  "var fits=[];var colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2'];" ++
  "function tx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'square':return v*v;case'exp':return Math.exp(v);default:return v}}" ++
  "function polyFit(x,y,deg){" ++
    "var nn=x.length;if(nn<=deg)return null;" ++
    "var X=[];for(var i=0;i<nn;i++){var row=[];for(var j=0;j<=deg;j++)row.push(Math.pow(x[i],j));X.push(row)}" ++
    "var XtX=[];for(var i=0;i<=deg;i++){XtX[i]=[];for(var j=0;j<=deg;j++){var s=0;for(var k=0;k<nn;k++)s+=X[k][i]*X[k][j];XtX[i][j]=s}}" ++
    "var Xty=[];for(var i=0;i<=deg;i++){var s=0;for(var k=0;k<nn;k++)s+=X[k][i]*y[k];Xty[i]=s}" ++
    "var A=XtX.map(function(r,i){return r.concat([Xty[i]])});" ++
    "var m=A.length;" ++
    "for(var i=0;i<m;i++){var mx=i;for(var j=i+1;j<m;j++)if(Math.abs(A[j][i])>Math.abs(A[mx][i]))mx=j;var tmp=A[i];A[i]=A[mx];A[mx]=tmp;" ++
    "if(Math.abs(A[i][i])<1e-12)continue;" ++
    "for(var j=i+1;j<m;j++){var f=A[j][i]/A[i][i];for(var k=i;k<=m;k++)A[j][k]-=f*A[i][k]}}" ++
    "var coef=new Array(m);" ++
    "for(var i=m-1;i>=0;i--){coef[i]=A[i][m];for(var j=i+1;j<m;j++)coef[i]-=A[i][j]*coef[j];coef[i]/=A[i][i]}" ++
    "return coef}" ++
  "function polyEval(coef,x){var y=0;for(var i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}"

private def explorerJs2 : String :=
  "function drawScatter(){" ++
    "var xf=document.getElementById('xform').value;" ++
    "var yf=document.getElementById('yform').value;" ++
    "var deg=parseInt(document.getElementById('degree').value);" ++
    "var pts=[];for(var i=0;i<n;i++){if(pointState[i].hidden)continue;var xt=tx(rawX[i],xf),yt=tx(rawY[i],yf);if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt))pts.push({idx:i,x:xt,y:yt})}" ++
    "if(pts.length<2){scatter.innerHTML='<text x=\"250\" y=\"200\" text-anchor=\"middle\">Not enough points</text>';return}" ++
    "var xArr=pts.map(function(p){return p.x}),yArr=pts.map(function(p){return p.y});" ++
    "var xMin=Math.min.apply(null,xArr),xMax=Math.max.apply(null,xArr),yMin=Math.min.apply(null,yArr),yMax=Math.max.apply(null,yArr);" ++
    "var xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "var sx=function(v){return(v-xMin)/xR*pw+M.l};" ++
    "var sy=function(v){return SH-M.b-(v-yMin)/yR*ph};" ++
    "var s='';" ++
    -- Background rect for click-to-clear
    "s+=\"<rect x='0' y='0' width='\"+SW+\"' height='\"+SH+\"' fill='transparent' id='scatterBg'/>\";" ++
    -- Axes
    "s+=\"<line class='axis' x1='\"+M.l+\"' y1='\"+(SH-M.b)+\"' x2='\"+(M.l+pw)+\"' y2='\"+(SH-M.b)+\"'/>\";" ++
    "s+=\"<line class='axis' x1='\"+M.l+\"' y1='\"+M.t+\"' x2='\"+M.l+\"' y2='\"+(SH-M.b)+\"'/>\";" ++
    "for(var i=0;i<=4;i++){var v=xMin+i/4*xR;s+=\"<text x='\"+sx(v)+\"' y='\"+(SH-M.b+15)+\"' text-anchor='middle' font-size='11'>\"+v.toPrecision(3)+\"</text>\"}" ++
    "for(var i=0;i<=4;i++){var v=yMin+i/4*yR;s+=\"<text x='\"+(M.l-8)+\"' y='\"+(sy(v)+4)+\"' text-anchor='end' font-size='11'>\"+v.toPrecision(3)+\"</text>\"}" ++
    -- Auto-fit line on non-excluded
    "var fitPts=pts.filter(function(p){return !pointState[p.idx].excluded});" ++
    "if(fitPts.length>deg){" ++
      "var fx=fitPts.map(function(p){return p.x}),fy=fitPts.map(function(p){return p.y});" ++
      "var coef=polyFit(fx,fy,deg);" ++
      "if(coef){" ++
        "var path='';for(var i=0;i<=100;i++){var xv=xMin+i/100*xR;var yv=polyEval(coef,xv);if(yv>=yMin-yR&&yv<=yMax+yR){path+=(path===''?'M':'L')+sx(xv)+','+sy(yv)}}" ++
        "s+=\"<path class='fit' d='\"+path+\"'/>\";" ++
        -- SE band
        "var sse=0;for(var i=0;i<fx.length;i++){var yh=polyEval(coef,fx[i]);sse+=(fy[i]-yh)*(fy[i]-yh)}" ++
        "var se=Math.sqrt(sse/(fx.length-deg-1));" ++
        "var xbar=fx.reduce(function(a,b){return a+b},0)/fx.length;" ++
        "var Sxx=fx.reduce(function(a,v){return a+(v-xbar)*(v-xbar)},0);" ++
        "var bandU='',bandL='';for(var i=0;i<=100;i++){var xv=xMin+i/100*xR;var yv=polyEval(coef,xv);var h=1/fx.length+(xv-xbar)*(xv-xbar)/Sxx;var b=1.96*se*Math.sqrt(h);bandU+=(bandU===''?'M':'L')+sx(xv)+','+sy(yv+b);bandL+=(bandL===''?'M':'L')+sx(xv)+','+sy(yv-b)}" ++
        "s+=\"<path class='ci' d='\"+bandU+\"'/>\";" ++
        "s+=\"<path class='ci' d='\"+bandL+\"'/>\"" ++
      "}" ++
    "}" ++
    -- Checkpoint lines
    "fits.forEach(function(spec,idx){" ++
      "var col=colors[idx%colors.length];" ++
      "var path='';for(var i=0;i<=100;i++){var xv=xMin+i/100*xR;var yv=polyEval(spec.coef,xv);if(yv>=yMin-yR&&yv<=yMax+yR){path+=(path===''?'M':'L')+sx(xv)+','+sy(yv)}}" ++
      "s+=\"<path class='fit' d='\"+path+\"'/>\"" ++
    "});" ++
    -- Points
    "pts.forEach(function(p){" ++
      "var st=pointState[p.idx];" ++
      "if(st.excluded){s+=\"<text x='\"+sx(p.x)+\"' y='\"+(sy(p.y)+4)+\"' text-anchor='middle' font-size='12' class='point excluded' data-idx='\"+p.idx+\"' style='cursor:pointer'>×</text>\"}" ++
      "else if(st.selected){s+=\"<circle class='point selected' cx='\"+sx(p.x)+\"' cy='\"+sy(p.y)+\"' data-idx='\"+p.idx+\"' style='cursor:pointer'/>\"}" ++
      "else{s+=\"<circle class='point' cx='\"+sx(p.x)+\"' cy='\"+sy(p.y)+\"' data-idx='\"+p.idx+\"' style='cursor:pointer'/>\"}" ++
    "});" ++
    "scatter.innerHTML=s;" ++
    -- Event: click background to clear
    "var bg=document.getElementById('scatterBg');if(bg)bg.addEventListener('click',function(e){if(e.target===bg){for(var i=0;i<n;i++)pointState[i].selected=false;draw();sendState()}});" ++
    -- Event: click point to toggle
    "scatter.querySelectorAll('[data-idx]').forEach(function(el){el.addEventListener('click',function(e){e.stopPropagation();var idx=parseInt(el.dataset.idx);if(e.shiftKey){pointState[idx].selected=!pointState[idx].selected}else{for(var i=0;i<n;i++)pointState[i].selected=false;pointState[idx].selected=true}draw();sendState()})});" ++
  "}"

private def explorerJs3 : String :=
  "function drawHisto(){" ++
    "var hM={t:15,r:10,b:30,l:35};var hpw=HW-hM.l-hM.r,hph=HH-hM.t-hM.b;" ++
    "var s='';" ++
    "if(groups){" ++
      -- Group histogram
      "var gNames=[];groups.forEach(function(g){if(gNames.indexOf(g)<0)gNames.push(g)});" ++
      "var gColors=['steelblue','#e67e22','#27ae60','#8e44ad','#e74c3c','#16a085'];" ++
      "var barH=Math.min(40,hph/gNames.length-4);" ++
      "var counts=gNames.map(function(g){var c=0;for(var i=0;i<n;i++)if(groups[i]===g&&!pointState[i].hidden)c++;return c});" ++
      "var maxC=Math.max.apply(null,counts)||1;" ++
      "gNames.forEach(function(g,gi){" ++
        "var y=hM.t+gi*(barH+4);" ++
        "var w=counts[gi]/maxC*hpw;" ++
        "var sel=false;for(var i=0;i<n;i++)if(groups[i]===g&&pointState[i].selected){sel=true;break}" ++
        "var col=gColors[gi%gColors.length];" ++
        "var stroke=sel?'orange':'none';var sw=sel?2:0;" ++
        "s+=\"<rect x='\"+hM.l+\"' y='\"+y+\"' width='\"+w+\"' height='\"+barH+\"' fill='\"+col+\"' opacity='0.7' stroke='\"+stroke+\"' stroke-width='\"+sw+\"' data-grp='\"+g+\"' style='cursor:pointer'/>\";" ++
        "s+=\"<text x='\"+(hM.l-4)+\"' y='\"+(y+barH/2+4)+\"' text-anchor='end' font-size='11'>\"+g+\"</text>\";" ++
        "s+=\"<text x='\"+(hM.l+w+4)+\"' y='\"+(y+barH/2+4)+\"' font-size='10'>\"+counts[gi]+\"</text>\"" ++
      "});" ++
    "}else{" ++
      -- X distribution histogram (10 bins)
      "var vis=[];for(var i=0;i<n;i++)if(!pointState[i].hidden)vis.push(i);" ++
      "var xf=document.getElementById('xform').value;" ++
      "var vals=vis.map(function(i){return tx(rawX[i],xf)}).filter(function(v){return !isNaN(v)&&isFinite(v)});" ++
      "if(vals.length<2){histo.innerHTML='';return}" ++
      "var vMin=Math.min.apply(null,vals),vMax=Math.max.apply(null,vals),vR=vMax-vMin||1;" ++
      "var bins=new Array(10).fill(0);var binIdx=new Array(n).fill(-1);" ++
      "for(var i=0;i<n;i++){if(pointState[i].hidden)continue;var v=tx(rawX[i],xf);if(isNaN(v)||!isFinite(v))continue;var b=Math.min(9,Math.floor((v-vMin)/vR*10));bins[b]++;binIdx[i]=b}" ++
      "var maxB=Math.max.apply(null,bins)||1;" ++
      "var barH=hph/10-2;" ++
      "for(var b=0;b<10;b++){" ++
        "var y=hM.t+b*(barH+2);" ++
        "var w=bins[b]/maxB*hpw;" ++
        "var sel=false;for(var i=0;i<n;i++)if(binIdx[i]===b&&pointState[i].selected){sel=true;break}" ++
        "var stroke=sel?'orange':'none';var sw=sel?2:0;" ++
        "s+=\"<rect x='\"+hM.l+\"' y='\"+y+\"' width='\"+w+\"' height='\"+barH+\"' fill='steelblue' opacity='0.6' stroke='\"+stroke+\"' stroke-width='\"+sw+\"' data-bin='\"+b+\"' style='cursor:pointer'/>\";" ++
        "var lo=vMin+b/10*vR;s+=\"<text x='\"+(hM.l-4)+\"' y='\"+(y+barH/2+4)+\"' text-anchor='end' font-size='9'>\"+lo.toPrecision(2)+\"</text>\"" ++
      "}" ++
    "}" ++
    "histo.innerHTML=s;" ++
    -- Histogram click events
    "histo.querySelectorAll('[data-grp]').forEach(function(el){el.addEventListener('click',function(e){" ++
      "var g=el.dataset.grp;" ++
      "if(!e.shiftKey){for(var i=0;i<n;i++)pointState[i].selected=false}" ++
      "for(var i=0;i<n;i++)if(groups[i]===g)pointState[i].selected=true;" ++
      "draw();sendState()})});" ++
    "histo.querySelectorAll('[data-bin]').forEach(function(el){el.addEventListener('click',function(e){" ++
      "var b=parseInt(el.dataset.bin);" ++
      "var xf=document.getElementById('xform').value;" ++
      "var vMin2=Math.min.apply(null,rawX.map(function(v){return tx(v,xf)}).filter(function(v){return !isNaN(v)&&isFinite(v)}));" ++
      "var vMax2=Math.max.apply(null,rawX.map(function(v){return tx(v,xf)}).filter(function(v){return !isNaN(v)&&isFinite(v)}));" ++
      "var vR2=vMax2-vMin2||1;" ++
      "if(!e.shiftKey){for(var i=0;i<n;i++)pointState[i].selected=false}" ++
      "for(var i=0;i<n;i++){if(pointState[i].hidden)continue;var v=tx(rawX[i],xf);if(isNaN(v)||!isFinite(v))continue;var bi=Math.min(9,Math.floor((v-vMin2)/vR2*10));if(bi===b)pointState[i].selected=true}" ++
      "draw();sendState()})});" ++
  "}"

private def explorerJs4 : String :=
  "function draw(){drawScatter();drawHisto();drawLegend()}" ++
  "function sendState(){" ++
    "var sel=[],exc=[],hid=[];for(var i=0;i<n;i++){if(pointState[i].selected)sel.push(i);if(pointState[i].excluded)exc.push(i);if(pointState[i].hidden)hid.push(i)}" ++
    "if(ws&&ws.readyState===1)ws.send(JSON.stringify({event:'selection_changed',selected:sel,excluded:exc,hidden:hid}))" ++
  "}" ++
  "function drawLegend(){" ++
    "var el=document.getElementById('legend');var h='';" ++
    "fits.forEach(function(spec,idx){var col=colors[idx%colors.length];h+='<div><span style=\"display:inline-block;width:20px;height:3px;background:'+col+';vertical-align:middle;margin-right:6px\"></span>Checkpoint '+(idx+1)+'</div>'});" ++
    "el.innerHTML=h" ++
  "}" ++
  -- WebSocket
  "var ws=null;try{ws=new WebSocket('ws://localhost:9147')}catch(e){}" ++
  "if(ws){ws.onmessage=function(ev){" ++
    "var msg=JSON.parse(ev.data);" ++
    "switch(msg.cmd){" ++
      "case'select':for(var i=0;i<n;i++)pointState[i].selected=false;msg.ids.forEach(function(id){pointState[id].selected=true});break;" ++
      "case'clearSelection':for(var i=0;i<n;i++)pointState[i].selected=false;break;" ++
      "case'excludeSelected':for(var i=0;i<n;i++)if(pointState[i].selected){pointState[i].excluded=true;pointState[i].selected=false}break;" ++
      "case'includeAll':for(var i=0;i<n;i++)pointState[i].excluded=false;break;" ++
      "case'hideExcluded':for(var i=0;i<n;i++)if(pointState[i].excluded)pointState[i].hidden=true;break;" ++
      "case'showAll':for(var i=0;i<n;i++)pointState[i].hidden=false;break;" ++
      "case'invertSelection':for(var i=0;i<n;i++)if(!pointState[i].hidden)pointState[i].selected=!pointState[i].selected;break;" ++
      "case'checkpoint':doCheckpoint();break" ++
    "}" ++
    "draw();sendState()" ++
  "}}" ++
  -- Checkpoint
  "function doCheckpoint(){" ++
    "var xf=document.getElementById('xform').value;var yf=document.getElementById('yform').value;var deg=parseInt(document.getElementById('degree').value);" ++
    "var fp=[];for(var i=0;i<n;i++){if(pointState[i].excluded||pointState[i].hidden)continue;var xt=tx(rawX[i],xf),yt=tx(rawY[i],yf);if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt))fp.push({x:xt,y:yt})}" ++
    "if(fp.length<=deg)return;" ++
    "var coef=polyFit(fp.map(function(p){return p.x}),fp.map(function(p){return p.y}),deg);" ++
    "if(coef){fits.push({coef:coef,deg:deg,xf:xf,yf:yf});draw();" ++
    "if(ws&&ws.readyState===1)ws.send(JSON.stringify({event:'checkpoint',state:{fits:fits.length,deg:deg,xf:xf,yf:yf}}))" ++
    "}" ++
  "}" ++
  -- Button events
  "document.getElementById('xform').addEventListener('change',function(){draw()});" ++
  "document.getElementById('yform').addEventListener('change',function(){draw()});" ++
  "document.getElementById('degree').addEventListener('change',function(){draw()});" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){doCheckpoint()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){fits=[];draw()});" ++
  "document.getElementById('invertBtn').addEventListener('click',function(){for(var i=0;i<n;i++)if(!pointState[i].hidden)pointState[i].selected=!pointState[i].selected;draw();sendState()});" ++
  "document.getElementById('keepBtn').addEventListener('click',function(){" ++
    "var state={event:'keep',pointState:pointState,fits:fits};" ++
    "if(ws&&ws.readyState===1){ws.send(JSON.stringify(state));this.textContent='✓ Kept';var b=this;setTimeout(function(){b.textContent='📌 Keep'},1500)}" ++
    "else{navigator.clipboard.writeText(JSON.stringify(state,null,2)).catch(function(){});this.textContent='📋 Copied';var b=this;setTimeout(function(){b.textContent='📌 Keep'},1500)}" ++
  "});" ++
  "draw();"

/-- Generate a self-contained HTML page with JMP-style scatter+histogram explorer.
    Includes per-point state management and bidirectional WebSocket on port 9147. -/
def explorerPlot (xs ys : Array Float) (groups : Option (Array String) := none)
    (xName : String := "x") (yName : String := "y")
    (groupName : String := "group") (title : String := "")
    (theme : LeanStats.Plot.Theme := LeanStats.Plot.Theme.tufte) : String :=
  let xJson := "[" ++ String.intercalate "," (xs.toList.map toString) ++ "]"
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  let gJson := match groups with
    | some gs => "var groups=[" ++ String.intercalate "," (gs.toList.map fun g => "\"" ++ g ++ "\"") ++ "];"
    | none => "var groups=null;"
  let pageTitle := if title != "" then title else s!"{yName} vs {xName}"
  let _ := groupName  -- used in legend context
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{explorerCss}{theme.toCss}</style></head><body>
<h2>{pageTitle} <button id='keepBtn' style='background:#16a34a;color:#fff;border:none;border-radius:4px;padding:4px 8px;cursor:pointer;font-size:12px;vertical-align:middle'>📌 Keep</button></h2>
<div class='main-grid'>
  <div class='y-ctrl'>
    <div class='y-label'>{yName}</div>
    <select id='yform'><option value='recip'>1/y</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>y²</option><option value='exp'>exp</option></select>
  </div>
  <svg id='scatter' width='500' height='400'></svg>
  <svg id='histo' width='200' height='400'></svg>
  <div class='x-ctrl'>
    <b>{xName}</b>
    <select id='xform'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select>
    degree <select id='degree'><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select>
  </div>
</div>
<div class='toolbar'>
  <button id='fitBtn'>+ Checkpoint</button>
  <button id='clearBtn'>Clear</button>
  <button id='invertBtn'>Invert Selection</button>
</div>
<div id='legend' class='legend'></div>
<script>
var rawX = {xJson};
var rawY = {yJson};
{gJson}
{explorerJs1}
{explorerJs2}
{explorerJs3}
{explorerJs4}
</script></body></html>"

end LeanStats.Plot
