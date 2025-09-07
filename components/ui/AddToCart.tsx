"use client";
import { useCartStore } from "../../lib/cart";
export default function AddToCart({id, name, price}:{id:string; name:string; price:number}){
  const add = useCartStore(s=>s.add);
  return <button onClick={()=>add({id,name,price,qty:1})}>Add to cart</button>;
}
