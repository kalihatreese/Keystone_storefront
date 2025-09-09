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
