import {spawn} from 'node:child_process';
const server=spawn('python3',['-m','http.server','4173','--bind','127.0.0.1','--directory','dist']);
await new Promise(r=>setTimeout(r,500));
process.on('exit',()=>server.kill());
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
const browser=await chromium.launch({...(process.env.CHROME_PATH ? {executablePath:process.env.CHROME_PATH}:{}),args:['--no-sandbox'],headless:true});
const context=await browser.newContext();const page=await context.newPage();
const errors=[];page.on('pageerror',e=>errors.push(e.message));
const user={id:'00000000-0000-4000-8000-000000000011',aud:'authenticated',role:'authenticated',email:'alice@example.invalid',email_confirmed_at:new Date().toISOString(),is_anonymous:false,app_metadata:{provider:'email'},user_metadata:{full_name:'Alice'},created_at:new Date().toISOString()};
let saved={id:'10000000-0000-4000-8000-000000000011',full_name:'Alice',handle:null,network_visibility:'private',archived_at:null};
const jwt=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')+'.'+Buffer.from(JSON.stringify({sub:user.id,exp:Math.floor(Date.now()/1000)+3600,role:'authenticated',is_anonymous:false})).toString('base64url')+'.test';
const session={access_token:jwt,refresh_token:'test-refresh',token_type:'bearer',expires_in:3600,expires_at:Math.floor(Date.now()/1000)+3600,user};
const requests=[];
await context.route('https://dompwdardnqvmoncawrk.supabase.co/**',async route=>{
 const r=route.request();const u=new URL(r.url());requests.push([r.method(),u.pathname]);
 let body={};
 if(u.pathname.endsWith('/signup'))body={user,session:null};
 else if(u.pathname.endsWith('/token'))body=session;
 else if(u.pathname.endsWith('/user'))body=user;
 else if(u.pathname.includes('/rest/v1/profiles')){
  if(r.method()==='PATCH'){saved={...saved,...r.postDataJSON()};body={id:saved.id};}
  else body=saved;
 }
 await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
});
await context.route('https://fonts.googleapis.com/**',r=>r.abort());
await page.goto('http://127.0.0.1:4173/signup.html');
await page.getByLabel('Your name').fill('Alice');await page.locator('#email-input').fill(user.email);
await page.getByLabel('Password',{exact:true}).fill('a secure password');await page.getByLabel('Confirm password').fill('a secure password');
await page.getByRole('button',{name:'Create my account'}).click();await page.getByRole('status').filter({hasText:'Check your inbox'}).waitFor();
await page.screenshot({path:'/tmp/notai-signup-desktop.png',fullPage:true});
await page.goto('http://127.0.0.1:4173/signin.html');await page.locator('#email-input').fill(user.email);await page.getByLabel('Password',{exact:true}).fill('a secure password');await page.getByRole('button',{name:'Sign in',exact:true}).click();
await page.waitForURL('**/account.html');await page.getByLabel('Your name').waitFor();
await page.getByLabel('Your name').fill('Alice Example');await page.getByLabel('Public handle').fill('Alice_Designs');await page.getByRole('button',{name:'Save profile'}).click();
await page.getByRole('status').filter({hasText:'Your profile is saved'}).waitFor();assert.equal(saved.handle,'alice_designs');assert.equal(saved.network_visibility,'private');
await page.screenshot({path:'/tmp/notai-account-desktop.png',fullPage:true});
await page.setViewportSize({width:390,height:844});await page.screenshot({path:'/tmp/notai-account-mobile.png',fullPage:true});
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
await page.getByRole('button',{name:'Sign out',exact:true}).click();await page.waitForURL('**/signin.html');
await page.goto('http://127.0.0.1:4173/account.html');await page.waitForURL('**/signin.html?next=/account.html');
await page.goto('http://127.0.0.1:4173/forgot-password.html');await page.getByLabel('Email address').fill(user.email);await page.getByRole('button',{name:'Send reset link'}).click();await page.getByRole('status').filter({hasText:'If an account exists'}).waitFor();
await page.goto('http://127.0.0.1:4173/reset-password.html');await page.getByRole('status').filter({hasText:'Open the password reset link'}).waitFor();assert.equal(await page.locator('#password-form').isVisible(),false);
assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:true,requests:requests.length,checks:['signup confirmation','sign in','profile load/save','private default','mobile width','sign out','protected page redirect','recovery request','expired/missing recovery link'],screenshots:['/tmp/notai-signup-desktop.png','/tmp/notai-account-desktop.png','/tmp/notai-account-mobile.png']}));await browser.close();server.kill();
