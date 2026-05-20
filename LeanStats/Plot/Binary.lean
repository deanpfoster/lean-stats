import LeanStats.Descriptive

/-! # LeanStats.Plot.Binary — interactive binary response plot

The JMP plot that should have been: binary Y with proper link functions,
X transforms, fringe display, empirical proportions, and SE bands.

Features:
- Top/bottom fringe marks showing where 1s and 0s fall along X
- Fitted probability curve (logistic, probit, cloglog, or linear)
- Empirical proportions (binned) as reference dots
- SE bands around the fitted curve
- X transform dropdown (Tukey ladder: 1/x, log, √, linear, x², exp)
- Link function dropdown (logit, probit, cloglog, identity)
- All computation in browser JS (MLE via IRLS for logistic/probit)
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def binaryCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".controls{margin:12px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap}" ++
  ".controls label{font-size:13px}" ++
  ".controls select,.controls button,.controls input{padding:4px 8px;font-size:13px}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  ".stats{font-family:monospace;font-size:13px;margin-top:12px;padding:12px;background:#f8f8f8;border-radius:6px;white-space:pre-wrap}" ++
  "svg{border:1px solid #e0e0e0;border-radius:6px}"

private def binaryJs : String :=
  "const W=700,H=500,M={t:40,r:30,b:50,l:60};" ++
  "const pw=W-M.l-M.r,ph=H-M.t-M.b;" ++
  "const svg=document.getElementById('plot');" ++
  "const statsEl=document.getElementById('stats');" ++
  -- Transform functions
  "function tx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'square':return v*v;case'exp':return Math.exp(v);default:return v}}" ++
  -- Link functions and inverses
  "function linkFn(p,link){switch(link){case'logit':return Math.log(p/(1-p));case'probit':return probitInv(p);case'cloglog':return Math.log(-Math.log(1-p));default:return p}}" ++
  "function invLink(eta,link){switch(link){case'logit':return 1/(1+Math.exp(-eta));case'probit':return probitCdf(eta);case'cloglog':return 1-Math.exp(-Math.exp(eta));default:return Math.max(0,Math.min(1,eta))}}" ++
  -- Probit (normal CDF approximation)
  "function probitCdf(z){const a1=0.254829592,a2=-0.284496736,a3=1.421413741,a4=-1.453152027,a5=1.061405429,p=0.3275911;const s=z<0?-1:1;const t=1/(1+p*Math.abs(z));const y=1-((((a5*t+a4)*t+a3)*t+a2)*t+a1)*t*Math.exp(-z*z/2);return 0.5*(1+s*y)}" ++
  "function probitInv(p){if(p<=0)return -5;if(p>=1)return 5;const a=[0,-3.969683028665376e1,2.209460984245205e2,-2.759285104469687e2,1.383577518672690e2,-3.066479806614716e1,2.506628277459239e0];const b=[0,-5.447609879822406e1,1.615858368580409e2,-1.556989798598866e2,6.680131188771972e1,-1.328068155288572e1];const c=[0,-7.784894002430293e-3,-3.223964580411365e-1,-2.400758277161838e0,-2.549732539343734e0,4.374664141464968e0,2.938163982698783e0];const d=[0,7.784695709041462e-3,3.224671290700398e-1,2.445134137142996e0,3.754408661907416e0];const pLow=0.02425,pHigh=1-pLow;let q,r;if(p<pLow){q=Math.sqrt(-2*Math.log(p));return(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6])/((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)}if(p<=pHigh){q=p-0.5;r=q*q;return(((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6])*q/(((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1)}q=Math.sqrt(-2*Math.log(1-p));return-(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6])/((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)}" ++
  -- IRLS for GLM fitting (returns [intercept, slope])
  "function fitGlm(x,y,link){" ++
    "const n=x.length;let b0=0,b1=0;" ++
    "for(let iter=0;iter<25;iter++){" ++
      "let XtWX00=0,XtWX01=0,XtWX11=0,XtWz0=0,XtWz1=0;" ++
      "for(let i=0;i<n;i++){" ++
        "const eta=b0+b1*x[i];" ++
        "const mu=invLink(eta,link);" ++
        "const muC=Math.max(1e-8,Math.min(1-1e-8,mu));" ++
        -- Variance and derivative depend on link
        "let w,z;" ++
        "if(link==='logit'){w=muC*(1-muC);z=eta+(y[i]-muC)/w}" ++
        "else if(link==='probit'){const phi=Math.exp(-eta*eta/2)/Math.sqrt(2*Math.PI);w=phi*phi/(muC*(1-muC));z=eta+(y[i]-muC)/phi}" ++
        "else if(link==='cloglog'){const h=Math.exp(eta);const dmu=(1-muC)*h;w=dmu*dmu/(muC*(1-muC));z=eta+(y[i]-muC)/dmu}" ++
        "else{w=1;z=y[i]}" ++
        "XtWX00+=w;XtWX01+=w*x[i];XtWX11+=w*x[i]*x[i];" ++
        "XtWz0+=w*z;XtWz1+=w*z*x[i]" ++
      "}" ++
      "const det=XtWX00*XtWX11-XtWX01*XtWX01;" ++
      "if(Math.abs(det)<1e-12)break;" ++
      "const nb0=(XtWX11*XtWz0-XtWX01*XtWz1)/det;" ++
      "const nb1=(XtWX00*XtWz1-XtWX01*XtWz0)/det;" ++
      "if(Math.abs(nb0-b0)+Math.abs(nb1-b1)<1e-8){b0=nb0;b1=nb1;break}" ++
      "b0=nb0;b1=nb1" ++
    "}" ++
    "return[b0,b1]}" ++
  -- Pool Adjacent Violators (isotonic regression)
  "function pav(y){" ++
    "var n=y.length;var val=y.slice();var cnt=new Array(n).fill(1);" ++
    "var len=n;" ++
    -- Forward pass: merge violations
    "var j=0;" ++
    "for(var i=1;i<n;i++){" ++
      "val[j+1]=y[i];cnt[j+1]=1;" ++
      "j++;" ++
      "while(j>0&&val[j]<val[j-1]){" ++
        "val[j-1]=(val[j-1]*cnt[j-1]+val[j]*cnt[j])/(cnt[j-1]+cnt[j]);" ++
        "cnt[j-1]+=cnt[j];" ++
        "j--" ++
      "}" ++
    "}" ++
    -- Expand blocks back to original length
    "var result=[];for(var k=0;k<=j;k++){for(var m=0;m<cnt[k];m++)result.push(val[k])}" ++
    "return result}" ++
  -- Draw
  "function draw(){" ++
    "const xf=document.getElementById('xform').value;" ++
    "const orig=document.getElementById('origToggle').checked;" ++
    "let pairs=[];for(let i=0;i<rawX.length;i++){let xt=tx(rawX[i],xf);if(!isNaN(xt)&&isFinite(xt))pairs.push({x:xt,y:rawY[i],rx:rawX[i]})}" ++
    "if(pairs.length<4){svg.innerHTML='<text x=\"350\" y=\"250\" text-anchor=\"middle\">Not enough valid points</text>';return}" ++
    "pairs.sort((a,b)=>a.x-b.x);" ++
    "const xd=pairs.map(p=>p.x);" ++
    "const plotX=orig?pairs.map(p=>p.rx):xd;" ++
    "const xMin=Math.min(...plotX),xMax=Math.max(...plotX);" ++
    "const xR=xMax-xMin||1;" ++
    "const sx=x=>(x-xMin)/xR*pw+M.l;" ++
    "const sy=p=>M.t+ph*(1-p);" ++
    "window._pairs=pairs;window._sx=sx;window._sy=sy;window._xMin=xMin;window._xMax=xMax;window._orig=orig;window._xf=xf;" ++
    "let s='';" ++
    -- Axes
    "s+=`<line x1='${M.l}' y1='${H-M.b}' x2='${M.l+pw}' y2='${H-M.b}' stroke='#333'/>`;" ++
    "s+=`<line x1='${M.l}' y1='${M.t}' x2='${M.l}' y2='${H-M.b}' stroke='#333'/>`;" ++
    -- X ticks
    "for(let i=0;i<=4;i++){let v=xMin+i/4*xR;s+=`<text x='${sx(v)}' y='${H-M.b+15}' text-anchor='middle' font-size='11'>${v.toPrecision(3)}</text>`}" ++
    -- Y ticks (probability 0 to 1)
    "for(let i=0;i<=4;i++){let v=i/4;s+=`<text x='${M.l-8}' y='${sy(v)+4}' text-anchor='end' font-size='11'>${v.toFixed(2)}</text>`}" ++
    -- Axis labels
    "let xl=orig?xName:(xf==='linear'?xName:xf+'('+xName+')');" ++
    "s+=`<text x='${M.l+pw/2}' y='${H-5}' text-anchor='middle' font-size='13'>${xl}</text>`;" ++
    "s+=`<text x='15' y='${M.t+ph/2}' text-anchor='middle' font-size='13' transform='rotate(-90,15,${M.t+ph/2})'>P(${yName}=1)</text>`;" ++
    -- Fringe marks: top for Y=1, bottom for Y=0
    "pairs.forEach(function(p){" ++
      "const px=sx(orig?p.rx:p.x);" ++
      "if(p.y===1){s+=`<line x1='${px}' y1='${M.t}' x2='${px}' y2='${M.t+12}' stroke='#2563eb' opacity='0.6'/>`}" ++
      "else{s+=`<line x1='${px}' y1='${H-M.b}' x2='${px}' y2='${H-M.b-12}' stroke='#dc2626' opacity='0.6'/>`}" ++
    "});" ++
    -- Empirical proportions (binned)
    "if(document.getElementById('empirical').checked){" ++
      "const nbins=parseInt(document.getElementById('nbins').value)||10;" ++
      "const binW=xR/nbins;" ++
      "for(let b=0;b<nbins;b++){" ++
        "const lo=xMin+b*binW,hi=lo+binW;" ++
        "const inBin=pairs.filter(p=>{const px=orig?p.rx:p.x;return px>=lo&&(b===nbins-1?px<=hi:px<hi)});" ++
        "if(inBin.length>=1){" ++
          "const prop=inBin.filter(p=>p.y===1).length/inBin.length;" ++
          "const cx=sx((lo+hi)/2),cy=sy(prop);" ++
          "const r=Math.min(8,Math.max(3,Math.sqrt(inBin.length)*2));" ++
          "s+=`<circle cx='${cx}' cy='${cy}' r='${r}' fill='none' stroke='#666' stroke-width='1.5'/>`" ++
        "}" ++
      "}" ++
    "}" ++
    "svg.innerHTML=s;" ++
    -- PAV isotonic regression (drawn after svg.innerHTML set, as overlay)
    "if(document.getElementById('pav').checked){" ++
      "const pavY=pav(pairs.map(p=>p.y));" ++
      "let pavPath='';" ++
      "for(let i=0;i<pairs.length;i++){" ++
        "const px=sx(orig?pairs[i].rx:pairs[i].x);" ++
        "const py=sy(pavY[i]);" ++
        "pavPath+=(pavPath===''?'M':'L')+px+','+py" ++
      "}" ++
      "svg.innerHTML+=`<path d='${pavPath}' fill='none' stroke='#16a34a' stroke-width='2' opacity='0.8'/>`" ++
    "}" ++
    "statsEl.textContent=`n=${pairs.length} (${pairs.filter(p=>p.y===1).length} events, ${pairs.filter(p=>p.y===0).length} non-events)`" ++
  "}" ++
  -- Fit
  "function doFit(){" ++
    "const link=document.getElementById('link').value;" ++
    "const showSE=document.getElementById('seToggle').checked;" ++
    "const pairs=window._pairs,sx=window._sx,sy=window._sy;" ++
    "if(!pairs||pairs.length<4)return;" ++
    "const xd=pairs.map(p=>p.x),yd=pairs.map(p=>p.y);" ++
    "const coef=fitGlm(xd,yd,link);" ++
    "const b0=coef[0],b1=coef[1];" ++
    -- Draw fitted curve
    "const nPts=100,xMin=window._xMin,xMax=window._xMax;" ++
    "const orig=window._orig,xf=window._xf;" ++
    "let path='';let bandU='';let bandL='';" ++
    "for(let i=0;i<=nPts;i++){" ++
      "const plotXi=xMin+i/nPts*(xMax-xMin);" ++
      "const txI=orig?tx(plotXi,xf):plotXi;" ++
      "if(isNaN(txI)||!isFinite(txI))continue;" ++
      "const eta=b0+b1*txI;" ++
      "const p=invLink(eta,link);" ++
      "const px=sx(plotXi),py=sy(p);" ++
      "path+=(path===''?'M':'L')+px+','+py;" ++
      "if(showSE){" ++
        -- Approximate SE of eta: sqrt(var(b0) + x²*var(b1) + 2x*cov)
        -- Simplified: use 1/sqrt(n*p*(1-p)) as rough SE
        "const pC=Math.max(0.01,Math.min(0.99,p));" ++
        "const seEta=1.96/Math.sqrt(pairs.length*pC*(1-pC));" ++
        "const pU=invLink(eta+seEta,link),pL=invLink(eta-seEta,link);" ++
        "bandU+=(bandU===''?'M':'L')+px+','+sy(pU);" ++
        "bandL+=(bandL===''?'M':'L')+px+','+sy(pL)" ++
      "}" ++
    "}" ++
    "let extra='';" ++
    "if(showSE&&bandU){extra+=`<path d='${bandU}' fill='none' stroke='rgba(220,50,50,0.3)' stroke-dasharray='4'/><path d='${bandL}' fill='none' stroke='rgba(220,50,50,0.3)' stroke-dasharray='4'/>`}" ++
    "extra+=`<path d='${path}' fill='none' stroke='crimson' stroke-width='2.5'/>`;" ++
    "svg.innerHTML+=extra;" ++
    -- Stats
    "const xbar=xd.reduce((a,b)=>a+b,0)/xd.length;" ++
    "const p50=invLink(b0+b1*xbar,link);" ++
    "statsEl.textContent=`link: ${link}, coef: [${b0.toPrecision(4)}, ${b1.toPrecision(4)}]\\nP(${yName}=1 | ${xName}=mean) = ${p50.toPrecision(3)}`" ++
  "}" ++
  -- Events
  "var fitSpecs=[];" ++
  "document.getElementById('xform').addEventListener('change',function(){fitSpecs=[];draw()});" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){var link=document.getElementById('link').value;var se=document.getElementById('seToggle').checked;fitSpecs.push({link:link,se:se});draw();renderBinaryFits()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){fitSpecs=[];draw()});" ++
  "document.getElementById('seToggle').addEventListener('change',function(){});" ++
  "document.getElementById('empirical').addEventListener('change',draw);" ++
  "document.getElementById('nbins').addEventListener('change',draw);" ++
  "document.getElementById('link').addEventListener('change',function(){});" ++
  "document.getElementById('pav').addEventListener('change',draw);" ++
  "document.getElementById('origToggle').addEventListener('change',function(){draw();renderBinaryFits()});" ++
  -- Render all stored fits
  "function renderBinaryFits(){" ++
    "const pairs=window._pairs,sx=window._sx,sy=window._sy;" ++
    "const orig=window._orig,xf=window._xf;" ++
    "const xMin=window._xMin,xMax=window._xMax;" ++
    "if(!pairs)return;" ++
    "const colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2'];" ++
    "const xd=pairs.map(p=>p.x),yd=pairs.map(p=>p.y);" ++
    "fitSpecs.forEach(function(spec,idx){" ++
      "const coef=fitGlm(xd,yd,spec.link);" ++
      "const b0=coef[0],b1=coef[1];" ++
      "let path='';let bandU='';let bandL='';" ++
      "for(let i=0;i<=100;i++){" ++
        "const plotXi=xMin+i/100*(xMax-xMin);" ++
        "const txI=orig?tx(plotXi,xf):plotXi;" ++
        "if(isNaN(txI)||!isFinite(txI))continue;" ++
        "const eta=b0+b1*txI;" ++
        "const p=invLink(eta,spec.link);" ++
        "const px=sx(plotXi),py=sy(p);" ++
        "path+=(path===''?'M':'L')+px+','+py;" ++
        "if(spec.se){const pC=Math.max(0.01,Math.min(0.99,p));const seEta=1.96/Math.sqrt(pairs.length*pC*(1-pC));bandU+=(bandU===''?'M':'L')+px+','+sy(invLink(eta+seEta,spec.link));bandL+=(bandL===''?'M':'L')+px+','+sy(invLink(eta-seEta,spec.link))}" ++
      "}" ++
      "const col=colors[idx%colors.length];" ++
      "if(spec.se&&bandU){svg.innerHTML+=`<path d='${bandU}' fill='none' stroke='${col}' opacity='0.3' stroke-dasharray='4'/><path d='${bandL}' fill='none' stroke='${col}' opacity='0.3' stroke-dasharray='4'/>`}" ++
      "svg.innerHTML+=`<path d='${path}' fill='none' stroke='${col}' stroke-width='2.5'/>`" ++
    "});" ++
    "if(fitSpecs.length>0){const last=fitSpecs[fitSpecs.length-1];statsEl.textContent+=`\\n${fitSpecs.length} fit(s). Last: ${last.link}`}" ++
  "}" ++
  "draw();"

/-- Generate a self-contained HTML page for binary response analysis.
    xs: continuous predictor, ys: binary response (0.0 or 1.0). -/
def binaryPlot (xs ys : Array Float)
    (xName : String := "x") (yName : String := "y")
    (title : String := "") : String :=
  let xJson := "[" ++ String.intercalate "," (xs.toList.map toString) ++ "]"
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  let pageTitle := if title != "" then title else s!"P({yName}=1) vs {xName}"
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{binaryCss}</style></head><body>
<h2>{pageTitle}</h2>
<div class='controls'>
  <label>X: <select id='xform'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select></label>
  <label>Link: <select id='link'><option value='logit' selected>logit</option><option value='probit'>probit</option><option value='cloglog'>cloglog</option><option value='identity'>identity</option></select></label>
  <button id='fitBtn'>+ Fit</button>
  <button id='clearBtn'>Clear fits</button>
  <label><input type='checkbox' id='seToggle'> SE bands</label>
  <label><input type='checkbox' id='empirical' checked> Empirical</label>
  <label>Bins: <input type='number' id='nbins' value='10' min='3' max='50' style='width:50px'></label>
  <label><input type='checkbox' id='pav'> PAV</label>
  <label><input type='checkbox' id='origToggle'> Original</label>
</div>
<svg id='plot' width='700' height='500'></svg>
<div id='stats' class='stats'></div>
<script>
const rawX = {xJson};
const rawY = {yJson};
const xName = '{xName}';
const yName = '{yName}';
{binaryJs}
</script></body></html>"

end LeanStats.Plot
