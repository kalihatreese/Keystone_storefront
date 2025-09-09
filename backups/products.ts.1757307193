import { getStore } from "./db";
import { filterRestricted } from "./compliance";
export async function fetchProducts(){
  const s = getStore();
  const restricted = (s.config?.restrictedTags) || ["alcohol","nicotine","cbd"];
  return filterRestricted(s.products || [], restricted);
}
