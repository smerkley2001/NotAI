import {validateDesign,validateName} from './design-model.js';
import {validateProfile} from './profile.js';
const key='notai-browser-drafts-v1';
export function readDrafts(){try{const d=JSON.parse(localStorage.getItem(key));if(d?.version===1&&Array.isArray(d.designs))return d;}catch{}return {version:1,profile:{full_name:'',handle:null,network_visibility:'private'},designs:[],imports:{}};}
export function storeDrafts(d){try{localStorage.setItem(key,JSON.stringify(d));}catch{throw new Error('Browser storage is unavailable or full. Your changes could not be saved.');}}
export function demoActive(){return sessionStorage.getItem('notai-demo')==='true';}
export function startDemo(){sessionStorage.setItem('notai-demo','true');location.assign('/try.html');}
export function stopDemo(){sessionStorage.removeItem('notai-demo');}
export function saveDraft(id,name,design){const data=readDrafts();let d=data.designs.find(x=>x.id===id);if(!d){if(data.designs.length>=50)throw new Error('Keep up to 50 browser drafts. Remove a draft to make room.');d={id:crypto.randomUUID(),versions:[],archived:false};data.designs.push(d);}d.name=validateName(name);d.versions.push({...validateDesign(design),saved_at:new Date().toISOString()});storeDrafts(data);return d;}
export function saveGuestProfile(fields){const d=readDrafts();d.profile=validateProfile(fields);storeDrafts(d);}
export function demoEntry(){if(document.getElementById('try-entry'))return;const a=document.createElement('a');a.id='try-entry';a.href='/try.html';a.textContent='Try without signing in';a.className='secondary';(document.querySelector('header nav')||document.querySelector('.hero')||document.querySelector('main')||document.querySelector('.wrap')||document.body).append(a);}
export function demoBanner(){const b=document.createElement('section');b.className='card';b.style.cssText='padding:16px;margin:16px auto;max-width:1100px;background:#eef8fa;color:#17323b;border-radius:12px';b.innerHTML='<strong>Browser demo</strong><p>Your drafts stay in this browser. Orders, credits, network connections and sharing require an account.</p><a href="/try.html">Explore my demo account</a> · <a href="/signup.html" id="keep-drafts">Create an account and keep my designs</a>';(document.querySelector('main')||document.querySelector('.wrap')||document.body).prepend(b);b.querySelector('#keep-drafts').onclick=stopDemo;}
