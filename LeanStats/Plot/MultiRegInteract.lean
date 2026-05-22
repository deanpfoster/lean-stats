import LeanStats.Descriptive

/-! # LeanStats.Plot.MultiRegInteract — Multiple regression with interaction terms

Generates a self-contained HTML page with interaction terms that auto-derive
from parent transforms. Layout: horizontal flex row of panels (calibration +
main effects + interactions).
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def mriCss : String :=
  "body{font-family:system-ui,sans-serif;margin:20px;color:#333}" ++
  "h2{margin-bottom:8px}" ++
  ".plots-row{display:flex;gap:8px;align-items:flex-start;margin:12px 0;flex-wrap:wrap}" ++
  ".panel{display:flex;flex-direction:column;align-items:center}" ++
  ".panel svg{border:1px solid #e0e0e0;border-radius:4px}" ++
  ".panel-ctrl{font-size:11px;margin-top:4px;text-align:center}" ++
  ".y-ctrl{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;writing-mode:vertical-rl;transform:rotate(180deg);margin-right:8px}" ++
  ".y-label{font-weight:bold;font-size:13px}" ++
  ".y-ctrl select{font-size:11px;writing-mode:horizontal-tb;transform:rotate(180deg)}" ++
  ".toolbar{margin:8px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap;font-size:13px}" ++
  ".toolbar select,.toolbar button{font-size:13px}" ++
  "#fitBtn{background:#3b82f6;color:#fff;border:none;border-radius:4px;cursor:pointer;padding:4px 8px}" ++
  "#fitBtn:hover{background:#2563eb}" ++
  "#clearBtn{padding:4px 8px}" ++
  ".stats{font-family:monospace;font-size:12px;margin:8px 0;padding:8px;background:#f8f8f8;border-radius:6px}"

private def mriJs1 : String :=
  "const W=280,H=240,M={t:12,r:10,b:25,l:38};" ++
  "const pw=W-M.l-M.r,ph=H-M.t-M.b;" ++
  "function tx(v,f){switch(f){case'recip':return v!==0?1/v:NaN;case'log':return v>0?Math.log(v):NaN;case'sqrt':return v>=0?Math.sqrt(v):NaN;case'square':return v*v;case'exp':return Math.exp(v);default:return v}}" ++
  "function tfLabel(f){switch(f){case'recip':return'1/';case'log':return'log';case'sqrt':return'√';case'square':return'²';case'exp':return'exp';default:return''}}" ++
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
  "function polyFit(x,y,deg){const n=x.length;let X=[];for(let i=0;i<n;i++){let row=[];for(let j=0;j<=deg;j++)row.push(Math.pow(x[i],j));X.push(row)}return fitOLS(X,y)}" ++
  "function polyEval(coef,x){let y=0;for(let i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}"

private def mriJs2 : String :=
  "function buildDesignMatrix(){" ++
    "const n=rawY.length;let X=[];for(let i=0;i<n;i++)X[i]=[1];" ++
    "for(let t=0;t<terms.length;t++){" ++
      "let term=terms[t];let tf=document.getElementById('tf_'+t).value;" ++
      "let deg=parseInt(document.getElementById('deg_'+t).value);" ++
      "term.tf=tf;term.deg=deg;" ++
      "let baseVals;" ++
      "if(term.type==='main'){baseVals=rawXs[term.idx]}" ++
      "else{let pi=term.parents[0],pj=term.parents[1];" ++
        "let tfi=document.getElementById('tf_'+pi).value;" ++
        "let tfj=document.getElementById('tf_'+pj).value;" ++
        "baseVals=rawXs[terms[pi].idx].map((v,k)=>tx(v,tfi)*tx(rawXs[terms[pj].idx][k],tfj))}" ++
      "let cols=predCols(baseVals,tf,deg);" ++
      "cols.forEach(col=>{for(let i=0;i<n;i++)X[i].push(col[i])})" ++
    "}return X}" ++
  "function buildDesignMatrixExcl(exclIdx){" ++
    "const n=rawY.length;let X=[];for(let i=0;i<n;i++)X[i]=[1];" ++
    "for(let t=0;t<terms.length;t++){" ++
      "if(t===exclIdx)continue;" ++
      "let term=terms[t];let tf=document.getElementById('tf_'+t).value;" ++
      "let deg=parseInt(document.getElementById('deg_'+t).value);" ++
      "let baseVals;" ++
      "if(term.type==='main'){baseVals=rawXs[term.idx]}" ++
      "else{let pi=term.parents[0],pj=term.parents[1];" ++
        "let tfi=document.getElementById('tf_'+pi).value;" ++
        "let tfj=document.getElementById('tf_'+pj).value;" ++
        "baseVals=rawXs[terms[pi].idx].map((v,k)=>tx(v,tfi)*tx(rawXs[terms[pj].idx][k],tfj))}" ++
      "let cols=predCols(baseVals,tf,deg);" ++
      "cols.forEach(col=>{for(let i=0;i<n;i++)X[i].push(col[i])})" ++
    "}return X}" ++
  "function avResiduals(termIdx){" ++
    "const yf=document.getElementById('yform').value;" ++
    "let ty=rawY.map(v=>tx(v,yf));" ++
    "let Xfull=buildDesignMatrix();" ++
    "let valid=[];for(let i=0;i<ty.length;i++){let ok=isFinite(ty[i])&&!isNaN(ty[i]);if(ok){for(let j=0;j<Xfull[i].length;j++)if(!isFinite(Xfull[i][j])||isNaN(Xfull[i][j])){ok=false;break}}if(ok)valid.push(i)}" ++
    "if(valid.length<3)return null;" ++
    "let Xexcl=buildDesignMatrixExcl(termIdx);" ++
    "let XvE=valid.map(i=>Xexcl[i]),yv=valid.map(i=>ty[i]);" ++
    "let coefY=fitOLS(XvE,yv);let eY=residuals(XvE,yv,coefY);" ++
    "let term=terms[termIdx];let tf=document.getElementById('tf_'+termIdx).value;" ++
    "let deg=parseInt(document.getElementById('deg_'+termIdx).value);" ++
    "if(deg===0)return{eX:valid.map(()=>0),eY:eY,valid:valid};" ++
    "let baseVals;" ++
    "if(term.type==='main'){baseVals=rawXs[term.idx]}" ++
    "else{let pi=term.parents[0],pj=term.parents[1];" ++
      "let tfi=document.getElementById('tf_'+pi).value;" ++
      "let tfj=document.getElementById('tf_'+pj).value;" ++
      "baseVals=rawXs[terms[pi].idx].map((v,k)=>tx(v,tfi)*tx(rawXs[terms[pj].idx][k],tfj))}" ++
    "let xjCols=predCols(baseVals,tf,deg);" ++
    "let xjFlat=valid.map(i=>xjCols[0][i]);" ++
    "let coefX=fitOLS(XvE,xjFlat);let eX=residuals(XvE,xjFlat,coefX);" ++
    "return{eX:eX,eY:eY,valid:valid}}"

private def mriJs3 : String :=
  "var lwOptions=[1,2,3,5];var lwCurrent=2;var seOn=false;" ++
  "var colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2','#4f46e5','#dc2626'];" ++
  "var fits=[];var plotState=[];" ++
  "for(let i=0;i<terms.length+1;i++)plotState.push(null);" ++
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
  "function drawPlotContent(svgEl,xArr,yArr,plotIdx,annotation){" ++
    "let xMin=Math.min(...xArr),xMax=Math.max(...xArr),yMin=Math.min(...yArr),yMax=Math.max(...yArr);" ++
    "let xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "xMin-=xR*0.05;xMax+=xR*0.05;yMin-=yR*0.05;yMax+=yR*0.05;" ++
    "if(document.getElementById('lockY').checked&&plotIdx>0){" ++
      "let allResid=[];for(let p=1;p<terms.length+1;p++){let ps=plotState[p];if(ps)allResid.push(...ps.plotY)}" ++
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
    "if(plotIdx>0&&xArr.length>2){" ++
      "let n=xArr.length;let xm=xArr.reduce((a,b)=>a+b,0)/n;" ++
      "let Sxx=xArr.reduce((a,v)=>a+(v-xm)**2,0);" ++
      "let num=0,den=0;for(let i=0;i<n;i++){num+=xArr[i]*yArr[i];den+=xArr[i]*xArr[i]}" ++
      "let slope=den>0?num/den:0;" ++
      "let sse=0;for(let i=0;i<n;i++){let r=yArr[i]-slope*xArr[i];sse+=r*r}" ++
      "let se=Math.sqrt(sse/Math.max(1,n-2));" ++
      "let bandU='',bandL='';const nPts=60;" ++
      "for(let i=0;i<=nPts;i++){let xi=xMin+i/nPts*xR;let yi=slope*xi;let h=1/n+(xi-xm)**2/(Sxx||1);let band=1.96*se*Math.sqrt(h);" ++
        "bandU+=(bandU===''?'M':'L')+sx(xi)+','+sy(yi+band);bandL+=(bandL===''?'M':'L')+sx(xi)+','+sy(yi-band)}" ++
      "s+=`<path d='${bandU}' fill='none' stroke='rgba(100,100,100,0.3)' stroke-dasharray='3' stroke-width='1'/>`;" ++
      "s+=`<path d='${bandL}' fill='none' stroke='rgba(100,100,100,0.3)' stroke-dasharray='3' stroke-width='1'/>`;" ++
      "s+=`<line x1='${sx(xMin)}' y1='${sy(slope*xMin)}' x2='${sx(xMax)}' y2='${sy(slope*xMax)}' stroke='#666' stroke-width='1.5'/>`" ++
    "}" ++
    "for(let i=0;i<xArr.length;i++){s+=`<circle cx='${sx(xArr[i])}' cy='${sy(yArr[i])}' r='3' fill='steelblue' opacity='0.7'/>`}" ++
    "if(annotation)s+=`<text x='${M.l+4}' y='${M.t+12}' font-size='10' fill='#333'>${annotation}</text>`;" ++
    "svgEl.innerHTML=s;renderFitsForPlot(svgEl,plotIdx)}" ++
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
    "})}"

private def mriJs4 : String :=
  "function updateInteractionLabels(){" ++
    "for(let t=0;t<terms.length;t++){" ++
      "if(terms[t].type!=='interact')continue;" ++
      "let pi=terms[t].parents[0],pj=terms[t].parents[1];" ++
      "let tfi=document.getElementById('tf_'+pi).value;" ++
      "let tfj=document.getElementById('tf_'+pj).value;" ++
      "let li=tfLabel(tfi),lj=tfLabel(tfj);" ++
      "let ni=predNames[terms[pi].idx],nj=predNames[terms[pj].idx];" ++
      "let lbl=(li?li+'('+ni+')':ni)+'·'+(lj?lj+'('+nj+')':nj);" ++
      "document.getElementById('lbl_'+t).textContent=lbl}" ++
  "}" ++
  "function drawAll(){" ++
    "updateInteractionLabels();" ++
    "const yf=document.getElementById('yform').value;" ++
    "let ty=rawY.map(v=>tx(v,yf));" ++
    "let Xfull=buildDesignMatrix();" ++
    "let valid=[];for(let i=0;i<ty.length;i++){let ok=isFinite(ty[i])&&!isNaN(ty[i]);if(ok){for(let j=0;j<Xfull[i].length;j++)if(!isFinite(Xfull[i][j])||isNaN(Xfull[i][j])){ok=false;break}}if(ok)valid.push(i)}" ++
    "if(valid.length<3)return;" ++
    "let Xv=valid.map(i=>Xfull[i]),yv=valid.map(i=>ty[i]);" ++
    "let coef=fitOLS(Xv,yv);" ++
    "let yhat=predicted(Xv,coef);" ++
    "let svg0=document.getElementById('panel_0');" ++
    "let sst=0,sse=0;let ym=yv.reduce((a,b)=>a+b,0)/yv.length;for(let i=0;i<yv.length;i++){sst+=(yv[i]-ym)**2;sse+=(yv[i]-yhat[i])**2}" ++
    "let r2=1-sse/(sst||1);" ++
    "drawPlotContent(svg0,yhat,yv,0,'R²='+r2.toFixed(4)+' n='+yv.length);" ++
    "{let ps=plotState[0];if(ps){let dMin=Math.max(ps.xMin,ps.yMin),dMax=Math.min(ps.xMax,ps.yMax);if(dMax>dMin)svg0.innerHTML+=`<line x1='${ps.sx(dMin)}' y1='${ps.sy(dMin)}' x2='${ps.sx(dMax)}' y2='${ps.sy(dMax)}' stroke='#999' stroke-dasharray='4' stroke-width='1'/>`}}" ++
    "for(let t=0;t<terms.length;t++){" ++
      "let res=avResiduals(t);" ++
      "let svgT=document.getElementById('panel_'+(t+1));" ++
      "if(!res){svgT.innerHTML='<text x=\"50\" y=\"120\" font-size=\"12\">insufficient data</text>';continue}" ++
      "let deg=parseInt(document.getElementById('deg_'+t).value);" ++
      "let ann='';" ++
      "if(deg>0){let num=0,den=0;for(let i=0;i<res.eX.length;i++){num+=res.eX[i]*res.eY[i];den+=res.eX[i]*res.eX[i]}let slope=den>0?num/den:0;ann='β='+slope.toFixed(4)}" ++
      "else{ann='excluded (deg=0)'}" ++
      "drawPlotContent(svgT,res.eX,res.eY,t+1,ann)}" ++
    "renderLegend()}" ++
  "function renderLegend(){" ++
    "let html='';" ++
    "fits.forEach(function(spec,idx){" ++
      "if(spec.hidden)return;" ++
      "let ps=plotState[spec.plot];if(!ps||ps.plotX.length<spec.deg+1)return;" ++
      "let lcoef=polyFit(ps.plotX,ps.plotY,spec.deg);" ++
      "let pname=spec.plot===0?'Y vs Ŷ':spec.label;" ++
      "let eq=pname+': y = ';for(let i=lcoef.length-1;i>=0;i--){let c=lcoef[i];let cs=c>=0&&i<lcoef.length-1?' + '+c.toPrecision(3):c.toPrecision(3);if(i===0)eq+=cs;else if(i===1)eq+=cs+'·x ';else eq+=cs+'·x^'+i+' '}" ++
      "let col=colors[idx%colors.length];" ++
      "html+='<div style=\"margin:1px 0\"><svg width=\"24\" height=\"16\" style=\"vertical-align:middle;margin-right:4px;cursor:pointer\" data-fidx=\"'+idx+'\"><line x1=\"2\" y1=\"8\" x2=\"22\" y2=\"8\" stroke=\"'+col+'\" stroke-width=\"'+spec.lw+'\"/></svg><span style=\"font-size:11px\">'+eq+'</span></div>'" ++
    "});" ++
    "document.getElementById('legend').innerHTML=html;" ++
    "document.getElementById('legend').querySelectorAll('[data-fidx]').forEach(function(el){el.addEventListener('click',function(){var idx=parseInt(el.dataset.fidx);fits[idx].hidden=!fits[idx].hidden;drawAll()})})" ++
  "}"

private def mriJs5 : String :=
  "drawLwPicker();" ++
  "document.getElementById('fitBtn').addEventListener('click',function(){" ++
    "for(let p=0;p<terms.length+1;p++){" ++
      "let ps=plotState[p];if(!ps||ps.plotX.length<2)continue;" ++
      "let coef=polyFit(ps.plotX,ps.plotY,1);" ++
      "let lbl=p===0?'Y vs Ŷ':(document.getElementById('lbl_'+(p-1))?document.getElementById('lbl_'+(p-1)).textContent:predNames[terms[p-1].idx]);" ++
      "fits.push({deg:1,lw:lwCurrent,se:seOn,plot:p,frozen:true,coef:coef,label:lbl})" ++
    "}" ++
    "drawAll();drawLwPicker()});" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){fits=[];drawAll();drawLwPicker()});" ++
  "document.getElementById('yform').addEventListener('change',drawAll);" ++
  "document.getElementById('lockY').addEventListener('change',drawAll);" ++
  "for(let t=0;t<terms.length;t++){document.getElementById('tf_'+t).addEventListener('change',drawAll);document.getElementById('deg_'+t).addEventListener('change',drawAll)}" ++
  "document.getElementById('keepBtn').addEventListener('click',function(){" ++
    "var state={event:'keep',yform:document.getElementById('yform').value,terms:terms,fits:fits};" ++
    "if(ws&&ws.readyState===1){ws.send(JSON.stringify(state));document.getElementById('keepBtn').textContent='✓ Kept';setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
    "else{document.getElementById('keepBtn').textContent='📋 Copied';navigator.clipboard.writeText(JSON.stringify(state,null,2)).catch(function(){});setTimeout(function(){document.getElementById('keepBtn').textContent='📌 Keep'},1500)}" ++
  "});" ++
  "var ws=null;try{ws=new WebSocket('ws://localhost:9147')}catch(e){}" ++
  "drawAll();"


/-- Generate a self-contained HTML page for multiple regression with interaction terms.
    `interactions` is an array of (i, j) pairs indicating which X variables interact. -/
def multiRegInteract (xs : Array (String × Array Float)) (ys : Array Float)
    (interactions : Array (Nat × Nat) := #[])
    (yName : String := "y") (title : String := "") : String :=
  let pageTitle := if title != "" then title else s!"{yName} ~ multiple regression (interactions)"
  let nMain := xs.size
  let predArrays := String.intercalate "," (xs.toList.map fun (_, vals) =>
    "[" ++ String.intercalate "," (vals.toList.map toString) ++ "]")
  let predNames := String.intercalate "," (xs.toList.map fun (name, _) => s!"'{name}'")
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  -- Build terms array JS
  let mainTerms := xs.toList.enum.map fun (i, _) =>
    s!"\{type:'main',idx:{i},tf:'linear',deg:1}"
  let interTerms := interactions.toList.map fun (i, j) =>
    s!"\{type:'interact',parents:[{i},{j}],tf:'linear',deg:1}"
  let allTerms := mainTerms ++ interTerms
  let termsJs := "[" ++ String.intercalate "," allTerms ++ "]"
  -- Panel 0: calibration
  let panel0 := "<div class='panel'><svg id='panel_0' width='280' height='240'></svg>" ++
    "<div class='panel-ctrl'><b>Y vs Ŷ</b> deg <select id='caldeg'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option></select></div></div>"
  -- Main effect panels
  let mainPanels := String.join (xs.toList.enum.map fun (i, (name, _)) =>
    s!"<div class='panel'><svg id='panel_{i+1}' width='280' height='240'></svg>" ++
    s!"<div class='panel-ctrl'><b id='lbl_{i}'>{name}</b> " ++
    s!"<select id='tf_{i}'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select> " ++
    s!"deg <select id='deg_{i}'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select></div></div>")
  -- Interaction panels
  let interPanels := String.join (interactions.toList.enum.map fun (k, (i, j)) =>
    let idx := nMain + k
    let nameI := match xs.get? i with | some (n, _) => n | none => s!"x{i}"
    let nameJ := match xs.get? j with | some (n, _) => n | none => s!"x{j}"
    s!"<div class='panel'><svg id='panel_{idx+1}' width='280' height='240'></svg>" ++
    s!"<div class='panel-ctrl'><b id='lbl_{idx}'>{nameI}·{nameJ}</b> " ++
    s!"<select id='tf_{idx}'><option value='recip'>1/x</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>x²</option><option value='exp'>exp</option></select> " ++
    s!"deg <select id='deg_{idx}'><option value='0'>0</option><option value='1' selected>1</option><option value='2'>2</option><option value='3'>3</option><option value='4'>4</option><option value='5'>5</option></select></div></div>")
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>\n<style>{mriCss}</style></head><body>\n" ++
  s!"<h2>{pageTitle} <button id='keepBtn' title='Pin this view' style='background:#16a34a;color:#fff;border:none;border-radius:4px;padding:4px 8px;cursor:pointer;font-size:12px;vertical-align:middle'>📌 Keep</button></h2>\n" ++
  s!"<div style='display:flex;align-items:stretch'><div class='y-ctrl'><div class='y-label'>{yName}</div><select id='yform'><option value='recip'>1/y</option><option value='log'>log</option><option value='sqrt'>√</option><option value='linear' selected>linear</option><option value='square'>y²</option><option value='exp'>exp</option></select></div><div class='plots-row'>{panel0}{mainPanels}{interPanels}</div></div>\n" ++
  s!"<div class='toolbar'>\n" ++
  s!"  <svg id='lwPicker' width='120' height='24' style='vertical-align:middle;cursor:pointer' title='Line thickness'></svg>\n" ++
  s!"  <button id='fitBtn'>+ Checkpoint</button>\n" ++
  s!"  <button id='clearBtn'>Clear</button>\n" ++
  s!"  <label title='Lock Y range across all AV plots'><input type='checkbox' id='lockY'> lock Y</label>\n" ++
  s!"</div>\n" ++
  s!"<div id='legend' class='stats'></div>\n" ++
  s!"<script>\nconst rawXs=[{predArrays}];\nconst predNames=[{predNames}];\nconst rawY={yJson};\nvar terms={termsJs};\n" ++
  mriJs1 ++ "\n" ++ mriJs2 ++ "\n" ++ mriJs3 ++ "\n" ++ mriJs4 ++ "\n" ++ mriJs5 ++
  "\n</script></body></html>"

end LeanStats.Plot
