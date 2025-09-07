import { create } from "zustand";
type Item = { id:string; name:string; price:number; qty:number; };
type S = { items: Item[]; add:(i:Item)=>void; remove:(id:string)=>void; };
export const useCartStore = create<S>(set => ({
  items: [],
  add: (i) => set(s => {
    const idx = s.items.findIndex(x=>x.id===i.id);
    if (idx>=0){ const copy=[...s.items]; copy[idx].qty += i.qty; return {items:copy}; }
    return {items:[...s.items, i]};
  }),
  remove: (id) => set(s => ({items: s.items.filter(x=>x.id!==id)}))
}));
