import fs from 'fs'; import path from 'path'; import {fileURLToPath} from 'url';
const __dirname=path.dirname(fileURLToPath(import.meta.url)); const root=path.resolve(__dirname,'..');
const store=path.join(root,'data','store.json'); const mapFile=path.join(root,'data','image-urls.json'); const out=path.join(root,'public','images');
fs.mkdirSync(out,{recursive:true});
const items=JSON.parse(fs.readFileSync(store,'utf8')); const map=fs.existsSync(mapFile)?JSON.parse(fs.readFileSync(mapFile,'utf8')):{};
const idOf=p=>String(p.sku||p.slug||p.id||p.name||p.title||'unknown');
const pick=p=>{const arr=[p.image, ...(Array.isArray(p.images)?p.images:[]), map[idOf(p)]].filter(Boolean); return arr.find(u=>typeof u==='string' && /^https?:\/\//i.test(u));};
const ext=(ct,u)=>ct?.includes('png')?'.png':ct?.includes('webp')?'.webp':(ct?.includes('jpeg')||ct?.includes('jpg'))?'.jpg':(u?.toLowerCase().match(/\.(png|webp|jpe?g)(\?|$)/)?.[0]?.replace('jpeg','jpg')||'.jpg');
let saved=0;
for (const p of items){ const url=pick(p); if(!url) continue; const r=await fetch(url); if(!r.ok) continue;
  const e=ext(r.headers.get('content-type')||'',url); const id=idOf(p); const buf=Buffer.from(await r.arrayBuffer());
  fs.writeFileSync(path.join(out, id+e), buf); p.image='/images/'+id+e; saved++; }
fs.writeFileSync(store, JSON.stringify(items,null,2)); console.log('saved',saved,'images');
