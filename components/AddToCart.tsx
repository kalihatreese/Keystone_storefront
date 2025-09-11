"use client";
export default function AddToCart({ id }:{id:string}) {
  return <button className="px-3 py-2 rounded border" onClick={()=>console.log("add",id)}>Add to cart</button>;
}
