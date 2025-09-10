import STORE from "../data/store.json";
type P = any;
function toNumber(x:any){ if(x==null) return; if(typeof x==="number"&&!Number.isNaN(x)) return x;
  if(typeof x==="string"){ const n=Number(x.replace(/[^0-9.,-]/g,"").replace(",",".")); if(!Number.isNaN(n)) return n; } }
function chooseId(p:P){ return (p.sku||p.slug||p.id||p.name||p.title||"unknown").toString(); }
function chooseImage(p:P){
  const c=[p.image,p.img,Array.isArray(p.images)?p.images[0]:undefined,
    `/images/${p.sku||p.slug||p.id}.jpg`, `/images/${p.sku||p.slug||p.id}.png`].filter(Boolean) as string[];
  return c[0]||"/images/placeholder.png";
}
function normalize(p:P){
  const price=toNumber(p.price)??toNumber(p.pricing?.price)??(typeof p.price_cents==="number"?p.price_cents/100:undefined);
  return { id:chooseId(p), title:(p.title||p.name||"").toString(),
    price:typeof price==="number"&&price>0?Number(price.toFixed(2)):0,
    currency:p.currency||"USD", image:chooseImage(p),
    images:Array.isArray(p.images)&&p.images.length?p.images:[chooseImage(p)],
    enabled:p.enabled!==false, ...p };
}
export function getProducts(){ return (STORE as any[]).map(normalize); }
export function getProductById(id:string){ return getProducts().find(p=>p.id===id); }
export async function fetchProducts(){ return getProducts(); }
