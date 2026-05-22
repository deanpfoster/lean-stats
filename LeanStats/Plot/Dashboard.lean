import LeanStats.Descriptive

/-! # LeanStats.Plot.Dashboard — unified multi-panel analysis dashboard

A persistent live workspace with dynamic panels (scatter, histogram, avplot, residual),
shared point state, and bidirectional WebSocket on port 9147.

## Architecture (JS side)

Panel object model: each panel is created via `createPanel(type, config)` which
returns `{type, config, svgId, render, handleClick, getAnnotation}`.
Panel-type-specific logic lives in `panelTypes` registry. Core loop is just
`drawAll()` → iterate panels → `panel.render(sharedState)`.
-/

set_option autoImplicit false

namespace LeanStats.Plot

private def dashCss : String :=
  "body{font-family:system-ui,sans-serif;margin:12px;color:#333}" ++
  "h2{margin-bottom:6px}" ++
  ".dashboard{display:flex;flex-wrap:wrap;gap:8px}" ++
  ".panel{border:1px solid #e0e0e0;border-radius:6px;padding:4px}" ++
  ".panel-header{font-size:11px;text-align:center;margin-bottom:2px}" ++
  ".panel svg{display:block}" ++
  ".panel-ctrl{font-size:11px;text-align:center;margin-top:4px}" ++
  ".toolbar{margin:12px 0;display:flex;gap:12px;align-items:center;flex-wrap:wrap;font-size:13px}" ++
  ".toolbar button{font-size:13px;padding:4px 8px;border:none;border-radius:4px;cursor:pointer}" ++
  "#chkBtn{background:#3b82f6;color:#fff}" ++
  "#chkBtn:hover{background:#2563eb}" ++
  "#clearBtn{background:#e5e7eb}" ++
  "#invertBtn{background:#e5e7eb}" ++
  ".legend{margin:8px 0;font-size:12px;font-family:monospace}"

private def dashJs1 : String :=
  "var PW=300,PH=250,M={t:15,r:15,b:30,l:45};" ++
  "var pw=PW-M.l-M.r,ph=PH-M.t-M.b;" ++
  "var n=data.y.length;" ++
  "var pointState=new Array(n);for(var i=0;i<n;i++)pointState[i]={selected:false,excluded:false,hidden:false};" ++
  "var panels=[];var fits=[];var colors=['crimson','#2563eb','#16a34a','#9333ea','#ea580c','#0891b2'];" ++
  "var numVars=Object.keys(data.xs);" ++
  "var grpVars=Object.keys(data.groups);" ++
  -- sharedState
  "var sharedState={points:pointState,data:data,fits:fits};" ++
  -- transforms + math utilities
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
  "function polyEval(coef,x){var y=0;for(var i=0;i<coef.length;i++)y+=coef[i]*Math.pow(x,i);return y}" ++
  "function fitOLS(X,y){" ++
    "var nn=X.length,p=X[0].length;" ++
    "var XtX=[];for(var i=0;i<p;i++){XtX[i]=[];for(var j=0;j<p;j++){var s=0;for(var k=0;k<nn;k++)s+=X[k][i]*X[k][j];XtX[i][j]=s}}" ++
    "var Xty=[];for(var i=0;i<p;i++){var s=0;for(var k=0;k<nn;k++)s+=X[k][i]*y[k];Xty[i]=s}" ++
    "var A=XtX.map(function(r,i){return r.concat([Xty[i]])});" ++
    "var m=A.length;" ++
    "for(var i=0;i<m;i++){var mx=i;for(var j=i+1;j<m;j++)if(Math.abs(A[j][i])>Math.abs(A[mx][i]))mx=j;var tmp=A[i];A[i]=A[mx];A[mx]=tmp;" ++
    "if(Math.abs(A[i][i])<1e-12)continue;" ++
    "for(var j=i+1;j<m;j++){var f=A[j][i]/A[i][i];for(var k=i;k<=m;k++)A[j][k]-=f*A[i][k]}}" ++
    "var coef=new Array(m);" ++
    "for(var i=m-1;i>=0;i--){coef[i]=A[i][m];for(var j=i+1;j<m;j++)coef[i]-=A[i][j]*coef[j];coef[i]/=A[i][i]}" ++
    "return coef}"


private def dashJs2 : String :=
  -- renderScatter
  "function renderScatter(panel,state){" ++
    "var svg=document.getElementById(panel.svgId);if(!svg)return;" ++
    "var p=panel;var xVar=p.config.x||numVars[0];var xf=p.config.xform||'linear';var yf=p.config.yform||'linear';" ++
    "var deg=p.config.degree||1;var xArr=state.data.xs[xVar]||[];" ++
    "var pts=[];for(var i=0;i<n;i++){if(state.points[i].hidden)continue;var xt=tx(xArr[i],xf),yt=tx(state.data.y[i],yf);if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt))pts.push({idx:i,x:xt,y:yt})}" ++
    "if(pts.length<2){svg.innerHTML='<text x=\"150\" y=\"125\" text-anchor=\"middle\" font-size=\"12\">Not enough points</text>';return}" ++
    "var xA=pts.map(function(p){return p.x}),yA=pts.map(function(p){return p.y});" ++
    "var xMin=Math.min.apply(null,xA),xMax=Math.max.apply(null,xA),yMin=Math.min.apply(null,yA),yMax=Math.max.apply(null,yA);" ++
    "var xR=xMax-xMin||1,yR=yMax-yMin||1;" ++
    "var sx=function(v){return(v-xMin)/xR*pw+M.l};var sy=function(v){return PH-M.b-(v-yMin)/yR*ph};" ++
    "var pi=panel._idx;" ++
    "var s=\"<rect x='0' y='0' width='\"+PW+\"' height='\"+PH+\"' fill='transparent' class='bg' data-pi='\"+pi+\"'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+(PH-M.b)+\"' x2='\"+(M.l+pw)+\"' y2='\"+(PH-M.b)+\"' stroke='#333'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+M.t+\"' x2='\"+M.l+\"' y2='\"+(PH-M.b)+\"' stroke='#333'/>\";" ++
    "for(var i=0;i<=4;i++){var v=xMin+i/4*xR;s+=\"<text x='\"+sx(v)+\"' y='\"+(PH-M.b+13)+\"' text-anchor='middle' font-size='9'>\"+v.toPrecision(3)+\"</text>\"}" ++
    "for(var i=0;i<=4;i++){var v=yMin+i/4*yR;s+=\"<text x='\"+(M.l-5)+\"' y='\"+(sy(v)+3)+\"' text-anchor='end' font-size='9'>\"+v.toPrecision(3)+\"</text>\"}" ++
    "var fitPts=pts.filter(function(p){return !state.points[p.idx].excluded});" ++
    "if(fitPts.length>deg){" ++
      "var fx=fitPts.map(function(p){return p.x}),fy=fitPts.map(function(p){return p.y});" ++
      "var coef=polyFit(fx,fy,deg);" ++
      "if(coef){" ++
        "var path='';for(var i=0;i<=80;i++){var xv=xMin+i/80*xR;var yv=polyEval(coef,xv);if(yv>=yMin-yR&&yv<=yMax+yR){path+=(path===''?'M':'L')+sx(xv)+','+sy(yv)}}" ++
        "s+=\"<path d='\"+path+\"' fill='none' stroke='#999' stroke-width='1.5' opacity='0.6'/>\";" ++
        "var sse=0;for(var i=0;i<fx.length;i++){var yh=polyEval(coef,fx[i]);sse+=(fy[i]-yh)*(fy[i]-yh)}" ++
        "var se=Math.sqrt(sse/Math.max(1,fx.length-deg-1));" ++
        "var xbar=fx.reduce(function(a,b){return a+b},0)/fx.length;" ++
        "var Sxx=fx.reduce(function(a,v){return a+(v-xbar)*(v-xbar)},0);" ++
        "var bandU='',bandL='';for(var i=0;i<=80;i++){var xv=xMin+i/80*xR;var yv=polyEval(coef,xv);var h=1/fx.length+(xv-xbar)*(xv-xbar)/(Sxx||1);var b=1.96*se*Math.sqrt(h);bandU+=(bandU===''?'M':'L')+sx(xv)+','+sy(yv+b);bandL+=(bandL===''?'M':'L')+sx(xv)+','+sy(yv-b)}" ++
        "s+=\"<path d='\"+bandU+\"' fill='none' stroke='#999' stroke-width='1' opacity='0.3' stroke-dasharray='3'/>\";" ++
        "s+=\"<path d='\"+bandL+\"' fill='none' stroke='#999' stroke-width='1' opacity='0.3' stroke-dasharray='3'/>\"" ++
      "}" ++
    "}" ++
    "state.fits.forEach(function(spec,idx){" ++
      "if(spec.panelIdx!==undefined&&spec.panelIdx!==pi)return;" ++
      "var col=colors[idx%colors.length];" ++
      "var path='';for(var i=0;i<=80;i++){var xv=xMin+i/80*xR;var yv=polyEval(spec.coef,xv);if(yv>=yMin-yR&&yv<=yMax+yR){path+=(path===''?'M':'L')+sx(xv)+','+sy(yv)}}" ++
      "s+=\"<path d='\"+path+\"' fill='none' stroke='\"+col+\"' stroke-width='2'/>\"" ++
    "});" ++
    "pts.forEach(function(pt){" ++
      "var st=state.points[pt.idx];" ++
      "if(st.excluded){s+=\"<text x='\"+sx(pt.x)+\"' y='\"+(sy(pt.y)+4)+\"' text-anchor='middle' font-size='11' fill='grey' opacity='0.3' data-idx='\"+pt.idx+\"' data-pi='\"+pi+\"' style='cursor:pointer'>×</text>\"}" ++
      "else if(st.selected){s+=\"<circle cx='\"+sx(pt.x)+\"' cy='\"+sy(pt.y)+\"' r='4' fill='steelblue' stroke='orange' stroke-width='2' opacity='1' data-idx='\"+pt.idx+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\"}" ++
      "else{s+=\"<circle cx='\"+sx(pt.x)+\"' cy='\"+sy(pt.y)+\"' r='3.5' fill='steelblue' opacity='0.8' data-idx='\"+pt.idx+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\"}" ++
    "});" ++
    "svg.innerHTML=s;bindPanel(panel)" ++
  "}"


private def dashJs3 : String :=
  "function renderHistogram(panel,state){" ++
    "var svg=document.getElementById(panel.svgId);if(!svg)return;" ++
    "var varName=panel.config.var||grpVars[0]||'';var hM={t:10,r:10,b:25,l:35};var hpw=PW-hM.l-hM.r,hph=PH-hM.t-hM.b;" ++
    "var pi=panel._idx;" ++
    "var s=\"<rect x='0' y='0' width='\"+PW+\"' height='\"+PH+\"' fill='transparent' class='bg' data-pi='\"+pi+\"'/>\";" ++
    "if(state.data.groups[varName]){" ++
      "var gs=state.data.groups[varName];var gNames=[];gs.forEach(function(g){if(gNames.indexOf(g)<0)gNames.push(g)});" ++
      "var barH=Math.min(35,hph/gNames.length-3);" ++
      "var counts=gNames.map(function(g){var c=0;for(var i=0;i<n;i++)if(gs[i]===g&&!state.points[i].hidden)c++;return c});" ++
      "var maxC=Math.max.apply(null,counts)||1;" ++
      "gNames.forEach(function(g,gi){" ++
        "var y=hM.t+gi*(barH+3);var w=counts[gi]/maxC*hpw;" ++
        "var anyS=false,anyE=false;for(var i=0;i<n;i++)if(gs[i]===g){if(state.points[i].selected)anyS=true;if(state.points[i].excluded)anyE=true}" ++
        "var fill=anyE?'grey':anyS?'orange':'steelblue';var op=anyE?0.3:0.7;" ++
        "s+=\"<rect x='\"+hM.l+\"' y='\"+y+\"' width='\"+w+\"' height='\"+barH+\"' fill='\"+fill+\"' opacity='\"+op+\"' data-grp='\"+g+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\";" ++
        "s+=\"<text x='\"+(hM.l-3)+\"' y='\"+(y+barH/2+4)+\"' text-anchor='end' font-size='10'>\"+g+\"</text>\";" ++
        "s+=\"<text x='\"+(hM.l+w+3)+\"' y='\"+(y+barH/2+4)+\"' font-size='9'>\"+counts[gi]+\"</text>\"" ++
      "});" ++
    "}else if(state.data.xs[varName]){" ++
      "var vals=state.data.xs[varName];var vis=[];for(var i=0;i<n;i++)if(!state.points[i].hidden)vis.push(vals[i]);" ++
      "if(vis.length<2){svg.innerHTML='';return}" ++
      "var vMin=Math.min.apply(null,vis),vMax=Math.max.apply(null,vis),vR=vMax-vMin||1;" ++
      "var bins=new Array(10).fill(0);var binIdx=new Array(n).fill(-1);" ++
      "for(var i=0;i<n;i++){if(state.points[i].hidden)continue;var v=vals[i];var b=Math.min(9,Math.floor((v-vMin)/vR*10));bins[b]++;binIdx[i]=b}" ++
      "var maxB=Math.max.apply(null,bins)||1;var barH=hph/10-2;" ++
      "for(var b=0;b<10;b++){" ++
        "var y=hM.t+b*(barH+2);var w=bins[b]/maxB*hpw;" ++
        "var anyS=false;for(var i=0;i<n;i++)if(binIdx[i]===b&&state.points[i].selected)anyS=true;" ++
        "var fill=anyS?'orange':'steelblue';" ++
        "s+=\"<rect x='\"+hM.l+\"' y='\"+y+\"' width='\"+w+\"' height='\"+barH+\"' fill='\"+fill+\"' opacity='0.6' data-bin='\"+b+\"' data-var='\"+varName+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\";" ++
        "var lo=vMin+b/10*vR;s+=\"<text x='\"+(hM.l-3)+\"' y='\"+(y+barH/2+4)+\"' text-anchor='end' font-size='9'>\"+lo.toPrecision(2)+\"</text>\"" ++
      "}" ++
    "}" ++
    "svg.innerHTML=s;bindPanel(panel)" ++
  "}" ++
  "function renderAvplot(panel,state){" ++
    "var svg=document.getElementById(panel.svgId);if(!svg)return;" ++
    "var pred=panel.config.predictor||numVars[0];var others=numVars.filter(function(v){return v!==pred});" ++
    "var pi=panel._idx;" ++
    "var idx=[];for(var i=0;i<n;i++)if(!state.points[i].excluded&&!state.points[i].hidden)idx.push(i);" ++
    "if(idx.length<3||others.length<1){svg.innerHTML='<text x=\"150\" y=\"125\" text-anchor=\"middle\" font-size=\"11\">Need more data</text>';return}" ++
    "var X=idx.map(function(i){var row=[1];others.forEach(function(v){row.push(state.data.xs[v][i])});return row});" ++
    "var yv=idx.map(function(i){return state.data.y[i]});var xv=idx.map(function(i){return state.data.xs[pred][i]});" ++
    "var bY=fitOLS(X,yv);var bX=fitOLS(X,xv);" ++
    "if(!bY||!bX){svg.innerHTML='';return}" ++
    "var resY=idx.map(function(i,k){var yh=0;X[k].forEach(function(v,j){yh+=bY[j]*v});return yv[k]-yh});" ++
    "var resX=idx.map(function(i,k){var xh=0;X[k].forEach(function(v,j){xh+=bX[j]*v});return xv[k]-xh});" ++
    "var xMin=Math.min.apply(null,resX),xMax=Math.max.apply(null,resX),yMin=Math.min.apply(null,resY),yMax=Math.max.apply(null,resY);" ++
    "var xR2=xMax-xMin||1,yR2=yMax-yMin||1;" ++
    "var sx=function(v){return(v-xMin)/xR2*pw+M.l};var sy=function(v){return PH-M.b-(v-yMin)/yR2*ph};" ++
    "var s=\"<rect x='0' y='0' width='\"+PW+\"' height='\"+PH+\"' fill='transparent' class='bg' data-pi='\"+pi+\"'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+(PH-M.b)+\"' x2='\"+(M.l+pw)+\"' y2='\"+(PH-M.b)+\"' stroke='#333'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+M.t+\"' x2='\"+M.l+\"' y2='\"+(PH-M.b)+\"' stroke='#333'/>\";" ++
    "idx.forEach(function(oi,k){" ++
      "var st=state.points[oi];" ++
      "if(st.selected){s+=\"<circle cx='\"+sx(resX[k])+\"' cy='\"+sy(resY[k])+\"' r='4' fill='steelblue' stroke='orange' stroke-width='2' data-idx='\"+oi+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\"}" ++
      "else{s+=\"<circle cx='\"+sx(resX[k])+\"' cy='\"+sy(resY[k])+\"' r='3.5' fill='steelblue' opacity='0.8' data-idx='\"+oi+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\"}" ++
    "});" ++
    "svg.innerHTML=s;bindPanel(panel)" ++
  "}" ++
  "function renderResidual(panel,state){" ++
    "var svg=document.getElementById(panel.svgId);if(!svg)return;" ++
    "var pi=panel._idx;" ++
    "var idx=[];for(var i=0;i<n;i++)if(!state.points[i].excluded&&!state.points[i].hidden)idx.push(i);" ++
    "if(idx.length<3||numVars.length<1){svg.innerHTML='<text x=\"150\" y=\"125\" text-anchor=\"middle\" font-size=\"11\">Need more data</text>';return}" ++
    "var X=idx.map(function(i){var row=[1];numVars.forEach(function(v){row.push(state.data.xs[v][i])});return row});" ++
    "var yv=idx.map(function(i){return state.data.y[i]});" ++
    "var b=fitOLS(X,yv);if(!b){svg.innerHTML='';return}" ++
    "var fitted=idx.map(function(i,k){var yh=0;X[k].forEach(function(v,j){yh+=b[j]*v});return yh});" ++
    "var resid=idx.map(function(i,k){return yv[k]-fitted[k]});" ++
    "var xMin=Math.min.apply(null,fitted),xMax=Math.max.apply(null,fitted),yMin=Math.min.apply(null,resid),yMax=Math.max.apply(null,resid);" ++
    "var xR2=xMax-xMin||1,yR2=yMax-yMin||1;" ++
    "var sx=function(v){return(v-xMin)/xR2*pw+M.l};var sy=function(v){return PH-M.b-(v-yMin)/yR2*ph};" ++
    "var s=\"<rect x='0' y='0' width='\"+PW+\"' height='\"+PH+\"' fill='transparent' class='bg' data-pi='\"+pi+\"'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+(PH-M.b)+\"' x2='\"+(M.l+pw)+\"' y2='\"+(PH-M.b)+\"' stroke='#333'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+M.t+\"' x2='\"+M.l+\"' y2='\"+(PH-M.b)+\"' stroke='#333'/>\";" ++
    "s+=\"<line x1='\"+M.l+\"' y1='\"+sy(0)+\"' x2='\"+(M.l+pw)+\"' y2='\"+sy(0)+\"' stroke='#ccc' stroke-dasharray='4'/>\";" ++
    "idx.forEach(function(oi,k){" ++
      "var st=state.points[oi];" ++
      "if(st.selected){s+=\"<circle cx='\"+sx(fitted[k])+\"' cy='\"+sy(resid[k])+\"' r='4' fill='steelblue' stroke='orange' stroke-width='2' data-idx='\"+oi+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\"}" ++
      "else{s+=\"<circle cx='\"+sx(fitted[k])+\"' cy='\"+sy(resid[k])+\"' r='3.5' fill='steelblue' opacity='0.8' data-idx='\"+oi+\"' data-pi='\"+pi+\"' style='cursor:pointer'/>\"}" ++
    "});" ++
    "svg.innerHTML=s;bindPanel(panel)" ++
  "}"


private def dashJs4 : String :=
  -- Panel type registry
  "var panelTypes={" ++
    "scatter:{render:renderScatter,handleClick:null,getAnnotation:null}," ++
    "histogram:{render:renderHistogram,handleClick:null,getAnnotation:null}," ++
    "avplot:{render:renderAvplot,handleClick:null,getAnnotation:null}," ++
    "residual:{render:renderResidual,handleClick:null,getAnnotation:null}" ++
  "};" ++
  -- createPanel factory
  "function createPanel(type,config){" ++
    "var reg=panelTypes[type];if(!reg)return null;" ++
    "var panel={" ++
      "type:type," ++
      "config:config||{}," ++
      "svgId:'panel_'+panels.length," ++
      "_idx:panels.length," ++
      "render:function(state){reg.render(panel,state)}," ++
      "handleClick:function(e,state){return reg.handleClick?reg.handleClick(panel,e,state):null}," ++
      "getAnnotation:function(pointIdx,state){return reg.getAnnotation?reg.getAnnotation(panel,pointIdx,state):null}" ++
    "};" ++
    "return panel" ++
  "}" ++
  -- bindPanel: attaches click handlers to SVG elements within a panel
  "function bindPanel(panel){" ++
    "var svg=document.getElementById(panel.svgId);if(!svg)return;" ++
    "var pi=panel._idx;" ++
    "svg.querySelectorAll('[data-idx]').forEach(function(el){el.addEventListener('click',function(e){e.stopPropagation();var idx=parseInt(el.dataset.idx);if(e.shiftKey){sharedState.points[idx].selected=!sharedState.points[idx].selected}else{for(var i=0;i<n;i++)sharedState.points[i].selected=false;sharedState.points[idx].selected=true}drawAll();report('selection_changed')})});" ++
    "svg.querySelectorAll('.bg').forEach(function(el){el.addEventListener('click',function(e){if(e.target===el){for(var i=0;i<n;i++)sharedState.points[i].selected=false;drawAll();report('selection_changed')}})});" ++
    "svg.querySelectorAll('[data-grp]').forEach(function(el){el.addEventListener('click',function(e){e.stopPropagation();var g=el.dataset.grp;var varName=panel.config.var||grpVars[0];" ++
      "if(!e.shiftKey){for(var i=0;i<n;i++)sharedState.points[i].selected=false}" ++
      "var gs=sharedState.data.groups[varName];if(gs)for(var i=0;i<n;i++)if(gs[i]===g)sharedState.points[i].selected=true;" ++
      "drawAll();report('user_action',{action:'clicked_bar',group:g})})});" ++
    "svg.querySelectorAll('[data-bin]').forEach(function(el){el.addEventListener('click',function(e){e.stopPropagation();var b=parseInt(el.dataset.bin);var varName=el.dataset.var;" ++
      "var vals=sharedState.data.xs[varName];if(!vals)return;" ++
      "var vis=[];for(var i=0;i<n;i++)if(!sharedState.points[i].hidden)vis.push(vals[i]);" ++
      "var vMin=Math.min.apply(null,vis),vMax=Math.max.apply(null,vis),vR=vMax-vMin||1;" ++
      "if(!e.shiftKey){for(var i=0;i<n;i++)sharedState.points[i].selected=false}" ++
      "for(var i=0;i<n;i++){if(sharedState.points[i].hidden)continue;var bi=Math.min(9,Math.floor((vals[i]-vMin)/vR*10));if(bi===b)sharedState.points[i].selected=true}" ++
      "drawAll();report('selection_changed')})});" ++
  "}" ++
  -- drawAll iterates panels
  "function drawAll(){panels.forEach(function(panel){if(panel.type!=='removed')panel.render(sharedState)});drawLegend()}" ++
  -- addPanel: creates panel object and DOM, adds to panels array
  "function addPanel(type,config){" ++
    "var panel=createPanel(type,config);if(!panel)return;" ++
    "panels.push(panel);" ++
    "var div=document.createElement('div');div.className='panel';" ++
    "var hdr=document.createElement('div');hdr.className='panel-header';hdr.textContent=type+(config&&config.x?' ('+config.x+')':config&&config.var?' ('+config.var+')':config&&config.predictor?' ('+config.predictor+')':'');" ++
    "var svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.id=panel.svgId;svg.setAttribute('width',PW);svg.setAttribute('height',PH);" ++
    "var ctrl=document.createElement('div');ctrl.className='panel-ctrl';" ++
    "var idx=panel._idx;" ++
    "if(type==='scatter'){" ++
      "var sel='<select onchange=\"panels['+idx+'].config.x=this.value;drawAll()\">';numVars.forEach(function(v){sel+='<option'+(v===(config&&config.x||numVars[0])?' selected':'')+'>'+v+'</option>'});sel+='</select> ';" ++
      "sel+='<select onchange=\"panels['+idx+'].config.xform=this.value;drawAll()\"><option value=\"linear\">lin</option><option value=\"log\">log</option><option value=\"sqrt\">√</option><option value=\"recip\">1/x</option><option value=\"square\">x²</option></select> ';" ++
      "sel+='deg<select onchange=\"panels['+idx+'].config.degree=+this.value;drawAll()\"><option>1</option><option>2</option><option>3</option><option>4</option><option>5</option></select>';" ++
      "ctrl.innerHTML=sel" ++
    "}else if(type==='histogram'){" ++
      "var sel='<select onchange=\"panels['+idx+'].config.var=this.value;drawAll()\">';grpVars.concat(numVars).forEach(function(v){sel+='<option'+(v===(config&&config.var)?' selected':'')+'>'+v+'</option>'});sel+='</select>';" ++
      "ctrl.innerHTML=sel" ++
    "}" ++
    "div.appendChild(hdr);div.appendChild(svg);div.appendChild(ctrl);" ++
    "document.getElementById('dashPanels').appendChild(div);" ++
    "panel.render(sharedState)" ++
  "}" ++
  "function report(event,extra){" ++
    "var sel=[],exc=[];var nv=0;for(var i=0;i<n;i++){if(sharedState.points[i].selected)sel.push(i);if(sharedState.points[i].excluded)exc.push(i);if(!sharedState.points[i].hidden)nv++}" ++
    "var msg={event:event,selected:sel,excluded:exc,n_visible:nv};" ++
    "if(extra)Object.keys(extra).forEach(function(k){msg[k]=extra[k]});" ++
    "if(ws&&ws.readyState===1)ws.send(JSON.stringify(msg))" ++
  "}" ++
  "function drawLegend(){" ++
    "var el=document.getElementById('legend');var h='';" ++
    "sharedState.fits.forEach(function(spec,idx){var col=colors[idx%colors.length];h+='<span style=\"display:inline-block;width:18px;height:3px;background:'+col+';vertical-align:middle;margin-right:4px\"></span>Chk'+(idx+1)+' '});" ++
    "el.innerHTML=h" ++
  "}"


private def dashJs5 : String :=
  "var ws=null;try{ws=new WebSocket('ws://localhost:9147')}catch(e){}" ++
  "function handleCommand(msg){" ++
    "switch(msg.cmd){" ++
      "case'addVariable':if(msg.type==='group'){sharedState.data.groups[msg.name]=msg.values;grpVars.push(msg.name)}else{sharedState.data.xs[msg.name]=msg.values;numVars.push(msg.name)}break;" ++
      "case'addPanel':addPanel(msg.type,msg);break;" ++
      "case'removePanel':if(msg.id<panels.length){var el=document.getElementById(panels[msg.id].svgId);if(el&&el.parentNode)el.parentNode.parentNode.removeChild(el.parentNode);panels[msg.id]={type:'removed',config:{},svgId:'',_idx:msg.id,render:function(){},handleClick:function(){return null},getAnnotation:function(){return null}}}break;" ++
      "case'select':for(var i=0;i<n;i++)sharedState.points[i].selected=false;(msg.ids||[]).forEach(function(id){if(id<n)sharedState.points[id].selected=true});break;" ++
      "case'clearSelection':for(var i=0;i<n;i++)sharedState.points[i].selected=false;break;" ++
      "case'excludeSelected':for(var i=0;i<n;i++)if(sharedState.points[i].selected){sharedState.points[i].excluded=true;sharedState.points[i].selected=false}break;" ++
      "case'includeAll':for(var i=0;i<n;i++)sharedState.points[i].excluded=false;break;" ++
      "case'hideExcluded':for(var i=0;i<n;i++)if(sharedState.points[i].excluded)sharedState.points[i].hidden=true;break;" ++
      "case'showAll':for(var i=0;i<n;i++)sharedState.points[i].hidden=false;break;" ++
      "case'invertSelection':for(var i=0;i<n;i++)if(!sharedState.points[i].hidden)sharedState.points[i].selected=!sharedState.points[i].selected;break;" ++
      "case'checkpoint':doCheckpoint();break" ++
    "}" ++
    "drawAll();report('selection_changed')" ++
  "}" ++
  "if(ws){ws.onmessage=function(ev){handleCommand(JSON.parse(ev.data))}}" ++
  "function doCheckpoint(){" ++
    "panels.forEach(function(p,pi){" ++
      "if(p.type!=='scatter')return;" ++
      "var xVar=p.config.x||numVars[0];var xf=p.config.xform||'linear';var deg=p.config.degree||1;" ++
      "var xArr=sharedState.data.xs[xVar]||[];var fp=[];" ++
      "for(var i=0;i<n;i++){if(sharedState.points[i].excluded||sharedState.points[i].hidden)continue;var xt=tx(xArr[i],xf),yt=tx(sharedState.data.y[i],p.config.yform||'linear');if(!isNaN(xt)&&isFinite(xt)&&!isNaN(yt)&&isFinite(yt))fp.push({x:xt,y:yt})}" ++
      "if(fp.length<=deg)return;" ++
      "var coef=polyFit(fp.map(function(q){return q.x}),fp.map(function(q){return q.y}),deg);" ++
      "if(coef)sharedState.fits.push({coef:coef,panelIdx:pi})" ++
    "});" ++
    "drawAll();report('checkpoint',{panels:panels.length,fits:sharedState.fits.length})" ++
  "}" ++
  "document.getElementById('chkBtn').addEventListener('click',doCheckpoint);" ++
  "document.getElementById('clearBtn').addEventListener('click',function(){sharedState.fits.length=0;drawAll()});" ++
  "document.getElementById('invertBtn').addEventListener('click',function(){for(var i=0;i<n;i++)if(!sharedState.points[i].hidden)sharedState.points[i].selected=!sharedState.points[i].selected;drawAll();report('selection_changed')});" ++
  "document.getElementById('keepBtn').addEventListener('click',function(){" ++
    "var state={event:'keep',pointState:sharedState.points,fits:sharedState.fits,panels:panels};" ++
    "if(ws&&ws.readyState===1){ws.send(JSON.stringify(state));this.textContent='✓ Kept';var b=this;setTimeout(function(){b.textContent='📌 Keep'},1500)}" ++
  "});"


/-- Generate a self-contained HTML dashboard with dynamic panels, shared point state,
    and bidirectional WebSocket on port 9147. -/
def dashboard (ys : Array Float) (xs : Array (String × Array Float))
    (groups : Option (String × Array String) := none)
    (yName : String := "y") (title : String := "") : String :=
  let n := ys.size
  let yJson := "[" ++ String.intercalate "," (ys.toList.map toString) ++ "]"
  let xsJson := "{" ++ String.intercalate "," (xs.toList.map fun (name, vals) =>
    "\"" ++ name ++ "\":[" ++ String.intercalate "," (vals.toList.map toString) ++ "]") ++ "}"
  let grpJson := match groups with
    | some (gName, gVals) =>
      "{\"" ++ gName ++ "\":[" ++ String.intercalate "," (gVals.toList.map fun g => "\"" ++ g ++ "\"") ++ "]}"
    | none => "{}"
  let firstX := match xs.get? 0 with | some (name, _) => name | none => ""
  let initHistoVar := match groups with
    | some (gName, _) => gName
    | none => firstX
  let pageTitle := if title != "" then title else s!"{yName} Dashboard"
  let _ := n  -- used in data init
  s!"<!DOCTYPE html><html><head><meta charset='utf-8'><title>{pageTitle}</title>
<style>{dashCss}</style></head><body>
<h2>{pageTitle} <button id='keepBtn' style='background:#16a34a;color:#fff;border:none;border-radius:4px;padding:4px 8px;cursor:pointer;font-size:12px;vertical-align:middle'>📌 Keep</button></h2>
<div id='dashPanels' class='dashboard'></div>
<div class='toolbar'>
  <button id='chkBtn'>+ Checkpoint</button>
  <button id='clearBtn'>Clear</button>
  <button id='invertBtn'>Invert Selection</button>
</div>
<div id='legend' class='legend'></div>
<script>
var data = \{y:{yJson},xs:{xsJson},groups:{grpJson}};
{dashJs1}
{dashJs2}
{dashJs3}
{dashJs4}
{dashJs5}
addPanel('scatter',\{x:'{firstX}',degree:1,xform:'linear',yform:'linear'});
addPanel('histogram',\{var:'{initHistoVar}'});
</script></body></html>"

end LeanStats.Plot
