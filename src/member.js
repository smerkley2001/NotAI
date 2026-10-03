import {createClient} from '@supabase/supabase-js';
import {SUPABASE_URL,SUPABASE_KEY} from './config.js';
export const client=createClient(SUPABASE_URL,SUPABASE_KEY);
export const writesEnabled=__NOTAI_ACCOUNT_WRITES__;
export function requireWrites(){if(!writesEnabled)throw new Error('This preview is for reviewing the pages. Changes are disabled.');}
export async function member(){
 const {data,error}=await client.auth.getUser();
 if(error||!data.user||data.user.is_anonymous)return null;
 const p=await client.from('profiles').select('id,full_name,handle,archived_at').eq('auth_user_id',data.user.id).maybeSingle();
 if(p.error)throw p.error;
 return {user:data.user,profile:p.data?.archived_at?null:p.data};
}
export function notify(text,error=false){const s=document.getElementById('status');if(s){s.textContent=text;s.className=error?'message error':'message';}}
export function login(path='/designs.html'){location.assign('/signin.html?next='+encodeURIComponent(path));}
export function fail(error){notify(error.code==='40001'?'This design changed in another tab. Reload it, or save a copy to keep your changes.':error.message||'Please try again.',true);}
