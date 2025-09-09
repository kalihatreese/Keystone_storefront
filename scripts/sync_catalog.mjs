import fs from "fs"; import path from "path";
const ROOT=process.cwd(), DATA=p=>path.join(ROOT,"data",p), IMG=path.join(ROOT,"public","images");
fs.mkdirSync(IMG,{recursive:true});
const N={GEN:50,ELEC:50};
const slug=s=>s.toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/(^-|-$)/g,"");
const rnd=(a,b)=>Math.round((a+Math.random()*(b-a))*100)/100;

const GEN_BASE=["Portable Blender","LED Strip Lights","Cordless Hair Trimmer","Car Phone Mount","Mini Projector","Posture Corrector","Massage Gun","Desk Lamp","Power Bank 20000mAh","Reusable Water Bottle"];
const ELEC_BASE=["Wireless Earbuds ANC","1080p Smart Cam","Bluetooth Speaker","Mechanical Keyboard","USB-C Hub 8-in-1","NVMe SSD 1TB","1080p Webcam","Fitness Tracker","Wi-Fi 6 Router","Gaming Mouse"];

function makeList(base, count, priceRange, tag){
  const items=[];
  for(let i=0;i<count;i++){
    const name = `${base[i%base.length]} ${String.fromCharCode(65+(i%26))}`;
    const id = `${slug(name)}-${i+1}`;
    const price = rnd(priceRange[0], priceRange[1]);
    const text = encodeURIComponent(name);
    const img = `https://placehold.co/800x800/png?text=${text}`;
    items.push({ id, title:name, price:Number(price.toFixed(2)), currency:"USD",
      image: img, images:[img], url:`https://example.com/${id}`, vendor:tag, enabled:true });
  }
  return items;
}

async function dl(img,id){
  const ext="png"; const out=path.join(IMG,`${id}.${ext}`);
  if(fs.existsSync(out)) return `/images/${id}.${ext}`;
  try{
    const r = await fetch(img); if(!r.ok) return null;
    const b = Buffer.from(await r.arrayBuffer()); fs.writeFileSync(out,b);
    return `/images/${id}.${ext}`;
  }catch{ return null; }
}

(async()=>{
  let items=[
    ...makeList(GEN_BASE, N.GEN, [7.99,79.99], "GEN"),
    ...makeList(ELEC_BASE, N.ELEC, [19.99,299.99], "ELEC"),
  ];

  // download images to local /public/images and switch paths
  for(const p of items){
    const local = await dl(p.image, p.id);
    p.image = local || "/images/placeholder.png";
    p.images = [p.image];
  }

  fs.writeFileSync(DATA("store.json"), JSON.stringify(items,null,2));
  console.log(`wrote ${items.length} items -> data/store.json`);
})();
