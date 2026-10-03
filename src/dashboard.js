import {client,member,requireWrites,notify,login,fail,writesEnabled} from './member.js';
import {icons,fonts,money,uuidPattern,validateDesign} from './design-model.js';
const mode=document.body.dataset.page;const list=document.getElementById('items');let archived=false,offset=0;
function el(tag,text,className){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;}
function link(text,href){const a=el('a',text,'secondary');a.href=href;return a;}
async function act(button,fn){button.disabled=true;try{await fn();}catch(e){fail(e);}finally{button.disabled=false;}}
function preview(d){const wrap=el('div',undefined,'design-preview');const img=el('img');img.src=`/shirt-${d.shirt_color}-front.png`;img.alt=`${d.shirt_color} shirt design`;wrap.append(img);const art=el('div',undefined,'mini-art');art.style.color=d.shirt_color==='white'?'#111':'#fff';art.style.fontFamily=fonts[d.font_key];const headline=el('strong');headline.append(el('div','Not AI,'));const second=el('div','Just ');const accent=el('b','I.');accent.style.color=d.accent_color;second.append(accent);headline.append(second);art.append(headline);const lines=el('div');lines.append(el('div',d.line1),el('div',d.line2));art.append(lines);const icon=el('span',icons[d.icon_key]);icon.style.color=d.accent_color;art.append(icon);wrap.append(art);return wrap;}
async function designs(){
 const r=await client.rpc('list_my_designs',{p_archived:archived,p_offset:offset});if(r.error)throw r.error;
 const rows=r.data||[];if(offset===0)list.replaceChildren();
 if(!rows.length&&offset===0){list.append(el('p',archived?'Your archive is empty.':'No saved designs yet. Make your first one.','empty'));}
 for(const d of rows){const card=el('article',undefined,'card design-card');if(d.revision)card.append(preview(d.revision));card.append(el('h2',d.name),el('p',`Version ${d.revision?.revision_number||0} · ${new Date(d.updated_at).toLocaleDateString()}`,'meta'));
 const buttons=el('div',undefined,'card-actions');if(!archived)buttons.append(link('Edit design','/index.html?design='+d.id));
 const duplicate=el('button','Duplicate','secondary');duplicate.onclick=()=>act(duplicate,async()=>{requireWrites();const result=await client.rpc('save_design',{p_design_id:null,p_expected_revision:0,p_name:d.name.slice(0,113)+' (copy)',p_design:validateDesign(d.revision)});if(result.error)throw result.error;archived=false;offset=0;document.getElementById('archive-toggle').checked=false;await designs();notify('A new copy is saved in your designs.');});
 const archive=el('button',archived?'Restore':'Archive','secondary');archive.onclick=()=>act(archive,async()=>{requireWrites();const result=await client.rpc('archive_design',{p_design_id:d.id,p_archived:!archived});if(result.error)throw result.error;offset=0;await designs();notify(archived?'Design restored.':'Design archived. You can restore it anytime.');});buttons.append(duplicate,archive);card.append(buttons);list.append(card);}
 document.getElementById('load-more').hidden=rows.length<24;
}
async function orders(){
 const r=await client.from('orders').select('id,order_number,created_at,payment_status,fulfillment_status,total_minor,currency').order('created_at',{ascending:false}).range(offset,offset+23);if(r.error)throw r.error;
 if(offset===0)list.replaceChildren();if(!r.data.length&&offset===0)list.append(el('p','Your order history will appear here after your first purchase.','empty'));
 for(const o of r.data){const c=el('article',undefined,'card');c.append(el('h2',`Order #${o.order_number}`),el('p',`${new Date(o.created_at).toLocaleDateString()} · ${money(o.total_minor,o.currency)}`),el('p',`Payment: ${o.payment_status.replaceAll('_',' ')} · ${o.fulfillment_status.replaceAll('_',' ')}`,'meta'),link('View order','/order.html?id='+o.id));list.append(c);}document.getElementById('load-more').hidden=r.data.length<24;
}
async function order(){
 const id=new URLSearchParams(location.search).get('id');if(!uuidPattern.test(id||''))throw new Error('Choose an order from your order history.');
 const [o,i,s]=await Promise.all([client.from('orders').select('order_number,created_at,payment_status,fulfillment_status,subtotal_minor,shipping_minor,tax_minor,discount_minor,credit_minor,total_minor,currency').eq('id',id).single(),client.from('order_items').select('quantity,unit_price_minor,product_snapshot,personalization_snapshot').eq('order_id',id),client.from('shipments').select('carrier,tracking_number,shipped_at,delivered_at').eq('order_id',id)]);
 if(o.error)throw new Error('We couldn’t find that order in your account.');if(i.error)throw i.error;if(s.error)throw s.error;
 list.replaceChildren();document.getElementById('page-title').textContent=`Order #${o.data.order_number}`;
 const details=el('section',undefined,'card');details.append(el('h2','Order summary'),el('p',`${o.data.payment_status.replaceAll('_',' ')} · ${o.data.fulfillment_status.replaceAll('_',' ')}`));
 for(const [key,label] of [['subtotal_minor','Items'],['shipping_minor','Shipping'],['tax_minor','Tax'],['discount_minor','Discount'],['credit_minor','Store credit used'],['total_minor','Total']])details.append(el('p',label+': '+money(o.data[key],o.data.currency)));list.append(details);
 for(const item of i.data){const card=el('section',undefined,'card');card.append(el('h2',item.product_snapshot.product_name||'Personalized shirt'),el('p',`Quantity ${item.quantity} · ${money(item.unit_price_minor,o.data.currency)} each`),el('p',item.personalization_snapshot.line1||''),el('p',item.personalization_snapshot.line2||''));list.append(card);}
 for(const shipment of s.data){const card=el('section',undefined,'card');card.append(el('h2','Shipment'),el('p',`${shipment.carrier||'Carrier pending'} · ${shipment.tracking_number||'Tracking pending'}`));list.append(card);}
}
async function credits(){
 // Balances are grouped per currency; no conversion between currencies.
 const entries=[];let start=0;while(true){const page=await client.from('credit_ledger').select('id,amount_minor,currency,kind,created_at').order('created_at',{ascending:true}).order('id',{ascending:true}).range(start,start+499);if(page.error)throw page.error;entries.push(...page.data);if(page.data.length<500)break;start+=500;}const r={data:entries};
 list.replaceChildren();const balance=new Map();for(const e of r.data)balance.set(e.currency,(balance.get(e.currency)||0)+Number(e.amount_minor));
 if(!r.data.length){list.append(el('section','No referral credits yet. Qualifying referral credits and their history will appear here.','card'));return;}
 for(const [currency,amount] of balance){const c=el('section',undefined,'card');c.append(el('h2',money(amount,currency)),el('p','Recorded store credit balance'));list.append(c);}
 for(const e of [...r.data].reverse()){const row=el('article',undefined,'card');row.append(el('strong',`${money(e.amount_minor,e.currency)} · ${e.kind}`),el('p',new Date(e.created_at).toLocaleString(),'meta'));list.append(row);}
}
async function network(){const r=await client.from('shirts').select('id,qr_state,created_at').order('created_at',{ascending:false}).range(offset,offset+23);if(r.error)throw r.error;if(offset===0)list.replaceChildren();if(!r.data.length&&offset===0)list.append(el('p','Your purchased shirts will appear here. Each shirt will have its own QR identity.','empty'));for(const shirt of r.data){const c=el('article',undefined,'card');c.append(el('h2','Your shirt'),el('p',new Date(shirt.created_at).toLocaleDateString()),el('p','QR status: '+shirt.qr_state));list.append(c);}document.getElementById('load-more').hidden=r.data.length<24;}
document.getElementById('archive-toggle')?.addEventListener('change',e=>{archived=e.target.checked;offset=0;designs().catch(fail);});
document.getElementById('load-more')?.addEventListener('click',async e=>{offset+=24;await act(e.target,()=>mode==='designs'?designs():mode==='network'?network():orders());});
async function init(){const account=await member();if(!account){login(mode==='order'?'/orders.html':location.pathname);return;}if(!account.profile){notify('Finish your account profile first.','error');list.append(link('Complete my profile','/account.html'));return;}if(!writesEnabled)notify('Preview only. Design changes are disabled.');await ({designs,orders,order,credits,network}[mode])();}
init().catch(fail);
