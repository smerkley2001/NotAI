import QRCode from 'qrcode';
export const canonicalOrigin='https://notaijusti.com';
export function shirtUrl(token){if(!/^[a-f0-9]{32}$/.test(token))throw new Error('Invalid shirt token');return canonicalOrigin+'/s/'+token;}
export async function qrSvg(token){return QRCode.toString(shirtUrl(token),{type:'svg',errorCorrectionLevel:'Q',margin:4,color:{dark:'#000000',light:'#FFFFFF'}});}
export async function qrPng(token){return QRCode.toDataURL(shirtUrl(token),{errorCorrectionLevel:'Q',margin:4,width:1024,color:{dark:'#000000',light:'#FFFFFF'}});}
export function download(data,name,type='image/svg+xml'){const url=URL.createObjectURL(new Blob([data],{type}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
