import { fetchProducts } from "../lib/products";
import AddToCart from "./ui/AddToCart";
export default async function Products(){
  const products = await fetchProducts();
  return (
    <div style={{display:"grid", gridTemplateColumns:"repeat(auto-fill, minmax(220px,1fr))", gap:16}}>
      {products.filter(p=>p.enabled!==false).map(p => (
        <div key={p.id} style={{border:"1px solid #eee", borderRadius:8, padding:12}}>
          <div style={{fontWeight:700}}>{(p.title || (p.title || p.name))}</div>
          <div style={{color:"#666", fontSize:14, minHeight:40}}>{p.description}</div>
          <div style={{margin:"8px 0", fontWeight:700}}>${(Number(p.price)).toFixed(2)}</div>
          <AddToCart id={p.id} name={(p.title || (p.title || p.name))} price={p.price} />
        </div>
      ))}
    </div>
  );
}
