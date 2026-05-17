/-! # LeanStat.Report.Tooltip — tooltip and modal JS/CSS for HTML reports

Helpers for adding interactive tooltips and click-to-drill-down modals
to generated HTML reports. Pure: produces CSS and JS as strings, the
consumer embeds them in a report.
-/

set_option autoImplicit false

namespace LeanStat.Report

/-- CSS for tooltips and modal dialogs. -/
def tooltipCss : String :=
  ".tooltip{position:absolute;background:#222;color:#fff;padding:6px 10px;" ++
  "border-radius:4px;font-size:13px;pointer-events:none;z-index:1000;max-width:300px}" ++
  ".modal-overlay{position:fixed;top:0;left:0;width:100%;height:100%;" ++
  "background:rgba(0,0,0,0.5);display:flex;align-items:center;justify-content:center;z-index:2000}" ++
  ".modal{background:#fff;padding:24px;border-radius:8px;max-width:600px;width:90%;max-height:80vh;overflow:auto}"

/-- JS for hover tooltips and click drill-down modals. -/
def tooltipJs : String :=
  "document.addEventListener('DOMContentLoaded',function(){" ++
  "var tip=document.createElement('div');tip.className='tooltip';tip.style.display='none';document.body.appendChild(tip);" ++
  "function showTooltip(e,text){tip.textContent=text;tip.style.display='block';tip.style.left=e.pageX+10+'px';tip.style.top=e.pageY+10+'px'}" ++
  "function hideTooltip(){tip.style.display='none'}" ++
  "document.querySelectorAll('[data-tooltip]').forEach(function(el){" ++
  "el.addEventListener('mouseenter',function(e){showTooltip(e,el.dataset.tooltip)});" ++
  "el.addEventListener('mousemove',function(e){tip.style.left=e.pageX+10+'px';tip.style.top=e.pageY+10+'px'});" ++
  "el.addEventListener('mouseleave',hideTooltip)});" ++
  "document.querySelectorAll('[data-detail]').forEach(function(el){" ++
  "el.style.cursor='pointer';" ++
  "el.addEventListener('click',function(){" ++
  "var ov=document.createElement('div');ov.className='modal-overlay';" ++
  "var m=document.createElement('div');m.className='modal';m.innerHTML='<p>'+el.dataset.detail+'</p><button onclick=\"this.parentElement.parentElement.remove()\">Close</button>';" ++
  "ov.appendChild(m);document.body.appendChild(ov);" ++
  "ov.addEventListener('click',function(e){if(e.target===ov)ov.remove()})})});" ++
  "})"

end LeanStat.Report
