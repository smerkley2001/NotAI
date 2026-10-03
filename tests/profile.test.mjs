import test from 'node:test';
import assert from 'node:assert/strict';
import {validateProfile,validatePassword,safeNext} from '../src/profile.js';
test('normalizes optional handle and keeps privacy explicit',()=>{
 assert.deepEqual(validateProfile({full_name:'  Steve  ',handle:'  Steve_M  ',network_visibility:'private'}),{full_name:'Steve',handle:'steve_m',network_visibility:'private'});
 assert.equal(validateProfile({full_name:'Steve',handle:'',network_visibility:'private'}).handle,null);
});
test('rejects invalid identity and privacy values',()=>{
 for(const change of [{full_name:' '},{handle:'a'},{handle:'<script>'},{network_visibility:'friends'}])assert.throws(()=>validateProfile({full_name:'Steve',handle:'steve',network_visibility:'private',...change}));
});
test('blocks external login redirect destinations',()=>{
 for(const path of ['https://evil.example','//evil.example','/\\evil.example','javascript:alert(1)'])assert.equal(safeNext(path),'/account.html');
 assert.equal(safeNext('/index.html'),'/index.html');
});
test('checks password length and confirmation',()=>{
 assert.throws(()=>validatePassword('short','short'));
 assert.throws(()=>validatePassword('long password','different password'));
 assert.equal(validatePassword('long password','long password'),'long password');
});

test('allows a gift return link with a fixed-format bearer token',()=>{assert.equal(safeNext('/gift/'+'a'.repeat(32)),'/gift/'+'a'.repeat(32));assert.equal(safeNext('/gift/../evil'),'/account.html');});
