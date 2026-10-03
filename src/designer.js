import {client,member,requireWrites,notify,login,fail,writesEnabled} from './member.js';
import {icons,fonts,validateDesign,validateName,uuidPattern} from './design-model.js';
let current=null,revision=0,dirty=false,loading=false,account=null;
const name=document.getElementById('design-name');
const save=document.getElementById('save-design');
const copy=document.getElementById('save-copy');
const restore=document.getElementById('restore-revision');
const history=document.getElementById('design-history');
const revisionSelect=document.getElementById('revision-select');
function payload(){const d=window.notaiDesigner.read();return validateDesign({line1:d.line1,line2:d.line2,icon_key:Object.keys(icons).find(k=>icons[k]===d.symbol),font_key:Object.keys(fonts).find(k=>fonts[k]===d.font),accent_color:d.accent,shirt_color:d.shirt});}
function apply(d){loading=true;window.notaiDesigner.apply({line1:d.line1,line2:d.line2,symbol:icons[d.icon_key],font:fonts[d.font_key],accent:d.accent_color,shirt:d.shirt_color});loading=false;}
async function load(id){
 const d=await client.from('designs').select('id,name,archived_at').eq('id',id).single();if(d.error)throw new Error('We couldn’t find that design in your account.');
 if(d.data.archived_at)throw new Error('Restore this design from your archive before editing.');
 const r=await client.from('design_revisions').select('*').eq('design_id',id).order('revision_number',{ascending:false});if(r.error)throw r.error;
 if(!r.data.length)throw new Error('No saved revision found.');
 current=id;revision=r.data[0].revision_number;name.value=d.data.name;apply(r.data[0]);dirty=false;
 revisionSelect.replaceChildren();for(const rev of r.data){const opt=document.createElement('option');opt.value=rev.id;opt.textContent=`Version ${rev.revision_number} · ${new Date(rev.created_at).toLocaleString()}`;opt.dataset.design=JSON.stringify(validateDesign(rev));revisionSelect.append(opt);}
 history.hidden=false;copy.hidden=false;notify(`Saved version ${revision}.`);
}
async function persist(asCopy=false,draft=null){
 requireWrites();const d=draft||payload();const n=validateName(name.value);
 account=await member();if(!account){sessionStorage.setItem('notai-unsaved-design',JSON.stringify({name:n,design:d}));dirty=false;login('/index.html');return;}
 if(!account.profile){notify('Finish your account profile before saving. Use My account above.',true);return;}
 save.disabled=true;copy.disabled=true;restore.disabled=true;
 try{const result=await client.rpc('save_design',{p_design_id:asCopy?null:current,p_expected_revision:asCopy?0:revision,p_name:asCopy?validateName(n.slice(0,113)+' (copy)'):n,p_design:d});if(result.error)throw result.error;
 sessionStorage.removeItem('notai-unsaved-design');await load(result.data.design_id);historyReplace(result.data.design_id);notify(asCopy?'Your copy is saved.':`Design saved as version ${result.data.revision_number}.`);
 }finally{save.disabled=false;copy.disabled=false;restore.disabled=false;}
}
function historyReplace(id){window.history.replaceState(null,'','/index.html?design='+id);}
save.addEventListener('click',()=>persist().catch(fail));copy.addEventListener('click',()=>persist(true).catch(fail));
restore.addEventListener('click',()=>{const selected=revisionSelect.selectedOptions[0];if(selected)persist(false,JSON.parse(selected.dataset.design)).then(()=>notify('Earlier design restored as a new version.')).catch(fail);});
window.addEventListener('notai:design-changed',()=>{if(!loading){dirty=true;notify('You have unsaved changes.');}});name.addEventListener('input',()=>{dirty=true;});
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
async function init(){
 if(!writesEnabled)notify('This preview is for reviewing the pages. Changes are disabled.');
 account=await member();const id=new URLSearchParams(location.search).get('design');
 if(id){if(!uuidPattern.test(id))throw new Error('Invalid design link.');if(!account){login('/designs.html');return;}await load(id);}
 else {const saved=sessionStorage.getItem('notai-unsaved-design');if(saved){try{const d=JSON.parse(saved);name.value=validateName(d.name);apply(validateDesign(d.design));dirty=true;notify('Your unsaved idea is back. Save it when you’re ready.');}catch{sessionStorage.removeItem('notai-unsaved-design');}}}
}
init().catch(fail);
