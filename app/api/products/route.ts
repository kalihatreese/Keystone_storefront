import { fetchProducts } from "../../../lib/products";
export async function GET(){ const products = await fetchProducts(); return new Response(JSON.stringify({products}), {headers: {"Content-Type":"application/json"}}); }
