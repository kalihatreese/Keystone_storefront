import AddToCart from "./AddToCart";
import { getProducts } from "../lib/products";

export default function Products(){
  const products = getProducts();
  return (
    <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(220px,1fr))",gap:16}}>
      {products.map((p:any)=>(
        <div key={p.id} style={{border:"1px solid #eee",borderRadius:12,padding:12}}>
          <div style={{position:"relative",width:"100%",aspectRatio:"1/1",overflow:"hidden",borderRadius:8,background:"#f8f8f8"}}>
            <img src={p.image} alt={p.title||p.id} style={{width:"100%",height:"100%",objectFit:"cover"}} />
          </div>
          <div style={{fontWeight:600,marginTop:8}}>{p.title || p.id}</div>
          <div style={{color:"#666",fontSize:14,minHeight:40}}>{p.description ?? ""}</div>
          <div style={{margin:"8px 0",fontWeight:700}}>${Number(p.price||0).toFixed(2)}</div>
          <AddToCart id={p.id}/>
        </div>
      ))}
    </div>
  );
}
