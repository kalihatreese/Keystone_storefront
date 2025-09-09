#!/usr/bin/env bash
set -euo pipefail

# 0) Ensure placeholder
mkdir -p public/images
[ -f public/images/placeholder.png ] || base64 -d > public/images/placeholder.png <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAQAAABccqhmAAAAAklEQVR42u3BMQEAAADCoPdPbQ8HFAAAAAAAAAAAwB0OAAABZq3mWQAAAABJRU5ErkJggg==
B64

# 1) Force all code to use normalized lib/products (not raw JSON)
grep -RIl --include='*.{ts,tsx,js,jsx}' 'data/store.json' app components 2>/dev/null \
 | xargs -r sed -i 's#["'\'']\.\.?/data/store\.json["'\'']#"\.\./lib/products"#g'

# 2) Stop dividing by 100 in UI
grep -RIl --include='*.{ts,tsx,js,jsx}' '/100' app components 2>/dev/null \
 | xargs -r sed -i -E 's/\b(price|p\.price|product\.price)\s*\/\s*100\b/Number(\1)/g'

# 3) Always show a name
grep -RIl --include='*.{ts,tsx,js,jsx}' 'product.name' app components 2>/dev/null \
 | xargs -r sed -i 's/product\.name/(product.title || product.name)/g'
grep -RIl --include='*.{ts,tsx,js,jsx}' 'p.name' app components 2>/dev/null \
 | xargs -r sed -i 's/p\.name/(p.title || p.name)/g'

# 4) Use single image field
grep -RIl --include='*.{ts,tsx,js,jsx}' 'images\[0\]|images\?\.\[0\]' app components 2>/dev/null \
 | xargs -r sed -i -E 's/(product|p)\.images(\?\.)?\[0\]/\1.image/g'

# 5) Harden normalizer: numeric price, local image fallback
node -e '
const fs=require("fs"), p=require("path");
const f="lib/products.ts"; if(!fs.existsSync(f)) process.exit(0);
let s=fs.readFileSync(f,"utf8");
if(!/export async function fetchProducts/.test(s)){
  s=s.replace(/export function getProductById[\\s\\S]*?}\\n}/,
`export function getProductById(id: string) {
  return getProducts().find((p) => p.id === id);
}
export async function fetchProducts(){ return getProducts(); }`);
}
if(!/placeholder\.png/.test(s)){
  s=s.replace(/return c\[0] \|\| ".*?";/, 'return c[0] || "/images/placeholder.png";');
}
fs.writeFileSync(f,s);
'

# 6) Quick sanity on data
node -e 'const d=require("./data/store.json"); console.log(d.slice(0,8).map(x=>({id:x.id, price:x.price, title:x.title||x.name, image:x.image})))'

# 7) Rebuild catalog (optional if you already have 100 items)
[ -f scripts/sanity_check.mjs ] && node scripts/sanity_check.mjs || true

# 8) Restart dev
pkill -f "next dev" >/dev/null 2>&1 || true
PORT=3001 npm run dev
