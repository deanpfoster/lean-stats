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
  "function invLink(eta,link){switch(link){case'logit':return 1/(1+Math.exp(-eta));case'probit':return probitCdf(eta);case'cloglog':return 1-Math.exp(-Math.exp(eta));default:return eta}}" ++
  -- Probit (normal CDF approximation)
  "function probitCdf(z){const a1=0.254829592,a2=-0.284496736,a3=1.421413741,a4=-1.453152027,a5=1.061405429,p=0.3275911;const s=z<0?-1:1;const t=1/(1+p*Math.abs(z));const y=1-((((a5*t+a4)*t+a3)*t+a2)*t+a1)*t*Math.exp(-z*z/2);return 0.5*(1+s*y)}" ++
  "function probitInv(p){if(p<=0)return -5;if(p>=1)return 5;const a=[0,-3.969683028665376e1,2.209460984245205e2,-2.759285104469687e2,1.383577518672690e2,-3.066479806614716e1,2.506628277459239e0];const b=[0,-5.447609879822406e1,1.615858368580409e2,-1.556989798598866e2,6.680131188771972e1,-1.328068155288572e1];const c=[0,-7.784894002430293e-3,-3.223964580411365e-1,-2.400758277161838e0,-2.549732539343734e0,4.374664141464968e0,2.938163982698783e0];const d=[0,7.784695709041462e-3,3.224671290700398e-1,2.445134137142996e0,3.754408661907416e0];const pLow=0.02425,pHigh=1-pLow;let q,r;if(p<pLow){q=Math.sqrt(-2*Math.log(p));return(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6])/((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)}if(p<=pHigh){q=p-0.5;r=q*q;return(((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6])*q/(((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1)}q=Math.sqrt(-2*Math.log(1-p));return-(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6])/((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)}" ++
  -- IRLS for polynomial GLM (returns coefficients [b0, b1, b2, ...])
  "function fitGlm(x,y,link,deg){" ++
    "if(!deg)deg=1;" ++
    "const n=x.length,p=deg+1;" ++
    "var coef=new Array(p).fill(0);" ++
    "for(var iter=0;iter<30;iter++){" ++
      -- Build X'WX and X'Wz
      "var XtWX=[];for(var i=0;i<p;i++){XtWX[i]=new Array(p).fill(0)}" ++
      "var XtWz=new Array(p).fill(0);" ++
      "for(var i=0;i<n;i++){" ++
        "var eta=0;for(var j=0;j<p;j++)eta+=coef[j]*Math.pow(x[i],j);" ++
        "var mu=invLink(eta,link);" ++
        "var muC=Math.max(1e-7,Math.min(1-1e-7,mu));" ++
        "var w,deriv;" ++
        "if(link==='logit'){w=muC*(1-muC);deriv=w}" ++
        "else if(link==='probit'){var phi=Math.exp(-eta*eta/2)/Math.sqrt(2*Math.PI);deriv=phi;w=phi*phi/(muC*(1-muC))}" ++
        "else if(link==='cloglog'){var h=Math.exp(eta);deriv=(1-muC)*h;w=deriv*deriv/(muC*(1-muC))}" ++
        "else{w=1;deriv=1}" ++  -- identity: use variance as weight
        "var z=eta+(y[i]-muC)/deriv;" ++
        "for(var j=0;j<p;j++){XtWz[j]+=w*z*Math.pow(x[i],j);for(var k=0;k<p;k++)XtWX[j][k]+=w*Math.pow(x[i],j)*Math.pow(x[i],k)}" ++
      "}" ++
      -- Solve via Gaussian elimination
      "var A=XtWX.map(function(r,i){return r.concat([XtWz[i]])});" ++
      "for(var i=0;i<p;i++){var mx=i;for(var j=i+1;j<p;j++)if(Math.abs(A[j][i])>Math.abs(A[mx][i]))mx=j;var tmp=A[i];A[i]=A[mx];A[mx]=tmp;" ++
      "if(Math.abs(A[i][i])<1e-12)continue;" ++
      "for(var j=i+1;j<p;j++){var f=A[j][i]/A[i][i];for(var k=i;k<=p;k++)A[j][k]-=f*A[i][k]}}" ++
      "var nc=new Array(p);" ++
      "for(var i=p-1;i>=0;i--){nc[i]=A[i][p];for(var j=i+1;j<p;j++)nc[i]-=A[i][j]*nc[j];nc[i]/=A[i][i]}" ++
      "var diff=0;for(var i=0;i<p;i++)diff+=Math.abs(nc[i]-coef[i]);" ++
      "coef=nc;if(diff<1e-8)break" ++
    "}" ++
    "return coef}" ++
  -- Evaluate polynomial
  "function polyEvalB(coef,x){var y=0;for(var i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}" ++
  -- Compute inverse information matrix (for SE)
  "function infoMatrix(x,coef,link,deg){" ++
    "if(!deg)deg=1;const p=deg+1,n=x.length;" ++
    "var I=[];for(var i=0;i<p;i++){I[i]=new Array(p).fill(0)}" ++
    "for(var i=0;i<n;i++){" ++
      "var eta=polyEvalB(coef,x[i]);var mu=invLink(eta,link);var muC=Math.max(1e-7,Math.min(1-1e-7,mu));" ++
      "var w;if(link==='identity'){w=1}else if(link==='logit'){w=muC*(1-muC)}else if(link==='probit'){var phi=Math.exp(-eta*eta/2)/Math.sqrt(2*Math.PI);w=phi*phi/(muC*(1-muC))}else{var h=Math.exp(eta);w=((1-muC)*h)**2/(muC*(1-muC))}" ++
      "for(var j=0;j<p;j++)for(var k=0;k<p;k++)I[j][k]+=w*Math.pow(x[i],j)*Math.pow(x[i],k)" ++
    "}" ++
    -- Invert via Gauss-Jordan
    "var A=I.map(function(r,i){var row=r.slice();for(var j=0;j<p;j++)row.push(i===j?1:0);return row});" ++
    "for(var i=0;i<p;i++){var mx=i;for(var j=i+1;j<p;j++)if(Math.abs(A[j][i])>Math.abs(A[mx][i]))mx=j;var tmp=A[i];A[i]=A[mx];A[mx]=tmp;" ++
    "var d=A[i][i];if(Math.abs(d)<1e-12)continue;for(var j=0;j<2*p;j++)A[i][j]/=d;" ++
    "for(var j=0;j<p;j++){if(j===i)continue;var f=A[j][i];for(var k=0;k<2*p;k++)A[j][k]-=f*A[i][k]}}" ++
    "var V=[];for(var i=0;i<p;i++){V[i]=[];for(var j=0;j<p;j++)V[i][j]=A[i][j+p]}" ++
    "return V}" ++
  -- SE of eta at a point x given inverse info matrix V
  "function seEta(x,V,deg){" ++
    "if(!deg)deg=1;var s=0;const p=deg+1;" ++
    "for(var j=0;j<p;j++)for(var k=0;k<p;k++)s+=Math.pow(x,j)*V[j][k]*Math.pow(x,k);" ++
    "return Math.sqrt(Math.max(0,s))}" ++
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
          -- Flat forecast line spanning the bin
          "s+=`<line x1='${sx(lo)}' y1='${cy}' x2='${sx(hi)}' y2='${cy}' stroke='#666' stroke-width='1.5' opacity='0.5'/>`;" ++
          -- Circle at midpoint
          "s+=`<circle cx='${cx}' cy='${cy}' r='${r}' fill='none' stroke='#666' stroke-width='1.5'/>`" ++
        "}" ++
      "}" ++
    "}" ++
    -- PAV isotonic regression: circles at pool midpoints + flat forecast lines
    "if(document.getElementById('pav').checked){" ++
      "var pavY=pav(pairs.map(function(p){return p.y}));" ++
      -- Find pool boundaries (where pavY changes value)
      "var pools=[];var start=0;" ++
      "for(var i=1;i<=pairs.length;i++){" ++
        "if(i===pairs.length||pavY[i]!==pavY[i-1]){" ++
          "var sumX=0;var minX=Infinity;var maxX=-Infinity;" ++
          "for(var k=start;k<i;k++){var px=orig?pairs[k].rx:pairs[k].x;sumX+=px;if(px<minX)minX=px;if(px>maxX)maxX=px}" ++
          "pools.push({midX:sumX/(i-start),minX:minX,maxX:maxX,prob:pavY[start],n:i-start});" ++
          "start=i" ++
        "}" ++
      "}" ++
      "var maxN=Math.max.apply(null,pools.map(function(p){return p.n}));" ++
      "var maxR=12;" ++
      "pools.forEach(function(pool){" ++
        -- Flat forecast line spanning the pool
        "s+=`<line x1='${sx(pool.minX)}' y1='${sy(pool.prob)}' x2='${sx(pool.maxX)}' y2='${sy(pool.prob)}' stroke='#16a34a' stroke-width='2' opacity='0.7'/>`;" ++
        -- Circle at midpoint, area ∝ n
        "var r=Math.sqrt(pool.n/maxN)*maxR;" ++
        "s+=`<circle cx='${sx(pool.midX)}' cy='${sy(pool.prob)}' r='${r}' fill='rgba(22,163,74,0.2)' stroke='#16a34a' stroke-width='1.5'/>`" ++
      "});" ++
    "}" ++
    "svg.innerHTML=s;" ++
    "statsEl.textContent=`n=${pairs.length} (${pairs.filter(p=>p.y===1).length} events, ${pairs.filter(p=>p.y===0).length} non-events)`;renderBinaryFits()" ++
  "}" ++
  -- Fit
  -- Events
  "var fitSpecs=[];" ++
  "document.getElementById('xform').addEventListener('change',function(){draw()});" ++
  -- Line width picker (SVG swatches)
  "var lwOptions=[1,2,3,5];var lwCurrent=2;" ++
  "var lwColors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2'];" ++
  "function drawLwPicker(){" ++
    "var pick=document.getElementById('lwPicker');" ++
    "var s='';var segW=25;var nextColor=lwColors[fitSpecs.length%lwColors.length];" ++
    "lwOptions.forEach(function(w,i){" ++
      "var x=i*30+2;var y=12;" ++
      "var col=(w===lwCurrent)?nextColor:'#999';" ++
      "var opacity=(w===lwCurrent)?1:0.4;" ++
      "s+=`<line x1='${x}' y1='${y}' x2='${x+segW}' y2='${y}' stroke='${col}' stroke-width='${w}' opacity='${opacity}' data-lw='${w}' style='cursor:pointer'/>`" ++
    "});" ++
    "pick.innerHTML=s;" ++
    "pick.querySelectorAll('line').forEach(function(el){el.addEventListener('click',function(){lwCurrent=parseFloat(el.dataset.lw);drawLwPicker()})})" ++
  "}" ++
  "drawLwPicker();" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){var link=document.getElementById('link').value;var se=document.getElementById('seToggle').checked;var deg=parseInt(document.getElementById('xdeg').value);var xf=document.getElementById('xform').value;fitSpecs.push({link:link,se:se,deg:deg,lw:lwCurrent,xf:xf});draw();drawLwPicker()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){fitSpecs=[];draw()});" ++
  "document.getElementById('seToggle').addEventListener('change',function(){});" ++
  "document.getElementById('empirical').addEventListener('change',draw);" ++
  "document.getElementById('nbins').addEventListener('change',draw);" ++
  "document.getElementById('link').addEventListener('change',function(){});" ++
  "document.getElementById('pav').addEventListener('change',draw);" ++
  "document.getElementById('origToggle').addEventListener('change',function(){draw()});" ++
  -- Render all stored fits
  "function renderBinaryFits(){" ++
    "const pairs=window._pairs,sx=window._sx,sy=window._sy;" ++
    "const orig=window._orig,xf=window._xf;" ++
    "const xMin=window._xMin,xMax=window._xMax;" ++
    "if(!pairs)return;" ++
    "const colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2'];" ++
    "const xd=pairs.map(p=>p.x),yd=pairs.map(p=>p.y);" ++
    "fitSpecs.forEach(function(spec,idx){" ++
      "const deg=spec.deg||1;" ++
      -- Build pairs for THIS fit's transform
      "var fpairs=[];for(var i=0;i<rawX.length;i++){var xt=tx(rawX[i],spec.xf||xf);if(!isNaN(xt)&&isFinite(xt))fpairs.push({x:xt,y:rawY[i],rx:rawX[i]})}" ++
      "fpairs.sort(function(a,b){return a.x-b.x});" ++
      "if(fpairs.length<deg+1)return;" ++
      "var fxd=fpairs.map(function(p){return p.x}),fyd=fpairs.map(function(p){return p.y});" ++
      "const coef=fitGlm(fxd,fyd,spec.link,deg);" ++
      "const V=spec.se?infoMatrix(fxd,coef,spec.link,deg):null;" ++
      "let path='';let bandU='';let bandL='';" ++
      "for(let i=0;i<=200;i++){" ++
        "const plotXi=xMin+i/200*(xMax-xMin);" ++
        -- Convert current plot x to this fit's transform space
        "var txI;" ++
        "if(orig){txI=tx(plotXi,spec.xf||xf)}else{txI=plotXi}" ++
        "if(isNaN(txI)||!isFinite(txI))continue;" ++
        "const eta=polyEvalB(coef,txI);" ++
        "const p=invLink(eta,spec.link);" ++
        "const px=sx(plotXi),py=sy(p);" ++
        "path+=(path===''?'M':'L')+px+','+py;" ++
        "if(spec.se&&V){const se=1.96*seEta(txI,V,deg);bandU+=(bandU===''?'M':'L')+px+','+sy(invLink(eta+se,spec.link));bandL+=(bandL===''?'M':'L')+px+','+sy(invLink(eta-se,spec.link))}" ++
      "}" ++
      "const col=colors[idx%colors.length];" ++
      "if(spec.se&&bandU){var slw=Math.max(0.5,spec.lw*0.6);svg.innerHTML+=`<path d='${bandU}' fill='none' stroke='${col}' opacity='0.4' stroke-width='${slw}' stroke-dasharray='4'/><path d='${bandL}' fill='none' stroke='${col}' opacity='0.4' stroke-width='${slw}' stroke-dasharray='4'/>`}" ++
      "svg.innerHTML+=`<path d='${path}' fill='none' stroke='${col}' stroke-width='${spec.lw||2}'/>`" ++
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
  <label>X degree: <select id='xdeg'><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option></select></label>
  <label>Link: <select id='link'><option value='logit' selected>logit</option><option value='probit'>probit</option><option value='cloglog'>cloglog</option><option value='identity'>identity</option></select></label>
  <svg id='lwPicker' width='120' height='24' style='vertical-align:middle;cursor:pointer'></svg>
  <button id='fitBtn'>+ Fit</button>
  <button id='clearBtn'>Clear fits</button>
</div>
<div class='controls'>
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
