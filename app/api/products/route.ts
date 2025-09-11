import { getProducts } from "../../../lib/products";
export async function GET(){ return new Response(JSON.stringify({products:getProducts()}),{headers:{"Content-Type":"application/json"}}); }
