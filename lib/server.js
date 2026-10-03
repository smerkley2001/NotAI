import {createClient} from '@supabase/supabase-js';
import Stripe from 'stripe';
import {SUPABASE_URL,SUPABASE_KEY} from '../src/config.js';
export const canonicalOrigin='https://notaijusti.com';
export function db(){if(!process.env.SUPABASE_SERVICE_ROLE_KEY)throw Object.assign(new Error('Checkout setup is not complete.'),{status:503});return createClient(process.env.SUPABASE_URL||SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});}
export function publicDb(){return createClient(process.env.SUPABASE_URL||SUPABASE_URL,process.env.SUPABASE_PUBLISHABLE_KEY||SUPABASE_KEY,{auth:{persistSession:false}});}
export function gate(){if(process.env.NOTAI_CHECKOUT_ENABLED!=='true')throw Object.assign(new Error('Ordering is not open yet.'),{status:503});if(process.env.VERCEL_ENV==='preview'&&(process.env.NOTAI_PREVIEW_WRITES!=='true'||!process.env.SUPABASE_URL||process.env.SUPABASE_URL===SUPABASE_URL||!process.env.STRIPE_SECRET_KEY?.startsWith('sk_test_')))throw Object.assign(new Error('Preview purchases require an isolated test database and Stripe test key.'),{status:503});}
export function stripe(){if(!process.env.STRIPE_SECRET_KEY)throw Object.assign(new Error('Payments are not configured.'),{status:503});return new Stripe(process.env.STRIPE_SECRET_KEY);}
export async function authenticated(req){const token=req.headers.authorization?.match(/^Bearer (.+)$/)?.[1];if(!token)throw Object.assign(new Error('Sign in to continue.'),{status:401});const {data,error}=await publicDb().auth.getUser(token);if(error||!data.user||data.user.is_anonymous)throw Object.assign(new Error('Sign in to continue.'),{status:401});return data.user;}
export function respondError(res,e){const status=e.status||500;res.status(status).json({error:status<500||status===503?e.message:'We couldn’t complete that request. Please try again.'});}
export function noStore(res){res.setHeader('Cache-Control','no-store');}
export function validUuid(v){return typeof v==='string'&&/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(v);}

export function checkoutOrigin(){if(process.env.VERCEL_ENV!=='preview')return canonicalOrigin;const value=process.env.NOTAI_CHECKOUT_RETURN_ORIGIN;if(!value)throw Object.assign(new Error('Preview checkout return URL is not configured.'),{status:503});const url=new URL(value);if(url.protocol!=='https:'||!url.hostname.endsWith('.vercel.app')||url.username||url.password||url.pathname!=='/'||url.search||url.hash)throw Object.assign(new Error('Invalid preview return URL.'),{status:503});return url.origin;}
