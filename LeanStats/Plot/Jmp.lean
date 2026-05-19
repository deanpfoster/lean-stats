import LeanStats.Descriptive

/-! # LeanStats.Plot.Jmp — JMP-style interactive scatter with fit controls

Generates a self-contained HTML page with:
- Scatter plot (SVG)
- "Fit" button that overlays a polynomial fit
- Degree dropdown (1–4)
- SE bands toggle (confidence band around the fit)
- X transform selector (linear, log, sqrt, reciprocal, square)
- Y transform selector (same)

All computation (polynomial fitting, transforms, SE bands) happens
in the browser via inline JS. The Lean function just emits the page
with the raw data embedded as JSON arrays. No external dependencies.

This is the "throw up a scatter and explore" workflow from JMP.
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def jmpCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".controls{margin:12px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap}" ++
  ".controls label{font-size:13px}" ++
  ".controls select,.controls button{padding:4px 8px;font-size:13px}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  ".stats{font-family:monospace;font-size:13px;margin-top:12px;padding:12px;background:#f8f8f8;border-radius:6px;white-space:pre-wrap}" ++
  "svg{border:1px solid #e0e0e0;border-radius:6px}"

private def jmpJs : String :=
  "const W=700,H=500,M={t:30,r:30,b:50,l:60};" ++
  "const pw=W-M.l-M.r,ph=H-M.t-M.b;" ++
  "const svg=document.getElementById('plot');" ++
  "const statsEl=document.getElementById('stats');" ++
  -- Transform functions
  "function tx(v,f){switch(f){case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'recip':return v!==0?1/v:NaN;case'square':return v*v;default:return v}}" ++
  -- Draw function
  "function draw(){" ++
    "const xf=document.getElementById('xform').value;" ++
    "const yf=document.getElementById('yform').value;" ++
    "let xd=rawX.map(v=>tx(v,xf)).filter(v=>!isNaN(v)&&isFinite(v));" ++
    "let yd=rawY.map((v,i)=>{let xv=tx(rawX[i],xf);return(!isNaN(xv)&&isFinite(xv))?tx(v,yf):NaN}).filter(v=>!isNaN(v)&&isFinite(v));" ++
    -- Pair them (both must be valid)
    "let pairs=[];for(let i=0;i<rawX.length;i++){let x=tx(rawX[i],xf),y=tx(rawY[i],yf);if(!isNaN(x)&&isFinite(x)&&!isNaN(y)&&isFinite(y))pairs.push([x,y])}" ++
    "if(pairs.length<2){svg.innerHTML='<text x=\"350\" y=\"250\" text-anchor=\"middle\">Not enough valid points after transform</text>';return}" ++
    "xd=pairs.map(p=>p[0]);yd=pairs.map(p=>p[1]);" ++
    "const xMin=Math.min(...xd),xMax=Math.max(...xd),yMin=Math.min(...yd),yMax=Math.max(...yd);" ++
    "const xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "const sx=x=>(x-xMin)/xR*pw+M.l;" ++
    "const sy=y=>H-M.b-(y-yMin)/yR*ph;" ++
    -- Build SVG
    "let s='';" ++
    -- Axes
    "s+=`<line x1='${M.l}' y1='${H-M.b}' x2='${M.l+pw}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "s+=`<line x1='${M.l}' y1='${M.t}' x2='${M.l}' y2='${H-M.b}' stroke='#333'/>`;" ++
    -- Tick labels
    "for(let i=0;i<=4;i++){let v=xMin+i/4*xR;s+=`<text x='${sx(v)}' y='${H-M.b+15}' text-anchor='middle' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    "for(let i=0;i<=4;i++){let v=yMin+i/4*yR;s+=`<text x='${M.l-8}' y='${sy(v)+4}' text-anchor='end' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    -- Axis labels
    "let xl=xf==='linear'?xName:xf+'('+xName+')';" ++
    "let yl=yf==='linear'?yName:yf+'('+yName+')';" ++
    "s+=`<text x='${M.l+pw/2}' y='${H-5}' text-anchor='middle' font-size='13'>${xl}</text>`;" ++
    "s+=`<text x='15' y='${M.t+ph/2}' text-anchor='middle' font-size='13' transform='rotate(-90,15,${M.t+ph/2})'>${yl}</text>`;" ++
    -- Points
    "for(let i=0;i<xd.length;i++){s+=`<circle cx='${sx(xd[i])}' cy='${sy(yd[i])}' r='4' fill='steelblue' opacity='0.7'/>`}" ++
    "svg.innerHTML=s;" ++
    "window._xd=xd;window._yd=yd;window._sx=sx;window._sy=sy;window._xMin=xMin;window._xMax=xMax;" ++
    "statsEl.textContent=`n=${pairs.length}, x∈[${xMin.toPrecision(4)}, ${xMax.toPrecision(4)}], y∈[${yMin.toPrecision(4)}, ${yMax.toPrecision(4)}]`" ++
  "}" ++
  -- Polynomial fit via normal equations
  "function polyFit(x,y,deg){" ++
    "const n=x.length;" ++
    "let X=[];for(let i=0;i<n;i++){let row=[];for(let j=0;j<=deg;j++)row.push(Math.pow(x[i],j));X.push(row)}" ++
    -- X^T X
    "let XtX=[];for(let i=0;i<=deg;i++){XtX[i]=[];for(let j=0;j<=deg;j++){let s=0;for(let k=0;k<n;k++)s+=X[k][i]*X[k][j];XtX[i][j]=s}}" ++
    -- X^T y
    "let Xty=[];for(let i=0;i<=deg;i++){let s=0;for(let k=0;k<n;k++)s+=X[k][i]*y[k];Xty[i]=s}" ++
    -- Solve via Gaussian elimination
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
  -- Fit and draw
  "function doFit(){" ++
    "const deg=parseInt(document.getElementById('degree').value);" ++
    "const showSE=document.getElementById('seToggle').checked;" ++
    "const xd=window._xd,yd=window._yd,sx=window._sx,sy=window._sy;" ++
    "if(!xd||xd.length<deg+1)return;" ++
    "const coef=polyFit(xd,yd,deg);" ++
    -- R²
    "const yMean=yd.reduce((a,b)=>a+b,0)/yd.length;" ++
    "let sst=0,sse=0;" ++
    "for(let i=0;i<xd.length;i++){let yh=polyEval(coef,xd[i]);sse+=(yd[i]-yh)**2;sst+=(yd[i]-yMean)**2}" ++
    "const r2=1-sse/sst;" ++
    "const se=Math.sqrt(sse/(xd.length-deg-1));" ++
    -- Draw fit line
    "const nPts=100;const xMin=window._xMin,xMax=window._xMax;" ++
    "let path='';let bandU='';let bandL='';" ++
    "for(let i=0;i<=nPts;i++){" ++
      "const x=xMin+i/nPts*(xMax-xMin);" ++
      "const y=polyEval(coef,x);" ++
      "const px=sx(x),py=sy(y);" ++
      "path+=(i===0?'M':'L')+px+','+py;" ++
      "if(showSE){" ++
        -- Approximate SE band (simplified: se * sqrt(1 + 1/n + (x-xbar)²/Sxx))
        "const xbar=xd.reduce((a,b)=>a+b,0)/xd.length;" ++
        "const Sxx=xd.reduce((a,v)=>a+(v-xbar)**2,0);" ++
        "const h=1/xd.length+(x-xbar)**2/Sxx;" ++
        "const band=1.96*se*Math.sqrt(1+h);" ++  -- prediction interval
        "bandU+=(i===0?'M':'L')+px+','+sy(y+band);" ++
        "bandL+=(i===0?'M':'L')+px+','+sy(y-band);" ++
      "}" ++
    "}" ++
    -- Append to SVG
    "let extra='';" ++
    "if(showSE&&bandU){extra+=`<path d='${bandU}' fill='none' stroke='rgba(220,50,50,0.3)' stroke-dasharray='4'/><path d='${bandL}' fill='none' stroke='rgba(220,50,50,0.3)' stroke-dasharray='4'/>`}" ++
    "extra+=`<path d='${path}' fill='none' stroke='crimson' stroke-width='2'/>`;" ++
    "svg.innerHTML+=extra;" ++
    -- Stats
    "let eq='y = ';" ++
    "for(let i=coef.length-1;i>=0;i--){let c=coef[i].toPrecision(4);if(i===0)eq+=c;else if(i===1)eq+=c+'·x + ';else eq+=c+'·x^'+i+' + '}" ++
    "statsEl.textContent=`n=${xd.length}  R²=${r2.toPrecision(4)}  se=${se.toPrecision(4)}\\n${eq}`" ++
  "}" ++
  -- Event listeners
  "document.getElementById('xform').addEventListener('change',draw);" ++
  "document.getElementById('yform').addEventListener('change',draw);" ++
  "document.getElementById('fitBtn').addEventListener('click',doFit);" ++
  "document.getElementById('seToggle').addEventListener('change',function(){if(window._xd)doFit()});" ++
  "document.getElementById('degree').addEventListener('change',function(){if(window._xd)doFit()});" ++
  "draw();"

/-- Generate a self-contained HTML page with JMP-style interactive scatter.
    The page includes all data, JS for polynomial fitting, transforms, and SE bands. -/
def jmpScatter (xs ys : Array Float)
    (xName : String := "x") (yName : String := "y")
    (title : String := "") : String :=
  let xJson := "[" ++ String.intercalate "," (xs.toList.map toString) ++ "]"
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  let pageTitle := if title != "" then title else s!"{yName} vs {xName}"
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{jmpCss}</style></head><body>
<h2>{pageTitle}</h2>
<div class='controls'>
  <label>X: <select id='xform'><option value='linear'>linear</option><option value='log'>log</option><option value='sqrt'>√</option><option value='recip'>1/x</option><option value='square'>x²</option></select></label>
  <label>Y: <select id='yform'><option value='linear'>linear</option><option value='log'>log</option><option value='sqrt'>√</option><option value='recip'>1/y</option><option value='square'>y²</option></select></label>
  <label>Degree: <select id='degree'><option value='1'>1 (linear)</option><option value='2'>2 (quadratic)</option><option value='3'>3 (cubic)</option><option value='4'>4 (quartic)</option></select></label>
  <button id='fitBtn'>Fit</button>
  <label><input type='checkbox' id='seToggle'> SE bands</label>
</div>
<svg id='plot' width='700' height='500'></svg>
<div id='stats' class='stats'></div>
<script>
const rawX = {xJson};
const rawY = {yJson};
const xName = '{xName}';
const yName = '{yName}';
{jmpJs}
</script></body></html>"

end LeanStats.Plot
