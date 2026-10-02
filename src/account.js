import {createClient} from '@supabase/supabase-js';
import {SUPABASE_URL,SUPABASE_KEY} from './config.js';
import {validateProfile,validatePassword,safeNext} from './profile.js';
const page=document.body.dataset.page;
const writesEnabled=__NOTAI_ACCOUNT_WRITES__;
const client=createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{flowType:'implicit',persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);
const status=$('status');
let user=null,profile=null;
let recovery=false;
const initialHash=new URLSearchParams(location.hash.slice(1));
const recoveryLink=initialHash.get('type')==='recovery';
const next=safeNext(new URLSearchParams(location.search).get('next'));
const redirect=path=>new URL(path,location.origin).href;
function message(text,error=false){status.textContent=text;status.className=error?'message error':'message';status.focus();}
function routeLogin(){location.replace('/signin.html?next=/account.html');}
function errorText(error){
 if(error?.code==='23505') return 'That handle is already in use. Please choose another.';
 if(error?.code==='42501') return 'Your profile could not be saved. Please sign in again or try later.';
 if(error?.status===429) return 'Too many attempts. Please wait a few minutes and try again.';
 return error?.message||'Something went wrong. Please try again.';
}
function bind(id,handler){const form=$(id);if(!form)return;form.addEventListener('submit',async e=>{
 e.preventDefault();if(!writesEnabled){message('This preview is for reviewing the pages. Account changes are disabled.');return;}const button=form.querySelector('[type=submit]');const label=button.textContent;
 button.disabled=true;button.textContent='Please wait…';status.textContent='';
 try{await handler(new FormData(form));}catch(error){message(errorText(error),true);}
 finally{button.disabled=false;button.textContent=label;}
});}
async function currentUser(){const {data,error}=await client.auth.getUser();if(error||!data.user||data.user.is_anonymous)return null;return data.user;}
async function loadProfile(){
 const {data,error}=await client.from('profiles').select('id,full_name,handle,network_visibility,archived_at').eq('auth_user_id',user.id).maybeSingle();
 if(error)throw error;profile=data;
 if(data?.archived_at)throw new Error('This account is archived. Contact support to restore access.');
 $('full-name').value=data?.full_name||user.user_metadata?.full_name||'';
 $('handle').value=data?.handle||'';
 $('visibility').checked=data?.network_visibility==='public';
 $('email').textContent=user.email||'Email unavailable';
 $('greeting').textContent=data?.full_name?`Hello, ${data.full_name}.`:'Make yourself at home.';
 $('profile-form').hidden=false;
 $('account-content').hidden=false;
 if(!data)message('Finish your profile to get ready for your first design.');
}
bind('signup-form',async f=>{
 const password=validatePassword(f.get('password'),f.get('confirm'));
 const name=validateProfile({full_name:f.get('name'),handle:'',network_visibility:'private'}).full_name;
 const {data,error}=await client.auth.signUp({email:String(f.get('email')).trim(),password,options:{data:{full_name:name},emailRedirectTo:redirect('/account.html')}});
 if(error)throw error;
 if(data.session){location.assign('/account.html');return;}
 $('signup-form').reset();message('Check your inbox for a confirmation link. If you already have an account, sign in or reset your password.');
});
bind('signin-form',async f=>{
 const {error}=await client.auth.signInWithPassword({email:String(f.get('email')).trim(),password:f.get('password')});
 if(error)throw new Error('We could not sign you in. Check your email and password, and confirm your email if needed.');
 location.assign(next);
});
bind('forgot-form',async f=>{
 const {error}=await client.auth.resetPasswordForEmail(String(f.get('email')).trim(),{redirectTo:redirect('/reset-password.html')});
 if(error)throw error;message('If an account exists for that email, you’ll receive a password reset link.');
});
bind('resend-form',async f=>{
 const {error}=await client.auth.resend({type:'signup',email:String(f.get('email')).trim(),options:{emailRedirectTo:redirect('/account.html')}});
 if(error)throw error;message('If confirmation is needed, a new link has been requested. Check your inbox.');
});
bind('profile-form',async f=>{
 user=await currentUser();if(!user){routeLogin();return;}
 const fields=validateProfile({full_name:f.get('name'),handle:f.get('handle'),network_visibility:f.has('visibility')?'public':'private'});
 let result;
 if(profile)result=await client.from('profiles').update(fields).eq('id',profile.id).eq('auth_user_id',user.id).select('id').single();
 else result=await client.from('profiles').insert({...fields,auth_user_id:user.id}).select('id').single();
 if(result.error)throw result.error;
 await loadProfile();message('Your profile is saved.');
});
bind('password-form',async f=>{
 const password=validatePassword(f.get('password'),f.get('confirm'));
 user=await currentUser();if(!user)throw new Error('This session has expired. Request a new password reset link.');
 if(page==='reset'&&!recovery)throw new Error('Open the password reset link from your email first.');
 if(page==='account'){
  const {error}=await client.auth.signInWithPassword({email:user.email,password:f.get('current-password')});
  if(error)throw new Error('Your current password is incorrect.');
 }
 const {error}=await client.auth.updateUser({password});if(error)throw error;
 $('password-form').reset();
 const {error:logoutError}=await client.auth.signOut({scope:'global'});
 if(logoutError){message('Password updated. Please sign out and sign in again.');return;}
 recovery=false;message('Password updated. Sign in again with your new password.');
 $('password-form').hidden=true;$('signin-again').hidden=false;
 if(page==='account')location.assign('/signin.html');
});
$('signout')?.addEventListener('click',async()=>{
 const {error}=await client.auth.signOut();if(error){message(errorText(error),true);return;}
 location.replace('/signin.html');
});
client.auth.onAuthStateChange((event,session)=>{
 if(event==='PASSWORD_RECOVERY') {recovery=true;if(page==='reset'){$('password-form').hidden=false;status.textContent='Choose a new password.';}}
 if(event==='SIGNED_OUT'&&page==='account'){$('account-content').hidden=true;}
 // No awaited Supabase calls inside this callback (avoids auth lock deadlocks).
});
async function initialize(){
 if(!writesEnabled)message('This preview is for reviewing the pages. Account changes are disabled.');
 if(initialHash.get('error')){message('This email link is invalid or has expired. Request a new link.',true);history.replaceState(null,'',location.pathname);return;}
 const {data}=await client.auth.getSession();
 user=await currentUser();
 if(page==='account'){
  if(!user){routeLogin();return;}
  await loadProfile();
 }
 if(page==='reset'){
  recovery=recovery||Boolean(recoveryLink&&data.session&&user);
  $('password-form').hidden=!recovery;
  if(!recovery)message('Open the password reset link from your email, or request a new one below.');
 }
 if(user&&['signin','signup'].includes(page))location.replace('/account.html');
 if(location.hash)history.replaceState(null,'',location.pathname+location.search);
}
initialize().catch(error=>message(errorText(error),true));
