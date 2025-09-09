#!/usr/bin/env bash
set -euo pipefail
cd ~/keystone_storefront
mkdir -p logs data app/api/stripe/webhook scripts

# 1) Patch lib/products.ts to apply learned price overrides
node -e '
const fs=require("fs"), p=require("path");
const f="lib/products.ts";
let s=fs.readFileSync(f,"utf8");
if(!/price_overrides\.json/.test(s)){
  s=s.replace(/const STORE[^;]+;/,
`$&
const overridesPath = path.join(process.cwd(),"data","price_overrides.json");
const PRICE_OVERRIDES:any = fs.existsSync(overridesPath)? JSON.parse(fs.readFileSync(overridesPath,"utf8")) : {};`);
  s=s.replace(/return {\n\s*id:[\s\S]*?price:\s*typeof price[\s\S]*?\,/,
m=>m+`\n    // learned multiplier from Ashleyana/ShadowX\n    ...(PRICE_OVERRIDES[chooseId(p)] ? { price: Math.max(1, Number(((typeof price==="number"?price:0)* (PRICE_OVERRIDES[chooseId(p)]?.multiplier||1)).toFixed(2))) } : {}),\n`);
  fs.writeFileSync(f,s);
  console.log("patched lib/products.ts");
} else { console.log("lib/products.ts already patched"); }
';

# 2) Sales logging via Stripe webhook (expands line_items)
cat > app/api/stripe/webhook/route.ts <<'TS'
import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import fs from "fs";
import path from "path";

export async function POST(req: NextRequest){
  const sig = req.headers.get("stripe-signature") || "";
  const buf = await req.text();
  const wh = process.env.STRIPE_WEBHOOK_SECRET || "";
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "", { apiVersion: "2024-06-20" });
  let evt:any;
  try { evt = stripe.webhooks.constructEvent(buf, sig, wh); }
  catch(e:any){ return new NextResponse(`Webhook Error: ${e.message}`, { status: 400 }); }

  if(evt.type === "checkout.session.completed"){
    try{
      const s = await stripe.checkout.sessions.retrieve(evt.data.object.id, { expand:["line_items","line_items.data.price.product"] });
      const lines = s.line_items?.data || [];
      const logPath = path.join(process.cwd(),"logs","sales.jsonl");
      for(const li of lines){
        const meta:any = (li.price as any)?.product && typeof (li.price as any).product === "object" ? (li.price as any).product : {};
        const kid = (meta?.metadata?.keystone_product_id) || meta?.metadata?.sku || meta?.name || "";
        const rec = { ts: Date.now(), session: s.id, qty: li.quantity||1, amount: li.amount_total||li.amount_subtotal||0, product_id: kid };
        fs.appendFileSync(logPath, JSON.stringify(rec)+"\n");
      }
    }catch(e){ console.error("stripe expand/log fail", e); }
  }
  return NextResponse.json({received:true});
}
export const config = { api: { bodyParser: false } };
TS

# 3) Optimizer: bandit-style price multiplier per product
cat > scripts/optimizer.mjs <<'JS'
import fs from "fs"; import path from "path";
const salesPath = path.join(process.cwd(),"logs","sales.jsonl");
const storePath = path.join(process.cwd(),"data","store.json");
const outPath = path.join(process.cwd(),"data","price_overrides.json");
const MIN=0.70, MAX=1.30, STEP=0.05;

function loadJSONL(p){ if(!fs.existsSync(p)) return []; return fs.readFileSync(p,"utf8").trim().split("\n").filter(Boolean).map(x=>{try{return JSON.parse(x)}catch{return null}}).filter(Boolean); }
function clamp(x,a,b){ return Math.max(a, Math.min(b,x)); }

const store = fs.existsSync(storePath)? JSON.parse(fs.readFileSync(storePath,"utf8")) : [];
const sales = loadJSONL(salesPath);
const overrides = fs.existsSync(outPath)? JSON.parse(fs.readFileSync(outPath,"utf8")) : {};

const last24 = Date.now()-24*3600*1000;
const recent = sales.filter(s=>s.ts>=last24);

const soldCount = recent.reduce((m,r)=>{ const k=r.product_id||""; if(!k) return m; m[k]=(m[k]||0)+(r.qty||1); return m; }, {});
for(const p of store){
  const id = (p.sku||p.slug||p.id||p.title||"").toString();
  if(!id) continue;
  const cur = overrides[id]?.multiplier ?? 1.00;
  const sold = soldCount[id] || 0;

  // Heuristic: if sold >=2 items in 24h, increase price; if zero sales, decrease slightly.
  let next = cur;
  if(sold >= 2) next = cur + STEP;
  else if(sold === 0) next = cur - STEP/2;

  overrides[id] = { multiplier: Number(clamp(next, MIN, MAX).toFixed(2)) };
}

fs.writeFileSync(outPath, JSON.stringify(overrides,null,2));
console.log("updated overrides:", Object.keys(overrides).length);
JS

# 4) Seed overrides file if missing
[ -f data/price_overrides.json ] || echo '{}' > data/price_overrides.json

# 5) Cron: hourly optimize; morning catalog refresh already handled
( crontab -l 2>/dev/null | grep -v "keystone_opt" || true ) | crontab -
( crontab -l 2>/dev/null; echo "15 * * * * cd $PWD && node scripts/optimizer.mjs >> logs/opt.log 2>&1  # keystone_opt" ) | crontab -

# 6) Restart dev
pkill -f "next dev" >/dev/null 2>&1 || true
PORT=3001 npm run dev
