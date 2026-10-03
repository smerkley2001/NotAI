export const icons={soccer:'⚽',volleyball:'🏐',basketball:'🏀',guitar:'🎸',art:'🎨',paw:'🐾',books:'📚',star:'⭐',heart:'❤️',gaming:'🎮'};
export const fonts={modern:'Arial',classic:'Georgia','tech-mono':'Courier New',friendly:'Trebuchet MS',clean:'Verdana'};
export const uuidPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function validateDesign(d){
 if(!d||typeof d!=='object')throw new Error('Invalid design.');
 for(const k of ['line1','line2'])if(typeof d[k]!=='string'||Array.from(d[k]).length>32)throw new Error('Each line can have up to 32 characters.');
 if(!Object.hasOwn(icons,d.icon_key)||!Object.hasOwn(fonts,d.font_key)||!['black','charcoal','navy','white'].includes(d.shirt_color)||!/^#[0-9a-f]{6}$/i.test(d.accent_color))throw new Error('Choose a supported font, symbol, and shirt color.');
 return Object.fromEntries(['line1','line2','icon_key','font_key','shirt_color','accent_color'].map(k=>[k,d[k]]));
}
export function validateName(name){const n=String(name||'').trim();if(!n||n.length>120)throw new Error('Give your design a name (up to 120 characters).');return n;}
export function money(amount,currency='USD'){return new Intl.NumberFormat('en-US',{style:'currency',currency}).format(Number(amount)/100);}
