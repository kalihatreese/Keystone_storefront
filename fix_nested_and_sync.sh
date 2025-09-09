#!/usr/bin/env bash
set -euo pipefail
cd ~/keystone_storefront

# stop dev
pkill -f "next dev" >/dev/null 2>&1 || true

# remove nested copy
rm -rf Keystone_storefront/.git 2>/dev/null || true
rm -rf Keystone_storefront 2>/dev/null || true

# ensure dirs
mkdir -p scripts public/images data logs

# catalog builder
cat > scripts/sync_catalog.mjs <<'JS'
import fs from "fs"; import path from "path"; const ROOT=process.cwd();
const DATA=p=>path.join(ROOT,"data",p); const IMG=path.join(ROOT,"public","images");
fs.mkdirSync(IMG,{recursive:true});
const N={GEN:50, ELEC:50};
const slug=s=>s.toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/(^-|-$)/g,"");
const cents=x=>{const n=Number(String(x).replace(/[^0-9.]/g,""));return Number.isFinite(n)?Math.round(n*100):null};

async function seeds(){
  const gen=[
    {title:"Portable Power Bank 20000mAh", price:29.99, image:"https://i.imgur.com/2l4bVqC.jpeg", url:"https://example.com/power-bank", vendor:"GEN"},
    {title:"Cordless Hair Trimmer", price:24.95, image:"https://i.imgur.com/FoS8Vyx.jpeg", url:"https://example.com/trimmer", vendor:"GEN"},
  ];
  const elec=[
    {title:"Wireless Earbuds ANC", price:49.99, image:"https://i.imgur.com/8h1I9ti.jpeg", url:"https://example.com/earbuds", vendor:"ELEC"},
    {title:"1080p Smart Cam", price:32.99, image:"https://i.imgur.com/8p9qOqY.jpeg", url:"https://example.com/cam", vendor:"ELEC"},
  ];
  return {gen, elec};
}

async function dl(img,id){
  if(!img) return null;
  const ext=(img.split("?")[0].split(".").pop()||"jpg").toLowerCase();
  const fname=`${id}.${["jpg","jpeg","png","webp"].includes(ext)?ext:"jpg"}`;
  const out=path.join(IMG,fname);
  if(fs.existsSync(out)) return `/images/${fname}`;
  try{ const r=await fetch(img); if(!r.ok) return null;
       const b=Buffer.from(await r.arrayBuffer()); fs.writeFileSync(out,b);
       return `/images/${fname}`; }catch{ return null; }
}

const run=async()=>{
  const {gen,elec}=await seeds();
  let items=[...gen.slice(0,N.GEN), ...elec.slice(0,N.ELEC)];

  const seen=new Set();
  items=items.filter(x=>x&&x.title&&x.url).filter(x=>{
    const k=x.url+"|"+slug(x.title); if(seen.has(k)) return false; seen.add(k); return true;
  }).map(x=>({
    id: slug(x.title)+"-"+Buffer.from(x.url).toString("base64").slice(0,6),
    title: x.title.trim(),
    price: Number.isFinite(x.price)?Number(x.price):(cents(x.price)||0)/100,
    currency:"USD",
    image:x.image||"",
    images:x.images?.length?x.images:(x.image?[x.image]:[]),
    url:x.url, vendor:x.vendor||"GEN", enabled:true
  })).filter(p=>p.price>0);

  for(const p of items){
    if(!(p.image||"").startsWith("/images/")){
      const local=await dl(p.image,p.id);
      p.image=local||"/images/placeholder.png"; p.images=[p.image];
    }
  }
  fs.writeFileSync(DATA("store.json"), JSON.stringify(items,null,2));
  console.log("wrote", items.length, "items");
};
run().catch(e=>{console.error(e);process.exit(1);});
JS

# sanity fixer
cat > scripts/sanity_check.mjs <<'JS'
import fs from "fs"; import path from "path";
const p=path.join("data","store.json");
const data=JSON.parse(fs.readFileSync(p,"utf8"));
let bad=0;
for(const x of data){
  if(!(x.image||"").startsWith("/images/")){ x.image="/images/placeholder.png"; x.images=[x.image]; bad++; }
  if(!(x.price>0)){ x.enabled=false; bad++; }
}
fs.writeFileSync(p, JSON.stringify(data,null,2));
console.log("sanity fixed:", bad);
JS

# placeholder image (1x1 png)
base64 -d > public/images/placeholder.png <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=
B64

# ensure fetchProducts export
grep -q 'export async function fetchProducts' lib/products.ts || \
sed -i '/export function getProductById/a \
\nexport async function fetchProducts(){ return getProducts(); }\n' lib/products.ts

# ensure Products.tsx filters enabled items
sed -i 's/\.filter(.*enabled==false)/.filter(p=>p.enabled!==false)/' components/Products.tsx || true

# refresh catalog
node scripts/sync_catalog.mjs
node scripts/sanity_check.mjs

# restart dev
PORT=3001 npm run dev
