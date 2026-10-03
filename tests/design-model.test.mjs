import test from 'node:test';import assert from 'node:assert/strict';
import {validateDesign,validateName} from '../src/design-model.js';
const design={line1:'Hello',line2:'Human',icon_key:'soccer',font_key:'modern',shirt_color:'black',accent_color:'#22b8ff'};
test('saved personalization validates supported choices and Unicode length',()=>{assert.deepEqual(validateDesign(design),design);assert.doesNotThrow(()=>validateDesign({...design,line1:'😀'.repeat(32)}));assert.throws(()=>validateDesign({...design,line1:'😀'.repeat(33)}));for(const change of [{font_key:'unknown'},{icon_key:'<script>'},{shirt_color:'red'},{accent_color:'javascript:alert(1)'},{line1:null}])assert.throws(()=>validateDesign({...design,...change}));});
test('design names reject blank and overlong values',()=>{assert.equal(validateName(' Idea '),'Idea');assert.throws(()=>validateName(' '));assert.throws(()=>validateName('x'.repeat(121)));});
