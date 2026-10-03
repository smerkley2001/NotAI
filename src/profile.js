export function validateProfile({full_name,handle,network_visibility}) {
 const name=String(full_name||'').trim();
 const username=String(handle||'').trim().toLowerCase();
 if(!name || name.length>200) throw new Error('Enter your name (up to 200 characters).');
 if(username && !/^[a-z0-9_]{3,30}$/.test(username)) throw new Error('Your handle needs 3–30 letters, numbers, or underscores.');
 if(!['private','public'].includes(network_visibility)) throw new Error('Choose a privacy setting.');
 if(network_visibility==='public'&&!username) throw new Error('Choose a handle before making your network profile public.');
 return {full_name:name,handle:username||null,network_visibility};
}
export function safeNext(value) {
 // Only explicitly allowed account pages can be a post-login destination.
 if(typeof value==='string'&&/^\/gift\/[a-f0-9]{32}$/.test(value))return value;
 return ['/', '/index.html', '/account.html','/designs.html','/orders.html','/credits.html','/network.html','/gifts.html','/shares.html','/owner.html','/fulfillment.html'].includes(value) ? value : '/account.html';
}
export function validatePassword(password,confirmation) {
 if(password.length<12) throw new Error('Use at least 12 characters for your password.');
 if(password!==confirmation) throw new Error('Your passwords do not match.');
 return password;
}
