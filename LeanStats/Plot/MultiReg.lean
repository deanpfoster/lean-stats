import LeanStats.Descriptive

/-! # LeanStats.Plot.MultiReg — Multiple regression interactive HTML page

Generates a self-contained HTML page with ALL plots visible simultaneously:
- Y vs Ŷ + one added-variable plot per predictor, in a horizontal row
- Per-plot X controls, shared Y transform, shared line picker
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def multiRegCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".plots-row{display:flex;gap:8px;align-items:flex-start;margin:12px 0}" ++
  ".plot-panel{display:flex;flex-direction:column;align-items:center}" ++
  ".plot-panel svg{border:1px solid #e0e0e0;border-radius:4px}" ++
  ".plot-panel .x-ctrl{font-size:11px;margin-top:4px}" ++
  ".plot-panel .plot-title{font-size:12px;font-weight:bold;margin-bottom:2px}" ++
  ".y-ctrl{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;writing-mode:vertical-rl;transform:rotate(180deg);margin-right:8px}" ++
  ".y-label{font-weight:bold;font-size:13px}" ++
  ".y-ctrl select{font-size:11px;writing-mode:horizontal-tb;transform:rotate(180deg)}" ++
  ".toolbar{margin:8px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap;font-size:13px}" ++
  ".toolbar select,.toolbar button{font-size:13px}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer;padding:4px 8px}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  "#clearBtn{padding:4px 8px}" ++
  ".stats{font-family:monospace;font-size:12px;margin:8px 0;padding:8px;background:#f8f8f8;border-radius:6px}"

private def multiRegJs : String :=
  "const W=300,H=250,M={t:12,r:10,b:25,l:38};" ++
  "const pw=W-M.l-M.r,ph=H-M.t-M.b;" ++
  -- Transform
  "function tx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'square':return v*v;case'exp':return Math.exp(v);default:return v}}" ++
  -- OLS
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
  "function residuals(X,y,coef){return y.map((yi,i)=>{let yh=0;for(let j=0;j<coef.length;j++)yh+=X[i][j]*coef[j];return yi-yh})}" ++
  "function predicted(X,coef){return X.map(row=>{let yh=0;for(let j=0;j<coef.length;j++)yh+=row[j]*coef[j];return yh})}" ++
  "function predCols(vals,tf,deg){let tv=vals.map(v=>tx(v,tf));let cols=[];for(let d=1;d<=deg;d++)cols.push(tv.map(v=>Math.pow(v,d)));return cols}" ++
  "function buildDesignMatrix(){const n=rawY.length;let X=[];for(let i=0;i<n;i++)X[i]=[1];for(let p=0;p<nPred;p++){let tf=document.getElementById('tf_'+p).value;let deg=parseInt(document.getElementById('deg_'+p).value);let cols=predCols(rawXs[p],tf,deg);cols.forEach(col=>{for(let i=0;i<n;i++)X[i].push(col[i])})}return X}" ++
  "function buildDesignMatrixExcl(excl){const n=rawY.length;let X=[];for(let i=0;i<n;i++)X[i]=[1];for(let p=0;p<nPred;p++){if(p===excl)continue;let tf=document.getElementById('tf_'+p).value;let deg=parseInt(document.getElementById('deg_'+p).value);let cols=predCols(rawXs[p],tf,deg);cols.forEach(col=>{for(let i=0;i<n;i++)X[i].push(col[i])})}return X}" ++
  "function polyFit(x,y,deg){const n=x.length;let X=[];for(let i=0;i<n;i++){let row=[];for(let j=0;j<=deg;j++)row.push(Math.pow(x[i],j));X.push(row)}return fitOLS(X,y)}" ++
  "function polyEval(coef,x){let y=0;for(let i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}" ++
  -- Per-plot state
  "var lwOptions=[1,2,3,5];var lwCurrent=2;var seOn=false;" ++
  "var colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2','#4f46e5','#dc2626'];" ++
  "var fits=[];/* each: {deg,lw,se,plot} */" ++
  "var plotState=[];/* per plot: {sx,sy,xMin,xMax,yMin,yMax,plotX,plotY} */" ++
  "for(let i=0;i<=nPred;i++)plotState.push(null);" ++
  -- Line picker
  "function drawLwPicker(){" ++
    "var pick=document.getElementById('lwPicker');" ++
    "var s='';var segW=25;var nextColor=colors[fits.length%colors.length];" ++
    "lwOptions.forEach(function(w,i){var x=i*30+2;var y=12;var isSelected=(w===lwCurrent);var col=isSelected?nextColor:'#999';var opacity=isSelected?1:0.4;" ++
    "s+=`<rect x='${x-2}' y='${y-10}' width='${segW+4}' height='20' fill='transparent' data-lw='${w}' style='cursor:pointer'/>`;" ++
    "s+=`<line x1='${x}' y1='${y}' x2='${x+segW}' y2='${y}' stroke='${col}' stroke-width='${w}' opacity='${opacity}' pointer-events='none'/>`;" ++
    "if(isSelected&&seOn){s+=`<line x1='${x}' y1='${y-6}' x2='${x+segW}' y2='${y-6}' stroke='${col}' stroke-width='${Math.max(0.5,w*0.6)}' opacity='0.4' stroke-dasharray='3' pointer-events='none'/>`;s+=`<line x1='${x}' y1='${y+6}' x2='${x+segW}' y2='${y+6}' stroke='${col}' stroke-width='${Math.max(0.5,w*0.6)}' opacity='0.4' stroke-dasharray='3' pointer-events='none'/>`}" ++
    "});" ++
    "pick.innerHTML=s;" ++
    "pick.querySelectorAll('[data-lw]').forEach(function(el){el.addEventListener('click',function(){var clicked=parseFloat(el.dataset.lw);if(clicked===lwCurrent){seOn=!seOn}else{lwCurrent=clicked}drawLwPicker()})})" ++
  "}" ++
  -- Draw axes + points helper
  "function drawPlotContent(svgEl,xArr,yArr,plotIdx,annotation){" ++
    "let xMin=Math.min(...xArr),xMax=Math.max(...xArr),yMin=Math.min(...yArr),yMax=Math.max(...yArr);" ++
    "let xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "xMin-=xR*0.05;xMax+=xR*0.05;yMin-=yR*0.05;yMax+=yR*0.05;" ++
    -- Lock Y range: use global Y range across all plots
    "if(document.getElementById('lockY').checked&&plotIdx>0){" ++
      "let allResid=[];for(let p=0;p<=nPred;p++){let ps=plotState[p];if(ps)allResid.push(...ps.plotY)}" ++
      "if(allResid.length>0){let gMin=Math.min(...allResid),gMax=Math.max(...allResid);let gR=gMax-gMin||1;yMin=gMin-gR*0.05;yMax=gMax+gR*0.05}" ++
    "}" ++
    "xR=xMax-xMin;yR=yMax-yMin;" ++
    "const sx=x=>(x-xMin)/xR*pw+M.l;" ++
    "const sy=y=>H-M.b-(y-yMin)/yR*ph;" ++
    "plotState[plotIdx]={sx,sy,xMin,xMax,yMin,yMax,plotX:xArr,plotY:yArr};" ++
    "let s='';" ++
    "s+=`<line x1='${M.l}' y1='${H-M.b}' x2='${M.l+pw}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "s+=`<line x1='${M.l}' y1='${M.t}' x2='${M.l}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "for(let i=0;i<=3;i++){let v=xMin+i/3*xR;s+=`<text x='${sx(v)}' y='${H-M.b+13}' text-anchor='middle' font-size='9'>${v.toPrecision(3)}</text>`}" ++
    "for(let i=0;i<=3;i++){let v=yMin+i/3*yR;s+=`<text x='${M.l-5}' y='${sy(v)+3}' text-anchor='end' font-size='9'>${v.toPrecision(3)}</text>`}" ++
    -- Draw CI band for the regression line (if plotIdx > 0, it's an AV plot)
    "if(plotIdx>0&&xArr.length>2){" ++
      "let n=xArr.length;let xm=xArr.reduce((a,b)=>a+b,0)/n;" ++
      "let Sxx=xArr.reduce((a,v)=>a+(v-xm)**2,0);" ++
      "let num=0,den=0;for(let i=0;i<n;i++){num+=xArr[i]*yArr[i];den+=xArr[i]*xArr[i]}" ++
      "let slope=den>0?num/den:0;" ++
      "let sse=0;for(let i=0;i<n;i++){let r=yArr[i]-slope*xArr[i];sse+=r*r}" ++
      "let se=Math.sqrt(sse/(n-2));" ++
      "let bandU='',bandL='';const nPts=60;" ++
      "for(let i=0;i<=nPts;i++){let xi=xMin+i/nPts*xR;let yi=slope*xi;let h=1/n+(xi-xm)**2/Sxx;let band=1.96*se*Math.sqrt(h);" ++
        "bandU+=(bandU===''?'M':'L')+sx(xi)+','+sy(yi+band);bandL+=(bandL===''?'M':'L')+sx(xi)+','+sy(yi-band)}" ++
      "s+=`<path d='${bandU}' fill='none' stroke='rgba(100,100,100,0.3)' stroke-dasharray='3' stroke-width='1'/>`;" ++
      "s+=`<path d='${bandL}' fill='none' stroke='rgba(100,100,100,0.3)' stroke-dasharray='3' stroke-width='1'/>`;" ++
      -- Regression line
      "s+=`<line x1='${sx(xMin)}' y1='${sy(slope*xMin)}' x2='${sx(xMax)}' y2='${sy(slope*xMax)}' stroke='#666' stroke-width='1.5'/>`" ++
    "}" ++
    "for(let i=0;i<xArr.length;i++){s+=`<circle cx='${sx(xArr[i])}' cy='${sy(yArr[i])}' r='3' fill='steelblue' opacity='0.7'/>`}" ++
    "if(annotation)s+=`<text x='${M.l+4}' y='${M.t+12}' font-size='10' fill='#333'>${annotation}</text>`;" ++
    "svgEl.innerHTML=s;renderFitsForPlot(svgEl,plotIdx)}" ++
  -- Render fits for one plot
  "function renderFitsForPlot(svgEl,plotIdx){" ++
    "let ps=plotState[plotIdx];if(!ps)return;" ++
    "const{sx,sy,xMin,xMax,plotX,plotY}=ps;" ++
    "fits.forEach(function(spec,idx){" ++
      "if(spec.hidden||spec.plot!==plotIdx)return;" ++
      "let coef;" ++
      "if(spec.frozen&&spec.coef){coef=spec.coef}else{if(plotX.length<spec.deg+1)return;coef=polyFit(plotX,plotY,spec.deg)}" ++
      "let path='';const nPts=80;" ++
      "for(let i=0;i<=nPts;i++){const xi=xMin+i/nPts*(xMax-xMin);const yi=polyEval(coef,xi);path+=(path===''?'M':'L')+sx(xi)+','+sy(yi)}" ++
      "const col=colors[idx%colors.length];" ++
      "svgEl.innerHTML+=`<path d='${path}' fill='none' stroke='${col}' stroke-width='${spec.lw}'/>`" ++
    "})}" ++
  -- Main draw
  "function draw(){" ++
    "const yf=document.getElementById('yform').value;" ++
    "let ty=rawY.map(v=>tx(v,yf));" ++
    "let X=buildDesignMatrix();" ++
    "let valid=[];for(let i=0;i<ty.length;i++){let ok=isFinite(ty[i])&&!isNaN(ty[i]);if(ok){for(let j=0;j<X[i].length;j++)if(!isFinite(X[i][j])||isNaN(X[i][j])){ok=false;break}}if(ok)valid.push(i)}" ++
    "if(valid.length<3)return;" ++
    "let Xv=valid.map(i=>X[i]),yv=valid.map(i=>ty[i]);" ++
    "let coef=fitOLS(Xv,yv);" ++
    "let yhat=predicted(Xv,coef);" ++
    -- Y vs Yhat
    "let svg0=document.getElementById('plot_0');" ++
    "let sst=0,sse=0;let ym=yv.reduce((a,b)=>a+b,0)/yv.length;for(let i=0;i<yv.length;i++){sst+=(yv[i]-ym)**2;sse+=(yv[i]-yhat[i])**2}" ++
    "let r2=1-sse/sst;" ++
    "drawPlotContent(svg0,yhat,yv,0,'R²='+r2.toFixed(4)+' n='+yv.length);" ++
    -- Diagonal on plot_0
    "{let ps=plotState[0];if(ps){let dMin=Math.max(ps.xMin,ps.yMin),dMax=Math.min(ps.xMax,ps.yMax);if(dMax>dMin)svg0.innerHTML+=`<line x1='${ps.sx(dMin)}' y1='${ps.sy(dMin)}' x2='${ps.sx(dMax)}' y2='${ps.sy(dMax)}' stroke='#999' stroke-dasharray='4' stroke-width='1'/>`}}" ++
    -- AV plots
    "for(let idx=0;idx<nPred;idx++){" ++
      "let tf=document.getElementById('tf_'+idx).value;" ++
      "let deg=parseInt(document.getElementById('deg_'+idx).value);" ++
      "let Xexcl=buildDesignMatrixExcl(idx);" ++
      "let XvE=valid.map(i=>Xexcl[i]);" ++
      "let coefY=fitOLS(XvE,yv);" ++
      "let eY=residuals(XvE,yv,coefY);" ++
      "let eX;" ++
      "if(deg===0){eX=valid.map(()=>0)}else{" ++
        "let xjCols=predCols(rawXs[idx],tf,deg);" ++
        "let xjFlat=valid.map(i=>xjCols[0][i]);" ++
        "let coefX=fitOLS(XvE,xjFlat);" ++
        "eX=residuals(XvE,xjFlat,coefX)}" ++
      "let svgI=document.getElementById('plot_'+(idx+1));" ++
      "let ann='';" ++
      "if(deg>0){let num=0,den=0;for(let i=0;i<eX.length;i++){num+=eX[i]*eY[i];den+=eX[i]*eX[i]}let slope=den>0?num/den:0;ann='β='+slope.toFixed(4)}" ++
      "else{ann='excluded (deg=0)'}" ++
      "drawPlotContent(svgI,eX,eY,idx+1,ann);" ++
      "if(deg>0){let ps=plotState[idx+1];if(ps){let num=0,den=0;for(let i=0;i<eX.length;i++){num+=eX[i]*eY[i];den+=eX[i]*eX[i]}let slope=den>0?num/den:0;svgI.innerHTML+=`<line x1='${ps.sx(ps.xMin)}' y1='${ps.sy(slope*ps.xMin)}' x2='${ps.sx(ps.xMax)}' y2='${ps.sy(slope*ps.xMax)}' stroke='#999' stroke-dasharray='4' stroke-width='1'/>`}}" ++
    "}" ++
    "renderLegend()}" ++
  -- Legend
  "function renderLegend(){" ++
    "let html='';" ++
    "fits.forEach(function(spec,idx){" ++
      "if(spec.hidden)return;" ++
      "let ps=plotState[spec.plot];if(!ps||ps.plotX.length<spec.deg+1)return;" ++
      "let lcoef=polyFit(ps.plotX,ps.plotY,spec.deg);" ++
      "let pname=spec.plot===0?'Y vs Ŷ':predNames[spec.plot-1];" ++
      "let eq=pname+': y = ';for(let i=lcoef.length-1;i>=0;i--){let c=lcoef[i];let cs=c>=0&&i<lcoef.length-1?' + '+c.toPrecision(3):c.toPrecision(3);if(i===0)eq+=cs;else if(i===1)eq+=cs+'·x ';else eq+=cs+'·x^'+i+' '}" ++
      "let col=colors[idx%colors.length];" ++
      "let swH=16,swW=24;" ++
      "let svgSw='<svg width=\"'+swW+'\" height=\"'+swH+'\" style=\"vertical-align:middle;margin-right:4px;cursor:pointer\" data-fidx=\"'+idx+'\">';" ++
      "svgSw+='<line x1=\"2\" y1=\"'+swH/2+'\" x2=\"'+(swW-2)+'\" y2=\"'+swH/2+'\" stroke=\"'+col+'\" stroke-width=\"'+spec.lw+'\"/></svg>';" ++
      "html+='<div style=\"margin:1px 0\">'+svgSw+'<span style=\"font-size:11px\">'+eq+'</span></div>'" ++
    "});" ++
    "document.getElementById('legend').innerHTML=html;" ++
    "document.getElementById('legend').querySelectorAll('[data-fidx]').forEach(function(el){el.addEventListener('click',function(){var idx=parseInt(el.dataset.fidx);fits[idx].hidden=!fits[idx].hidden;draw()})})" ++
  "}" ++
  -- Events
  "drawLwPicker();" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){" ++
    -- Checkpoint: freeze current regression lines on ALL plots with their current data
    "for(let p=0;p<=nPred;p++){" ++
      "let ps=plotState[p];if(!ps||ps.plotX.length<2)continue;" ++
      "let coef=polyFit(ps.plotX,ps.plotY,1);" ++
      "fits.push({deg:1,lw:lwCurrent,se:seOn,plot:p,frozen:true,coef:coef,xMin:ps.xMin,xMax:ps.xMax})" ++
    "}" ++
    "draw();drawLwPicker()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){let plot=parseInt(document.getElementById('fitPlot').value);fits=fits.filter(s=>s.plot!==plot);draw();drawLwPicker()});" ++
  "document.getElementById('yform').addEventListener('change',draw);" ++
  "document.getElementById('lockY').addEventListener('change',draw);" ++
  "for(let p=0;p<nPred;p++){document.getElementById('tf_'+p).addEventListener('change',draw);document.getElementById('deg_'+p).addEventListener('change',draw)}" ++
  "document.getElementById('keepBtn').addEventListener('click',function(){" ++
    "var state={event:'keep',yform:document.getElementById('yform').value,fits:fits};" ++
    "if(ws&&ws.readyState===1){ws.send(JSON.stringify(state));document.getElementById('keepBtn').textContent='✓ Kept';setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
    "else{document.getElementById('keepBtn').textContent='📋 Copied';navigator.clipboard.writeText(JSON.stringify(state,null,2)).catch(function(){});setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
  "});" ++
  "var ws=null;try{ws=new WebSocket('ws://localhost:9147')}catch(e){}" ++
  "draw();"

/-- Generate a self-contained HTML page for multiple regression with
    all plots visible simultaneously in a horizontal row. -/
def multiRegPlot (xs : Array (String × Array Float)) (ys : Array Float)
    (yName : String := "y") (title : String := "") : String :=
  let pageTitle := if title != "" then title else s!"{yName} ~ multiple regression"
  let nPred := xs.size
  let predArrays := String.intercalate "," (xs.toList.map fun (_, vals) =>
    "[" ++ String.intercalate "," (vals.toList.map toString) ++ "]")
  let predNames := String.intercalate "," (xs.toList.map fun (name, _) => s!"'{name}'")
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  -- Plot panels: plot_0 = Y vs Yhat, plot_1..nPred = AV plots
  let plotPanels := String.join (
    [s!"<div class='plot-panel'><div class='plot-title'>Y vs Ŷ</div><svg id='plot_0' width='300' height='250'></svg><div class='x-ctrl'>cal deg <select id='caldeg'><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option></select></div></div>"] ++
    (xs.toList.enum.map fun (i, (name, _)) =>
      s!"<div class='plot-panel'><div class='plot-title'>{name}</div><svg id='plot_{i+1}' width='300' height='250'></svg><div class='x-ctrl'><select id='tf_{i}'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select> deg <select id='deg_{i}'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select></div></div>"))
  -- Fit plot selector options
  let fitPlotOpts := String.join (
    [s!"<option value='0'>Y vs Ŷ</option>"] ++
    (xs.toList.enum.map fun (i, (name, _)) => s!"<option value='{i+1}'>{name}</option>"))
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{multiRegCss}</style></head><body>
<h2>{pageTitle} <button id='keepBtn' title='Pin this view' style='background:#16a34a;color:#fff;border:none;border-radius:4px;padding:4px 8px;cursor:pointer;font-size:12px;vertical-align:middle'>📌 Keep</button></h2>
<div style='display:flex;align-items:flex-start'>
  <div class='y-ctrl'>
    <div class='y-label'>{yName}</div>
    <select id='yform'><option value='recip'>1/y</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>y²</option><option value='exp'>exp</option></select>
  </div>
  <div class='plots-row'>{plotPanels}</div>
</div>
<div class='toolbar'>
  <svg id='lwPicker' width='120' height='24' style='vertical-align:middle;cursor:pointer' title='Line thickness'></svg>
  plot <select id='fitPlot'>{fitPlotOpts}</select>
  degree <select id='fitDeg'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select>
  <button id='fitBtn'>+ Checkpoint</button>
  <button id='clearBtn'>Clear</button>
  <label title='Lock Y range across all plots'><input type='checkbox' id='lockY'> lock Y</label>
</div>
<div id='legend' class='stats'></div>
<script>
const rawXs=[{predArrays}];
const predNames=[{predNames}];
const rawY={yJson};
const nPred={nPred};
const yName='{yName}';
{multiRegJs}
</script></body></html>"

end LeanStats.Plot
