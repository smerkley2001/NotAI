import { build } from 'esbuild';
import { mkdir, copyFile, readdir, readFile, writeFile } from 'node:fs/promises';
if(process.env.SUPABASE_PUBLISHABLE_KEY&&!process.env.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_'))throw new Error('Only a publishable Supabase key may enter the browser build.');
await mkdir('dist/assets', { recursive:true });
await build({entryPoints:['src/account.js','src/designer.js','src/dashboard.js','src/customer.js','src/sizes.js','src/fulfillment.js','src/try.js','src/navigation.js'],bundle:true,minify:true,format:'esm',outdir:'dist/assets',target:['es2022'],define:{__NOTAI_ACCOUNT_WRITES__:JSON.stringify(process.env.VERCEL_ENV!=='preview'||(process.env.NOTAI_PREVIEW_WRITES==='true'&&Boolean(process.env.SUPABASE_URL)&&process.env.SUPABASE_URL!=='https://dompwdardnqvmoncawrk.supabase.co'&&Boolean(process.env.SUPABASE_PUBLISHABLE_KEY))),__PUBLIC_SUPABASE_URL__:JSON.stringify(process.env.SUPABASE_URL||'https://dompwdardnqvmoncawrk.supabase.co'),__PUBLIC_SUPABASE_KEY__:JSON.stringify(process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_1pNxNX-UvYcKA86KOVvZyA_r9BpoyJ3')}});
for(const file of await readdir('.')) { if(file.endsWith('.html')) {let html=await readFile(file,'utf8');if(!['Index.html','index-3.html'].includes(file))html=html.replace('</head>',"<link rel='stylesheet' href='/assets/navigation.css'><link rel='stylesheet' href='/assets/theme.css'><script type='module' src='/assets/navigation.js'></script></head>");await writeFile(`dist/${file}`,html);}else if(file.endsWith('.png'))await copyFile(file,`dist/${file}`);}
await copyFile('assets/account.css','dist/assets/account.css');

await copyFile('assets/navigation.css','dist/assets/navigation.css');

await copyFile('assets/theme.css','dist/assets/theme.css');
