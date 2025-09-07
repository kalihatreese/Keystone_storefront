const fs=require('fs'); const path=require('path');
const dataPath=path.join(__dirname,'../../data/store.json');
const todaySeed=path.join(__dirname,'../../data/todays_hot_items_2025-09-05.json');
function load(){ try{return JSON.parse(fs.readFileSync(dataPath,'utf8'));}catch{return {config:{},products:[],orders:[],events:[]};} }
function save(s){ if(process.env.READONLY_FS==='1')return; fs.writeFileSync(dataPath, JSON.stringify(s,null,2)); }
function slugify(s){ return s.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,''); }
async function seedToday(){
  const store=load(); const d=JSON.parse(fs.readFileSync(todaySeed,'utf8')); const now=new Date().toISOString();
  const restricted=["Nicotine Pouches","Hard Kombucha","CBD Balm","CBD Drinks","Hemp Gummies"];
  store.products=(d.items||[]).map((name,i)=>({id:slugify(name)+"-"+i,name,description:`${name} — auto-populated ${d.date}`,images:[],tags:restricted.includes(name)?["restricted"]:[],price:1999,currency:"USD",inventory:100,createdAt:now,updatedAt:now,enabled:!restricted.includes(name)}));
  save(store); console.log(`Seeded ${store.products.length} products for ${d.date}. Restricted items disabled.`);
}
(async()=>{ if(process.argv.includes("--seed-only")) return seedToday(); await seedToday(); })();
