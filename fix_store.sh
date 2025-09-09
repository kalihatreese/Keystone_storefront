#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# stop dev
pkill -f "next dev" >/dev/null 2>&1 || true

# 1) Patch UI imports and fields safely via Node
cat > scripts/patch_ui.cjs <<'JS'
const fs=require('fs'), path=require('path');
const roots=['app','components'];
const files=[];
function walk(p){ if(!fs.existsSync(p)) return;
  for(const f of fs.readdirSync(p)){ const fp=path.join(p,f);
    const st=fs.statSync(fp);
    if(st.isDirectory()) walk(fp);
    else if(/\.(tsx?|jsx?)$/.test(f)) files.push(fp);
  }
}
roots.forEach(walk);
for(const f of files){
  let s=fs.readFileSync(f,'utf8'); let o=s;

  // use normalized lib instead of raw JSON
  s=s.replace(/['"]\.\.?\/data\/store\.json['"]/g,'"../lib/products"');

  // show title fallback
  s=s.replace(/\bproduct\.name\b/g,'(product.title || product.name)');
  s=s.replace(/\bp\.name\b/g,'(p.title || p.name)');

  // single image field
  s=s.replace(/(product|p)\.images\??\[\s*0\s*\]/g,'$1.image');

  // stop dividing by 100
  s=s.replace(/\b(price|p\.price|product\.price)\s*\/\s*100\b/g,'Number($1)');

  if(s!==o){ fs.writeFileSync(f,s); console.log('patched', f); }
}
JS
node scripts/patch_ui.cjs

# 2) Replace lib/products.ts with a known-good normalizer
cat > lib/products.ts <<'TS'
import fs from "fs";
import path from "path";

const storePath = path.join(process.cwd(), "data", "store.json");
const raw = fs.existsSync(storePath) ? fs.readFileSync(storePath, "utf8") : "[]";
const STORE: any[] = JSON.parse(raw);

type P = {
  id?: string; sku?: string; slug?: string; title?: string; name?: string;
  price?: number|string; price_cents?: number; pricing?: { price?: number|string };
  images?: string[]; image?: string; img?: string; currency?: string; enabled?: boolean; [k: string]: any;
};

function toNumber(x: any): number | undefined {
  if (x == null) return undefined;
  if (typeof x === "number" && !Number.isNaN(x)) return x;
  if (typeof x === "string") {
    const n = Number(x.replace(/[^0-9.,-]/g, "").replace(",", "."));
    return Number.isNaN(n) ? undefined : n;
  }
}

function chooseId(p: P): string {
  return (p.sku || p.slug || p.id || p.name || p.title || "unknown").toString();
}

function chooseImage(p: P): string {
  const c = [
    p.image,
    p.img,
    Array.isArray(p.images) ? p.images[0] : undefined,
    `/images/${p.sku || p.slug || p.id}.jpg`,
    `/images/${p.sku || p.slug || p.id}.png`,
  ].filter(Boolean) as string[];
  return c[0] || "/images/placeholder.png";
}

function normalize(p: P) {
  const price =
    toNumber(p.price) ??
    toNumber(p.pricing?.price) ??
    (typeof p.price_cents === "number" ? p.price_cents / 100 : undefined);

  return {
    id: chooseId(p),
    title: (p.title || p.name || "").toString(),
    price: typeof price === "number" && price > 0 ? Number(price.toFixed(2)) : 0,
    currency: p.currency || "USD",
    image: chooseImage(p),
    images: Array.isArray(p.images) && p.images.length ? p.images : [chooseImage(p)],
    enabled: p.enabled !== false,
    ...p,
  };
}

export function getProducts() { return STORE.map(normalize); }
export function getProductById(id: string) { return getProducts().find((p) => p.id === id); }
export async function fetchProducts() { return getProducts(); }
TS

# 3) Sanity pass on data (optional)
[ -f scripts/sanity_check.mjs ] && node scripts/sanity_check.mjs || true

# 4) Show sample to confirm
node - <<'NODE'
const d=require('./data/store.json');
console.log(d.slice(0,8).map(x=>({id:x.id, title:x.title||x.name, price:x.price, image:x.image})));
NODE

# 5) restart
PORT=3001 npm run dev
