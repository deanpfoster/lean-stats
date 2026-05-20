import LeanStats.Descriptive

/-! # LeanStats.Plot.Jmp — JMP-style interactive scatter with fit controls

Generates a self-contained HTML page with:
- Scatter plot (SVG)
- Polynomial fit with persistent fit specs
- SVG line thickness picker (click to select, click same to toggle SE)
- Two-row controls layout
- Legend at bottom with clickable swatches

All computation (polynomial fitting, transforms, SE bands) happens
in the browser via inline JS. The Lean function just emits the page
with the raw data embedded as JSON arrays. No external dependencies.
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def jmpCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".controls{margin:12px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap}" ++
  ".controls label{font-size:13px}" ++
  ".controls select,.controls button{padding:4px 8px;font-size:13px}" ++
  ".axis-ctrl{background:#f0f4f8;padding:4px 8px;border-radius:4px;font-size:13px}" ++
  ".toolbar{margin:12px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap;font-size:13px}" ++
  ".toolbar select,.toolbar button,.toolbar label{font-size:13px}" ++
  ".plot-grid{display:grid;grid-template-columns:auto 1fr;grid-template-rows:1fr auto;gap:4px;align-items:center;margin:8px 0}" ++
  ".y-ctrl{grid-column:1;grid-row:1;writing-mode:vertical-lr;transform:rotate(180deg);text-align:center;font-size:12px;padding:4px}" ++
  ".y-ctrl select{writing-mode:horizontal-tb;transform:rotate(180deg);font-size:11px;margin-top:4px}" ++
  ".x-ctrl{grid-column:2;grid-row:2;text-align:center;font-size:12px;padding:4px}" ++
  ".x-ctrl select{font-size:11px}" ++
  "#plot{grid-column:2;grid-row:1}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  ".stats{font-family:monospace;font-size:13px;margin-top:12px;padding:12px;background:#f8f8f8;border-radius:6px;white-space:pre-wrap}" ++
  "svg{border:1px solid #e0e0e0;border-radius:6px}"

private def jmpJs : String :=
  "const W=600,H=450,M={t:20,r:20,b:40,l:50};" ++
  "const pw=W-M.l-M.r,ph=H-M.t-M.b;" ++
  "const svg=document.getElementById('plot');" ++
  "const statsEl=document.getElementById('stats');" ++
  -- Transform functions
  "function tx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'square':return v*v;case'exp':return Math.exp(v);default:return v}}" ++
  "function itx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return Math.exp(v);case'sqrt':return v*v;case'square':return v>=0?Math.sqrt(v):NaN;case'exp':return Math.log(v);default:return v}}" ++
  -- Polynomial fit via normal equations
  "function polyFit(x,y,deg){" ++
    "const n=x.length;" ++
    "let X=[];for(let i=0;i<n;i++){let row=[];for(let j=0;j<=deg;j++)row.push(Math.pow(x[i],j));X.push(row)}" ++
    "let XtX=[];for(let i=0;i<=deg;i++){XtX[i]=[];for(let j=0;j<=deg;j++){let s=0;for(let k=0;k<n;k++)s+=X[k][i]*X[k][j];XtX[i][j]=s}}" ++
    "let Xty=[];for(let i=0;i<=deg;i++){let s=0;for(let k=0;k<n;k++)s+=X[k][i]*y[k];Xty[i]=s}" ++
    "let A=XtX.map((r,i)=>[...r,Xty[i]]);" ++
    "const m=A.length;" ++
    "for(let i=0;i<m;i++){let mx=i;for(let j=i+1;j<m;j++)if(Math.abs(A[j][i])>Math.abs(A[mx][i]))mx=j;[A[i],A[mx]]=[A[mx],A[i]];" ++
    "if(Math.abs(A[i][i])<1e-12)continue;" ++
    "for(let j=i+1;j<m;j++){let f=A[j][i]/A[i][i];for(let k=i;k<=m;k++)A[j][k]-=f*A[i][k]}}" ++
    "let coef=new Array(m);" ++
    "for(let i=m-1;i>=0;i--){coef[i]=A[i][m];for(let j=i+1;j<m;j++)coef[i]-=A[i][j]*coef[j];coef[i]/=A[i][i]}" ++
    "return coef}" ++
  -- Evaluate polynomial
  "function polyEval(coef,x){let y=0;for(let i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}" ++
  -- Line width picker state
  "var lwOptions=[1,2,3,5];var lwCurrent=2;var seOn=false;" ++
  "var colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2','#4f46e5','#dc2626'];" ++
  "var fits=[];" ++
  -- Draw line width picker
  "function drawLwPicker(){" ++
    "var pick=document.getElementById('lwPicker');" ++
    "var s='';var segW=25;var nextColor=colors[fits.length%colors.length];" ++
    "lwOptions.forEach(function(w,i){" ++
      "var x=i*30+2;var y=12;" ++
      "var isSelected=(w===lwCurrent);" ++
      "var col=isSelected?nextColor:'#999';" ++
      "var opacity=isSelected?1:0.4;" ++
      "s+=`<rect x='${x-2}' y='${y-10}' width='${segW+4}' height='20' fill='transparent' data-lw='${w}' style='cursor:pointer'/>`;" ++
      "s+=`<line x1='${x}' y1='${y}' x2='${x+segW}' y2='${y}' stroke='${col}' stroke-width='${w}' opacity='${opacity}' pointer-events='none'/>`;" ++
      "if(isSelected&&seOn){" ++
        "s+=`<line x1='${x}' y1='${y-6}' x2='${x+segW}' y2='${y-6}' stroke='${col}' stroke-width='${Math.max(0.5,w*0.6)}' opacity='0.4' stroke-dasharray='3' pointer-events='none'/>`;" ++
        "s+=`<line x1='${x}' y1='${y+6}' x2='${x+segW}' y2='${y+6}' stroke='${col}' stroke-width='${Math.max(0.5,w*0.6)}' opacity='0.4' stroke-dasharray='3' pointer-events='none'/>`" ++
      "}" ++
    "});" ++
    "pick.innerHTML=s;" ++
    "pick.querySelectorAll('[data-lw]').forEach(function(el){el.addEventListener('click',function(){" ++
      "var clicked=parseFloat(el.dataset.lw);" ++
      "if(clicked===lwCurrent){seOn=!seOn}else{lwCurrent=clicked}" ++
      "drawLwPicker()" ++
    "})})" ++
  "}" ++
  -- Draw function
  "function draw(){" ++
    "const xf=document.getElementById('xform').value;" ++
    "const yf=document.getElementById('yform').value;" ++
    "const orig=document.getElementById('origToggle').checked;" ++
    "let pairs=[];for(let i=0;i<rawX.length;i++){let xt=tx(rawX[i],xf),yt=tx(rawY[i],yf);if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt))pairs.push({rx:rawX[i],ry:rawY[i],tx:xt,ty:yt})}" ++
    "if(pairs.length<2){svg.innerHTML='<text x=\"350\" y=\"250\" text-anchor=\"middle\">Not enough valid points after transform</text>';return}" ++
    "let plotX,plotY,axLabelX,axLabelY;" ++
    "if(orig){plotX=pairs.map(p=>p.rx);plotY=pairs.map(p=>p.ry);axLabelX=xName;axLabelY=yName}" ++
    "else{plotX=pairs.map(p=>p.tx);plotY=pairs.map(p=>p.ty);axLabelX=xf==='linear'?xName:xf+'('+xName+')';axLabelY=yf==='linear'?yName:yf+'('+yName+')'}" ++
    "window._pairs=pairs;window._orig=orig;window._xf=xf;window._yf=yf;" ++
    "let xd=plotX,yd=plotY;" ++
    "const xMin=Math.min(...xd),xMax=Math.max(...xd),yMin=Math.min(...yd),yMax=Math.max(...yd);" ++
    "const xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "const sx=x=>(x-xMin)/xR*pw+M.l;" ++
    "const sy=y=>H-M.b-(y-yMin)/yR*ph;" ++
    "window._sx=sx;window._sy=sy;window._xMin=xMin;window._xMax=xMax;window._yMin=yMin;window._yMax=yMax;" ++
    "let s='';" ++
    "s+=`<line x1='${M.l}' y1='${H-M.b}' x2='${M.l+pw}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "s+=`<line x1='${M.l}' y1='${M.t}' x2='${M.l}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "for(let i=0;i<=4;i++){let v=xMin+i/4*xR;s+=`<text x='${sx(v)}' y='${H-M.b+15}' text-anchor='middle' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    "for(let i=0;i<=4;i++){let v=yMin+i/4*yR;s+=`<text x='${M.l-8}' y='${sy(v)+4}' text-anchor='end' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    "s+=`<text x='${M.l+pw/2}' y='${H-5}' text-anchor='middle' font-size='13'>${axLabelX}</text>`;" ++
    "s+=`<text x='15' y='${M.t+ph/2}' text-anchor='middle' font-size='13' transform='rotate(-90,15,${M.t+ph/2})'>${axLabelY}</text>`;" ++
    "for(let i=0;i<xd.length;i++){s+=`<circle cx='${sx(xd[i])}' cy='${sy(yd[i])}' r='4' fill='steelblue' opacity='0.7'/>`}" ++
    "svg.innerHTML=s;" ++
    "renderFits()" ++
  "}" ++
  -- Render all stored fits
  "function renderFits(){" ++
    "const orig=window._orig,xf=window._xf,yf=window._yf;" ++
    "const sx=window._sx,sy=window._sy,xMin=window._xMin,xMax=window._xMax;" ++
    "if(!sx)return;" ++
    "const curXf=document.getElementById('xform').value;" ++
    "const curYf=document.getElementById('yform').value;" ++
    "fits.forEach(function(spec,idx){" ++
      "if(spec.hidden)return;" ++
      "let pairs=[];for(let i=0;i<rawX.length;i++){let xt=tx(rawX[i],spec.xf),yt=tx(rawY[i],spec.yf);if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt))pairs.push({rx:rawX[i],ry:rawY[i],tx:xt,ty:yt})}" ++
      "if(pairs.length<spec.deg+1)return;" ++
      "const txd=pairs.map(p=>p.tx),tyd=pairs.map(p=>p.ty);" ++
      "const coef=polyFit(txd,tyd,spec.deg);" ++
      "const yMean=tyd.reduce((a,b)=>a+b,0)/tyd.length;" ++
      "let sst=0,sse=0;for(let i=0;i<txd.length;i++){let yh=polyEval(coef,txd[i]);sse+=(tyd[i]-yh)**2;sst+=(tyd[i]-yMean)**2}" ++
      "const se=Math.sqrt(sse/(txd.length-spec.deg-1));" ++
      "let path='';let bandU='';let bandL='';const nPts=100;" ++
      "for(let i=0;i<=nPts;i++){" ++
        "const plotXi=xMin+i/nPts*(xMax-xMin);" ++
        "var txI;" ++
        "if(orig){txI=tx(plotXi,spec.xf)}else{txI=tx(itx(plotXi,curXf),spec.xf)}" ++
        "if(isNaN(txI)||!isFinite(txI))continue;" ++
        "const tyI=polyEval(coef,txI);" ++
        "var plotYi;" ++
        "if(orig){plotYi=itx(tyI,spec.yf)}else{plotYi=tx(itx(tyI,spec.yf),curYf)}" ++
        "if(isNaN(plotYi)||!isFinite(plotYi))continue;" ++
        "path+=(path===''?'M':'L')+sx(plotXi)+','+sy(plotYi);" ++
        "if(spec.se){" ++
          "const xbar=txd.reduce((a,b)=>a+b,0)/txd.length;" ++
          "const Sxx=txd.reduce((a,v)=>a+(v-xbar)**2,0);" ++
          "const h=1/txd.length+(txI-xbar)**2/Sxx;" ++
          "const band=1.96*se*Math.sqrt(1+h);" ++
          "var yU,yL;" ++
          "if(orig){yU=itx(tyI+band,spec.yf);yL=itx(tyI-band,spec.yf)}else{yU=tx(itx(tyI+band,spec.yf),curYf);yL=tx(itx(tyI-band,spec.yf),curYf)}" ++
          "if(!isNaN(yU)&&isFinite(yU)){bandU+=(bandU===''?'M':'L')+sx(plotXi)+','+sy(yU)}" ++
          "if(!isNaN(yL)&&isFinite(yL)){bandL+=(bandL===''?'M':'L')+sx(plotXi)+','+sy(yL)}" ++
        "}" ++
      "}" ++
      "const col=colors[idx%colors.length];" ++
      "if(spec.se&&bandU){svg.innerHTML+=`<path d='${bandU}' fill='none' stroke='${col}' opacity='0.4' stroke-width='${spec.lw}' stroke-dasharray='4'/><path d='${bandL}' fill='none' stroke='${col}' opacity='0.4' stroke-width='${spec.lw}' stroke-dasharray='4'/>`}" ++
      "svg.innerHTML+=`<path d='${path}' fill='none' stroke='${col}' stroke-width='${spec.lw}'/>`" ++
    "});" ++
    -- Legend
    "if(fits.length>0){" ++
      "var legendHtml='';" ++
      "fits.forEach(function(spec,idx){" ++
        "var col=spec.hidden?'#999':colors[idx%colors.length];" ++
        "var fpairs=[];for(var i=0;i<rawX.length;i++){var xt=tx(rawX[i],spec.xf),yt=tx(rawY[i],spec.yf);if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt)){fpairs.push({tx:xt,ty:yt})}}" ++
        "var lcoef=polyFit(fpairs.map(function(p){return p.tx}),fpairs.map(function(p){return p.ty}),spec.deg);" ++
        "var eq='y = ';" ++
        "for(var i=lcoef.length-1;i>=0;i--){var c=lcoef[i];var cs=c>=0&&i<lcoef.length-1?' + '+c.toPrecision(3):c.toPrecision(3);if(i===0)eq+=cs;else if(i===1)eq+=cs+'*x ';else eq+=cs+'*x^'+i+' '}" ++
        "var xl=spec.xf==='linear'?xName:spec.xf+'('+xName+')';" ++
        "var yl=spec.yf==='linear'?yName:spec.yf+'('+yName+')';" ++
        "eq=eq.replace(/y/,'('+yl+')').replace(/x/g,xl);" ++
        "var swH=20;var swW=30;var svgSw='<svg width=\"'+swW+'\" height=\"'+swH+'\" style=\"vertical-align:middle;margin-right:6px;cursor:pointer\" data-fidx=\"'+idx+'\">';" ++
        "svgSw+='<rect x=\"0\" y=\"0\" width=\"'+swW+'\" height=\"'+swH+'\" fill=\"transparent\"/>';" ++
        "svgSw+='<line x1=\"2\" y1=\"'+swH/2+'\" x2=\"'+(swW-2)+'\" y2=\"'+swH/2+'\" stroke=\"'+col+'\" stroke-width=\"'+spec.lw+'\"/>';" ++
        "if(spec.se){" ++
          "svgSw+='<line x1=\"2\" y1=\"'+(swH/2-5)+'\" x2=\"'+(swW-2)+'\" y2=\"'+(swH/2-5)+'\" stroke=\"'+col+'\" stroke-width=\"'+spec.lw+'\" opacity=\"0.4\" stroke-dasharray=\"3\"/>';" ++
          "svgSw+='<line x1=\"2\" y1=\"'+(swH/2+5)+'\" x2=\"'+(swW-2)+'\" y2=\"'+(swH/2+5)+'\" stroke=\"'+col+'\" stroke-width=\"'+spec.lw+'\" opacity=\"0.4\" stroke-dasharray=\"3\"/>'}" ++
        "svgSw+='</svg>';" ++
        "var eqStyle=spec.hidden?'font-family:monospace;font-size:12px;color:#999':'font-family:monospace;font-size:12px';" ++
        "legendHtml+='<div style=\"margin:2px 0\">'+svgSw+'<span style=\"'+eqStyle+'\">'+eq+'</span></div>'" ++
      "});" ++
      "statsEl.innerHTML=legendHtml;" ++
      "statsEl.querySelectorAll('[data-fidx]').forEach(function(el){el.addEventListener('click',function(){var idx=parseInt(el.dataset.fidx);fits[idx].hidden=!fits[idx].hidden;draw()})})" ++
    "}else{statsEl.innerHTML=''}" ++
  "}" ++
  -- Event listeners
  "drawLwPicker();" ++
  "document.getElementById('xform').addEventListener('change',function(){draw()});" ++
  "document.getElementById('yform').addEventListener('change',function(){draw()});" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){var xf=document.getElementById('xform').value;var yf=document.getElementById('yform').value;var deg=parseInt(document.getElementById('degree').value);fits.push({deg:deg,xf:xf,yf:yf,se:seOn,lw:lwCurrent});draw();drawLwPicker()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){fits=[];draw();drawLwPicker()});" ++
  "document.getElementById('origToggle').addEventListener('change',function(){draw()});" ++
  -- Keep button
  "document.getElementById('keepBtn').addEventListener('click',function(){" ++
    "var state={event:'keep',xform:document.getElementById('xform').value," ++
    "yform:document.getElementById('yform').value," ++
    "original:document.getElementById('origToggle').checked," ++
    "fits:fits.filter(function(s){return !s.hidden})};" ++
    "if(ws&&ws.readyState===1){ws.send(JSON.stringify(state));document.getElementById('keepBtn').textContent='✓ Kept';setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
    "else{document.getElementById('keepBtn').textContent='📋 Copied';navigator.clipboard.writeText(JSON.stringify(state,null,2)).catch(function(){});setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
  "});" ++
  -- WebSocket
  "var ws=null;try{ws=new WebSocket('ws://localhost:9147')}catch(e){}" ++
  "function report(){" ++
    "if(!ws||ws.readyState!==1)return;" ++
    "var msg={event:'view_change',xform:document.getElementById('xform').value,yform:document.getElementById('yform').value,fits:fits.length};" ++
    "ws.send(JSON.stringify(msg))" ++
  "}" ++
  "draw();"

/-- A user interaction event from the JMP scatter page. -/
structure JmpEvent where
  xform : String
  yform : String
  degree : Nat
  seBands : Bool
  n : Nat
  xRange : Float × Float
  yRange : Float × Float
  pearsonR : Float
  curvature : Float
  r2 : Option Float := none
  equation : Option (Array Float) := none
  deriving Repr

/-- Generate the LLM summary string from a user interaction event. -/
def summarizeJmpEvent (ev : JmpEvent) (xName yName : String) : String :=
  let xLabel := if ev.xform == "linear" then xName else s!"{ev.xform}({xName})"
  let yLabel := if ev.yform == "linear" then yName else s!"{ev.yform}({yName})"
  let header := s!"User applied: x={xLabel}, y={yLabel}"
  let stats := s!"n: {ev.n}, x ∈ [{ev.xRange.1}, {ev.xRange.2}], y ∈ [{ev.yRange.1}, {ev.yRange.2}]"
  let corr := s!"pearson_r: {ev.pearsonR}"
  let interp := if ev.pearsonR.abs > 0.95 then "near-perfect linear"
    else if ev.pearsonR.abs > 0.8 then "strong linear"
    else if ev.pearsonR.abs > 0.5 then "moderate linear"
    else if ev.pearsonR.abs > 0.2 then "weak linear"
    else "no linear relationship"
  let curvNote := if ev.curvature.abs > 0.1 then s!", curvature: {ev.curvature} (nonlinear)"
    else if ev.curvature.abs > 0.01 then s!", curvature @ {ev.curvature}σ (borderline)"
    else ""
  let fitNote := match ev.r2, ev.equation with
    | some r2, some coef =>
      let eqStr := formatPoly coef xLabel
      s!"\nfit (degree {ev.degree}): {eqStr}, R² = {r2}"
    | some r2, none => s!"\nfit: R² = {r2}"
    | _, _ => ""
  let shape := s!"shape: {interp}{curvNote}"
  s!"{header}\n{stats}\n{corr}\n{shape}{fitNote}"
where
  formatPoly (coef : Array Float) (xVar : String) : String :=
    let terms := (List.range coef.size).reverse.filterMap fun i =>
      let c := coef.getD i 0
      if c.abs < 1e-10 && i > 0 then none
      else if i == 0 then some (toString c)
      else if i == 1 then some s!"{c}·{xVar}"
      else some s!"{c}·{xVar}^{i}"
    String.intercalate " + " terms

/-- Generate a self-contained HTML page with JMP-style interactive scatter.
    The page includes all data, JS for polynomial fitting, transforms, and SE bands.
    If l3m runs a WebSocket server on port 9147, the page reports user actions back. -/
def jmpScatter (xs ys : Array Float)
    (xName : String := "x") (yName : String := "y")
    (title : String := "") : String :=
  let xJson := "[" ++ String.intercalate "," (xs.toList.map toString) ++ "]"
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  let pageTitle := if title != "" then title else s!"{yName} vs {xName}"
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{jmpCss}</style></head><body>
<h2>{pageTitle}</h2>
<div class='toolbar'>
  <svg id='lwPicker' width='120' height='24' style='vertical-align:middle;cursor:pointer' title='Line thickness — click to select, click same to toggle SE bands'></svg>
  <button id='fitBtn' title='Add a fit with current settings'>+ Fit</button>
  <button id='clearBtn' title='Remove all fits from the plot'>Clear fits</button>
  <button id='keepBtn' title='Pin this view to your analysis document' style='background:#16a34a;color:#fff;border:none;border-radius:4px;padding:4px 8px;cursor:pointer'>📌 Keep</button>
  <label title='Show original axes'><input type='checkbox' id='origToggle'> Original</label>
</div>
<div class='plot-grid'>
  <div class='y-ctrl' title='Y axis transform'><b>{yName}</b><br><select id='yform'><option value='recip'>1/y</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>y²</option><option value='exp'>exp</option></select></div>
  <svg id='plot' width='600' height='450'></svg>
  <div class='x-ctrl' title='X axis: transform and polynomial degree'><b>{xName}</b> <select id='xform'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select> degree <select id='degree'><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option></select></div>
</div>
<div id='stats' class='stats'></div>
<script>
const rawX = {xJson};
const rawY = {yJson};
const xName = '{xName}';
const yName = '{yName}';
{jmpJs}
</script></body></html>"

end LeanStats.Plot
