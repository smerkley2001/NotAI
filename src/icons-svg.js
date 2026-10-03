const shapes={
 soccer:'<circle cx="50" cy="50" r="43"/><path d="M50 30 69 44 61 66 39 66 31 44Z" fill="currentColor"/><path d="m50 30 0-23m19 37 22-8M61 66l14 22M39 66 25 88M31 44 9 36"/>',
 volleyball:'<circle cx="50" cy="50" r="43"/><path d="M50 7c-23 19-27 42-9 62m-27-43c9 24 27 38 53 36m22-32C63 25 43 34 35 58M78 82c-24-4-41-20-43-45"/>',
 basketball:'<circle cx="50" cy="50" r="43"/><path d="M7 50h86M50 7v86M20 19c40 7 61 42 62 62M19 82c7-40 42-61 62-62"/>',
 guitar:'<path d="m61 38 19-26 9 8-21 26c8 9 5 20-2 23-2 13-17 22-29 14-13-9-17-25-7-35 3-10 17-15 24-5Z"/><circle cx="51" cy="57" r="9"/><path d="m46 63 37-46m-48 53 14 9"/>',
 art:'<path d="M51 8C24 8 8 28 8 51s20 42 44 42c10 0 17-9 10-18-4-7 2-13 11-12 21 4 24-15 16-29C82 18 67 8 51 8Z"/><circle cx="29" cy="31" r="5" fill="currentColor"/><circle cx="52" cy="23" r="5" fill="currentColor"/><circle cx="74" cy="35" r="5" fill="currentColor"/><circle cx="27" cy="57" r="5" fill="currentColor"/>',
 paw:'<path d="M50 43c-8 0-13 10-21 16-13 10-9 24 2 24 8 0 12-5 19-5s11 5 19 5c11 0 15-14 2-24-8-6-13-16-21-16Z" fill="currentColor"/><ellipse cx="18" cy="39" rx="8" ry="12"/><ellipse cx="38" cy="23" rx="8" ry="12"/><ellipse cx="62" cy="23" rx="8" ry="12"/><ellipse cx="82" cy="39" rx="8" ry="12"/>',
 books:'<path d="M12 25h21v61H12Zm27-12h20v73H39Zm27 7 18-4 13 65-18 4Z"/><path d="M15 36h15m12-12h14M72 31l14-3M15 75h15m12 0h14"/>',
 star:'<path d="m50 7 13 27 30 5-22 22 5 31-26-15-26 15 5-31L7 39l30-5Z"/>',
 heart:'<path d="M50 86 14 51C-8 29 24-4 50 22 76-4 108 29 86 51Z" fill="currentColor"/>',
 gaming:'<path d="M27 28h46c13 0 18 13 22 38 4 22-13 27-25 8H30C18 93 1 88 5 66c4-25 9-38 22-38Z"/><path d="M19 50h23M30 39v23"/><circle cx="69" cy="45" r="4" fill="currentColor"/><circle cx="81" cy="58" r="4" fill="currentColor"/>'};
export function iconSvg(key,color='currentColor'){if(!Object.hasOwn(shapes,key))throw new Error('Unsupported icon');if(color!=='currentColor'&&!/^#[a-f0-9]{6}$/i.test(color))throw new Error('Invalid icon color');return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100" aria-hidden="true" style="color:${color}" fill="none" stroke="currentColor" stroke-width="5" stroke-linejoin="round" stroke-linecap="round">${shapes[key]}</svg>`;}
export function iconGroup(key,color){const svg=iconSvg(key,color);return `<g transform="translate(445 770) scale(1.1)" fill="none" stroke="${color}" color="${color}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round">${shapes[key]}</g>`;}
