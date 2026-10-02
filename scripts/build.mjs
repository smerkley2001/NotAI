import { build } from 'esbuild';
import { mkdir, copyFile, readdir } from 'node:fs/promises';
await mkdir('dist/assets', { recursive:true });
await build({entryPoints:['src/account.js'],bundle:true,minify:true,format:'esm',outfile:'dist/assets/account.js',target:['es2022'],define:{__NOTAI_ACCOUNT_WRITES__:JSON.stringify(process.env.VERCEL_ENV!=='preview')}});
for(const file of await readdir('.')) if(file.endsWith('.html') || file.endsWith('.png')) await copyFile(file,`dist/${file}`);
await copyFile('assets/account.css','dist/assets/account.css');
