import LeanStats.Descriptive

/-! # LeanStats.Plot.MultiReg — JMP-style multiple regression interactive HTML page

Generates a self-contained HTML page with:
- Tabs: 'Y vs Ŷ' + one per predictor (added variable plots)
- Full model OLS via normal equations in browser JS
- Added variable plots showing partial regression coefficients
- Tukey ladder transforms, polynomial degrees, line picker, Keep button
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def multiRegCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".tabs{display:flex;gap:0;margin:12px 0 0 0;border-bottom:2px solid #e0e0e0}" ++
  ".tab{padding:8px 16px;cursor:pointer;font-size:13px;border:1px solid #e0e0e0;border-bottom:none;border-radius:6px 6px 0 0;background:#f8f8f8;margin-right:2px}" ++
  ".tab.active{background:#fff;border-bottom:2px solid #fff;margin-bottom:-2px;font-weight:bold}" ++
  ".toolbar{margin:12px 0 12px 64px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;font-size:13px}" ++
  ".toolbar select,.toolbar button,.toolbar label{font-size:13px}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer;padding:4px 8px}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  "#clearBtn{padding:4px 8px}" ++
  ".plot-grid{display:grid;grid-template-columns:60px 600px;grid-template-rows:450px auto;gap:0;margin:8px 0}" ++
  ".y-ctrl{grid-column:1;grid-row:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;writing-mode:vertical-rl;transform:rotate(180deg)}" ++
  ".y-label{font-weight:bold;font-size:14px}" ++
  ".y-ctrl select{font-size:11px;writing-mode:horizontal-tb;transform:rotate(180deg)}" ++
  ".x-ctrl{grid-column:2;grid-row:2;text-align:center;font-size:13px;padding:8px 0}" ++
  ".x-ctrl select{font-size:12px}" ++
  "#plot{grid-column:2;grid-row:1;border:1px solid #e0e0e0;border-radius:6px}" ++
  ".stats{font-family:monospace;font-size:13px;margin:12px 0 0 64px;padding:12px;background:#f8f8f8;border-radius:6px;white-space:pre-wrap}"

private def multiRegJs : String :=
  "const W=600,H=450,M={t:15,r:15,b:30,l:45};" ++
  "const pw=W-M.l-M.r,ph=H-M.t-M.b;" ++
  "const svg=document.getElementById('plot');" ++
  "const statsEl=document.getElementById('stats');" ++
  "var activeTab=0;" ++
  -- Transform
  "function tx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'square':return v*v;case'exp':return Math.exp(v);default:return v}}" ++
  -- OLS via normal equations on arbitrary design matrix (2D array X, vector y)
  "function fitOLS(X,y){" ++
    "const n=X.length,p=X[0].length;" ++
    "let XtX=[];for(let i=0;i<p;i++){XtX[i]=[];for(let j=0;j<p;j++){let s=0;for(let k=0;k<n;k++)s+=X[k][i]*X[k][j];XtX[i][j]=s}}" ++
    "let Xty=[];for(let i=0;i<p;i++){let s=0;for(let k=0;k<n;k++)s+=X[k][i]*y[k];Xty[i]=s}" ++
    "let A=XtX.map((r,i)=>[...r,Xty[i]]);" ++
    "const m=A.length;" ++
    "for(let i=0;i<m;i++){let mx=i;for(let j=i+1;j<m;j++)if(Math.abs(A[j][i])>Math.abs(A[mx][i]))mx=j;[A[i],A[mx]]=[A[mx],A[i]];" ++
    "if(Math.abs(A[i][i])<1e-12)continue;" ++
    "for(let j=i+1;j<m;j++){let f=A[j][i]/A[i][i];for(let k=i;k<=m;k++)A[j][k]-=f*A[i][k]}}" ++
    "let coef=new Array(m);" ++
    "for(let i=m-1;i>=0;i--){coef[i]=A[i][m];for(let j=i+1;j<m;j++)coef[i]-=A[i][j]*coef[j];coef[i]/=A[i][i]}" ++
    "return coef}" ++
  -- Residuals: y - X*coef
  "function residuals(X,y,coef){return y.map((yi,i)=>{let yh=0;for(let j=0;j<coef.length;j++)yh+=X[i][j]*coef[j];return yi-yh})}" ++
  -- Predicted values: X*coef
  "function predicted(X,coef){return X.map(row=>{let yh=0;for(let j=0;j<coef.length;j++)yh+=row[j]*coef[j];return yh})}" ++
  -- Build design matrix columns for one predictor at given transform and degree
  "function predCols(vals,tf,deg){" ++
    "let tv=vals.map(v=>tx(v,tf));" ++
    "let cols=[];for(let d=1;d<=deg;d++)cols.push(tv.map(v=>Math.pow(v,d)));" ++
    "return cols}" ++
  -- Build full design matrix from all predictors
  "function buildDesignMatrix(){" ++
    "const n=rawY.length;let X=[];for(let i=0;i<n;i++)X[i]=[1];" ++
    "for(let p=0;p<nPred;p++){" ++
      "let tf=document.getElementById('tf_'+p)?document.getElementById('tf_'+p).value:'linear';" ++
      "let deg=document.getElementById('deg_'+p)?parseInt(document.getElementById('deg_'+p).value):1;" ++
      "let cols=predCols(rawXs[p],tf,deg);" ++
      "cols.forEach(col=>{for(let i=0;i<n;i++)X[i].push(col[i])})" ++
    "}" ++
    "return X}" ++
  -- Build design matrix excluding predictor at index excl
  "function buildDesignMatrixExcl(excl){" ++
    "const n=rawY.length;let X=[];for(let i=0;i<n;i++)X[i]=[1];" ++
    "for(let p=0;p<nPred;p++){" ++
      "if(p===excl)continue;" ++
      "let tf=document.getElementById('tf_'+p)?document.getElementById('tf_'+p).value:'linear';" ++
      "let deg=document.getElementById('deg_'+p)?parseInt(document.getElementById('deg_'+p).value):1;" ++
      "let cols=predCols(rawXs[p],tf,deg);" ++
      "cols.forEach(col=>{for(let i=0;i<n;i++)X[i].push(col[i])})" ++
    "}" ++
    "return X}" ++
  -- Polynomial fit (for calibration on Y vs Yhat tab)
  "function polyFit(x,y,deg){" ++
    "const n=x.length;let X=[];for(let i=0;i<n;i++){let row=[];for(let j=0;j<=deg;j++)row.push(Math.pow(x[i],j));X.push(row)}" ++
    "return fitOLS(X,y)}" ++
  "function polyEval(coef,x){let y=0;for(let i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}" ++
  -- Line width picker
  "var lwOptions=[1,2,3,5];var lwCurrent=2;var seOn=false;" ++
  "var colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2','#4f46e5','#dc2626'];" ++
  "var fits=[];" ++
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
        "s+=`<line x1='${x}' y1='${y+6}' x2='${x+segW}' y2='${y+6}' stroke='${col}' stroke-width='${Math.max(0.5,w*0.6)}' opacity='0.4' stroke-dasharray='3' pointer-events='none'/>`}" ++
    "});" ++
    "pick.innerHTML=s;" ++
    "pick.querySelectorAll('[data-lw]').forEach(function(el){el.addEventListener('click',function(){" ++
      "var clicked=parseFloat(el.dataset.lw);" ++
      "if(clicked===lwCurrent){seOn=!seOn}else{lwCurrent=clicked}" ++
      "drawLwPicker()" ++
    "})})" ++
  "}" ++
  -- Draw Y vs Yhat tab
  "function drawYvYhat(){" ++
    "const yf=document.getElementById('yform').value;" ++
    "let ty=rawY.map(v=>tx(v,yf));" ++
    "let X=buildDesignMatrix();" ++
    "let valid=[];for(let i=0;i<ty.length;i++){let ok=isFinite(ty[i])&&!isNaN(ty[i]);if(ok){for(let j=0;j<X[i].length;j++)if(!isFinite(X[i][j])||isNaN(X[i][j])){ok=false;break}}if(ok)valid.push(i)}" ++
    "if(valid.length<3){svg.innerHTML='<text x=\"300\" y=\"225\" text-anchor=\"middle\">Not enough valid points</text>';return}" ++
    "let Xv=valid.map(i=>X[i]),yv=valid.map(i=>ty[i]);" ++
    "let coef=fitOLS(Xv,yv);" ++
    "let yhat=predicted(Xv,coef);" ++
    "let xMin=Math.min(...yhat),xMax=Math.max(...yhat),yMin=Math.min(...yv),yMax=Math.max(...yv);" ++
    "let xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "xMin-=xR*0.05;xMax+=xR*0.05;yMin-=yR*0.05;yMax+=yR*0.05;" ++
    "xR=xMax-xMin;yR=yMax-yMin;" ++
    "const sx=x=>(x-xMin)/xR*pw+M.l;" ++
    "const sy=y=>H-M.b-(y-yMin)/yR*ph;" ++
    "window._sx=sx;window._sy=sy;window._xMin=xMin;window._xMax=xMax;window._yMin=yMin;window._yMax=yMax;" ++
    "window._plotX=yhat;window._plotY=yv;" ++
    "let s='';" ++
    "s+=`<line x1='${M.l}' y1='${H-M.b}' x2='${M.l+pw}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "s+=`<line x1='${M.l}' y1='${M.t}' x2='${M.l}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "for(let i=0;i<=4;i++){let v=xMin+i/4*xR;s+=`<text x='${sx(v)}' y='${H-M.b+15}' text-anchor='middle' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    "for(let i=0;i<=4;i++){let v=yMin+i/4*yR;s+=`<text x='${M.l-8}' y='${sy(v)+4}' text-anchor='end' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    -- Diagonal reference line
    "let dMin=Math.max(xMin,yMin),dMax=Math.min(xMax,yMax);" ++
    "if(dMax>dMin){s+=`<line x1='${sx(dMin)}' y1='${sy(dMin)}' x2='${sx(dMax)}' y2='${sy(dMax)}' stroke='#999' stroke-dasharray='5' stroke-width='1'/>`}" ++
    -- Points
    "for(let i=0;i<yhat.length;i++){s+=`<circle cx='${sx(yhat[i])}' cy='${sy(yv[i])}' r='4' fill='steelblue' opacity='0.7'/>`}" ++
    -- R² annotation
    "let sst=0,sse=0;let ym=yv.reduce((a,b)=>a+b,0)/yv.length;for(let i=0;i<yv.length;i++){sst+=(yv[i]-ym)**2;sse+=(yv[i]-yhat[i])**2}" ++
    "let r2=1-sse/sst;" ++
    "s+=`<text x='${M.l+10}' y='${M.t+20}' font-size='12' fill='#333'>R² = ${r2.toFixed(4)}, n = ${yv.length}</text>`;" ++
    "svg.innerHTML=s;renderFits()}" ++
  -- Draw Added Variable plot for predictor idx
  "function drawAV(idx){" ++
    "let yf=document.getElementById('yform').value;" ++
    "let ty=rawY.map(v=>tx(v,yf));" ++
    "let tf=document.getElementById('tf_'+idx).value;" ++
    "let deg=parseInt(document.getElementById('deg_'+idx).value);" ++
    -- Build design matrix WITHOUT predictor idx
    "let Xexcl=buildDesignMatrixExcl(idx);" ++
    -- Build columns for predictor idx alone
    "let xjCols=predCols(rawXs[idx],tf,deg);" ++
    -- Valid indices
    "let valid=[];for(let i=0;i<ty.length;i++){let ok=isFinite(ty[i])&&!isNaN(ty[i]);if(ok){for(let j=0;j<Xexcl[i].length;j++)if(!isFinite(Xexcl[i][j])||isNaN(Xexcl[i][j])){ok=false;break}}if(ok&&xjCols.length>0){for(let c=0;c<xjCols.length;c++)if(!isFinite(xjCols[c][i])||isNaN(xjCols[c][i])){ok=false;break}}if(ok)valid.push(i)}" ++
    "if(valid.length<3){svg.innerHTML='<text x=\"300\" y=\"225\" text-anchor=\"middle\">Not enough valid points</text>';return}" ++
    "let Xv=valid.map(i=>Xexcl[i]),yv=valid.map(i=>ty[i]);" ++
    -- Residuals of Y on other predictors
    "let coefY=fitOLS(Xv,yv);" ++
    "let eY=residuals(Xv,yv,coefY);" ++
    -- If degree=0, eX is just the transformed predictor residualized (but degree 0 means flat)
    "let eX;" ++
    "if(deg===0){eX=valid.map(()=>0)}else{" ++
      -- Build Xj column(s) for valid rows
      "let xjVals=[];for(let i=0;i<valid.length;i++){let row=[];for(let c=0;c<xjCols.length;c++)row.push(xjCols[c][valid[i]]);xjVals.push(row)}" ++
      -- Flatten to single vector for residualizing (use first power for display)
      "let xjFlat=valid.map(i=>xjCols[0][i]);" ++
      -- Fit Xj ~ other predictors
      "let coefX=fitOLS(Xv,xjFlat);" ++
      "eX=residuals(Xv,xjFlat,coefX)}" ++
    -- Plot eY vs eX
    "let xMin=Math.min(...eX),xMax=Math.max(...eX),yMin=Math.min(...eY),yMax=Math.max(...eY);" ++
    "let xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "xMin-=xR*0.05;xMax+=xR*0.05;yMin-=yR*0.05;yMax+=yR*0.05;" ++
    "xR=xMax-xMin;yR=yMax-yMin;" ++
    "const sx=x=>(x-xMin)/xR*pw+M.l;" ++
    "const sy=y=>H-M.b-(y-yMin)/yR*ph;" ++
    "window._sx=sx;window._sy=sy;window._xMin=xMin;window._xMax=xMax;window._yMin=yMin;window._yMax=yMax;" ++
    "window._plotX=eX;window._plotY=eY;" ++
    "let s='';" ++
    "s+=`<line x1='${M.l}' y1='${H-M.b}' x2='${M.l+pw}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "s+=`<line x1='${M.l}' y1='${M.t}' x2='${M.l}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "for(let i=0;i<=4;i++){let v=xMin+i/4*xR;s+=`<text x='${sx(v)}' y='${H-M.b+15}' text-anchor='middle' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    "for(let i=0;i<=4;i++){let v=yMin+i/4*yR;s+=`<text x='${M.l-8}' y='${sy(v)+4}' text-anchor='end' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    "for(let i=0;i<eX.length;i++){s+=`<circle cx='${sx(eX[i])}' cy='${sy(eY[i])}' r='4' fill='steelblue' opacity='0.7'/>`}" ++
    -- Fit line through origin (slope = multiple regression coefficient)
    "if(deg>0){" ++
      "let num=0,den=0;for(let i=0;i<eX.length;i++){num+=eX[i]*eY[i];den+=eX[i]*eX[i]}" ++
      "let slope=den>0?num/den:0;" ++
      "s+=`<line x1='${sx(xMin)}' y1='${sy(slope*xMin)}' x2='${sx(xMax)}' y2='${sy(slope*xMax)}' stroke='#999' stroke-dasharray='5' stroke-width='1.5'/>`;" ++
      "s+=`<text x='${M.l+10}' y='${M.t+20}' font-size='12' fill='#333'>slope = ${slope.toFixed(4)} (partial reg coef)</text>`" ++
    "}else{" ++
      "s+=`<line x1='${sx(xMin)}' y1='${sy(0)}' x2='${sx(xMax)}' y2='${sy(0)}' stroke='#999' stroke-dasharray='5' stroke-width='1.5'/>`;" ++
      "s+=`<text x='${M.l+10}' y='${M.t+20}' font-size='12' fill='#333'>degree=0: variable excluded</text>`}" ++
    "svg.innerHTML=s;renderFits()}" ++
  -- Main draw dispatcher
  "function draw(){if(activeTab===0)drawYvYhat();else drawAV(activeTab-1)}" ++
  -- Render stored polynomial fits on current view
  "function renderFits(){" ++
    "const sx=window._sx,sy=window._sy,xMin=window._xMin,xMax=window._xMax;" ++
    "const plotX=window._plotX,plotY=window._plotY;" ++
    "if(!sx||!plotX)return;" ++
    "fits.forEach(function(spec,idx){" ++
      "if(spec.hidden||spec.tab!==activeTab)return;" ++
      "if(plotX.length<spec.deg+1)return;" ++
      "const coef=polyFit(plotX,plotY,spec.deg);" ++
      "let path='';const nPts=100;" ++
      "for(let i=0;i<=nPts;i++){" ++
        "const xi=xMin+i/nPts*(xMax-xMin);" ++
        "const yi=polyEval(coef,xi);" ++
        "path+=(path===''?'M':'L')+sx(xi)+','+sy(yi)" ++
      "}" ++
      "const col=colors[idx%colors.length];" ++
      "svg.innerHTML+=`<path d='${path}' fill='none' stroke='${col}' stroke-width='${spec.lw}'/>`" ++
    "});" ++
    -- Legend
    "let legendHtml='';" ++
    "fits.filter(s=>s.tab===activeTab).forEach(function(spec,i){" ++
      "let idx=fits.indexOf(spec);" ++
      "let col=spec.hidden?'#999':colors[idx%colors.length];" ++
      "let plotX2=window._plotX,plotY2=window._plotY;" ++
      "if(!plotX2||plotX2.length<spec.deg+1)return;" ++
      "let lcoef=polyFit(plotX2,plotY2,spec.deg);" ++
      "let eq='y = ';for(let i=lcoef.length-1;i>=0;i--){let c=lcoef[i];let cs=c>=0&&i<lcoef.length-1?' + '+c.toPrecision(3):c.toPrecision(3);if(i===0)eq+=cs;else if(i===1)eq+=cs+'·x ';else eq+=cs+'·x^'+i+' '}" ++
      "let swH=20,swW=30;" ++
      "let svgSw='<svg width=\"'+swW+'\" height=\"'+swH+'\" style=\"vertical-align:middle;margin-right:6px;cursor:pointer\" data-fidx=\"'+idx+'\">';" ++
      "svgSw+='<line x1=\"2\" y1=\"'+swH/2+'\" x2=\"'+(swW-2)+'\" y2=\"'+swH/2+'\" stroke=\"'+col+'\" stroke-width=\"'+spec.lw+'\"/></svg>';" ++
      "legendHtml+='<div style=\"margin:2px 0\">'+svgSw+'<span style=\"font-family:monospace;font-size:12px\">'+eq+'</span></div>'" ++
    "});" ++
    "statsEl.innerHTML=legendHtml;" ++
    "statsEl.querySelectorAll('[data-fidx]').forEach(function(el){el.addEventListener('click',function(){var idx=parseInt(el.dataset.fidx);fits[idx].hidden=!fits[idx].hidden;draw()})})" ++
  "}" ++
  -- Tab switching
  "function switchTab(t){" ++
    "activeTab=t;" ++
    "document.querySelectorAll('.tab').forEach((el,i)=>{el.classList.toggle('active',i===t)});" ++
    "draw()}" ++
  -- Events
  "drawLwPicker();" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){" ++
    "let deg=parseInt(document.getElementById('fitDeg').value);" ++
    "fits.push({deg:deg,lw:lwCurrent,se:seOn,tab:activeTab});draw();drawLwPicker()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){fits=fits.filter(s=>s.tab!==activeTab);draw();drawLwPicker()});" ++
  "document.getElementById('yform').addEventListener('change',draw);" ++
  -- Per-predictor controls
  "for(let p=0;p<nPred;p++){" ++
    "let tEl=document.getElementById('tf_'+p);if(tEl)tEl.addEventListener('change',draw);" ++
    "let dEl=document.getElementById('deg_'+p);if(dEl)dEl.addEventListener('change',draw)}" ++
  -- Keep button
  "document.getElementById('keepBtn').addEventListener('click',function(){" ++
    "var state={event:'keep',tab:activeTab,yform:document.getElementById('yform').value,fits:fits};" ++
    "if(ws&&ws.readyState===1){ws.send(JSON.stringify(state));document.getElementById('keepBtn').textContent='✓ Kept';setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
    "else{document.getElementById('keepBtn').textContent='📋 Copied';navigator.clipboard.writeText(JSON.stringify(state,null,2)).catch(function(){});setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
  "});" ++
  "var ws=null;try{ws=new WebSocket('ws://localhost:9147')}catch(e){}" ++
  "draw();"

/-- Generate a self-contained HTML page for multiple regression with
    Y vs Ŷ and added variable plots (one per predictor). -/
def multiRegPlot (xs : Array (String × Array Float)) (ys : Array Float)
    (yName : String := "y") (title : String := "") : String :=
  let pageTitle := if title != "" then title else s!"{yName} ~ multiple regression"
  let nPred := xs.size
  -- Serialize predictor arrays as JS
  let predArrays := String.intercalate "," (xs.toList.map fun (_, vals) =>
    "[" ++ String.intercalate "," (vals.toList.map toString) ++ "]")
  let predNames := String.intercalate "," (xs.toList.map fun (name, _) => s!"'{name}'")
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  -- Tabs HTML
  let predTabs := String.join (xs.toList.enum.map fun (i, (name, _)) =>
    s!"<div class='tab' onclick='switchTab({i+1})'>{name}</div>")
  -- Per-predictor hidden controls (transform + degree)
  let predCtrls := String.join (xs.toList.enum.map fun (i, (name, _)) =>
    s!"<span style='margin-left:12px;font-size:12px'><b>{name}</b>: " ++
    s!"<select id='tf_{i}'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select> " ++
    s!"deg <select id='deg_{i}'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select></span>")
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{multiRegCss}</style></head><body>
<h2>{pageTitle} <button id='keepBtn' title='Pin this view' style='background:#16a34a;color:#fff;border:none;border-radius:4px;padding:4px 8px;cursor:pointer;font-size:12px;vertical-align:middle'>📌 Keep</button></h2>
<div class='tabs'><div class='tab active' onclick='switchTab(0)'>Y vs Ŷ</div>{predTabs}</div>
<div class='toolbar'>
  <svg id='lwPicker' width='120' height='24' style='vertical-align:middle;cursor:pointer' title='Line thickness'></svg>
  <button id='fitBtn'>+ Fit</button>
  <button id='clearBtn'>Clear fits</button>
  degree <select id='fitDeg'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select>
</div>
<div class='plot-grid'>
  <div class='y-ctrl'>
    <div class='y-label'>{yName}</div>
    <select id='yform'><option value='recip'>1/y</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>y²</option><option value='exp'>exp</option></select>
  </div>
  <svg id='plot' width='600' height='450'></svg>
  <div class='x-ctrl'>
    {predCtrls}
  </div>
</div>
<div id='stats' class='stats'></div>
<script>
const rawXs = [{predArrays}];
const predNames = [{predNames}];
const rawY = {yJson};
const nPred = {nPred};
const yName = '{yName}';
{multiRegJs}
</script></body></html>"

end LeanStats.Plot
