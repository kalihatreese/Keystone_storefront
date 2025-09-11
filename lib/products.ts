import STORE from "../data/store.json";

type P = any;

const num = (x: any) => {
  if (x == null) return 0;
  if (typeof x === "number") return x;
  const n = Number(String(x).replace(/[^0-9.,-]/g, "").replace(",", "."));
  return Number.isNaN(n) ? 0 : n;
};

const pid = (p: P) =>
  String(p?.sku || p?.slug || p?.id || p?.name || p?.title || "unknown");

const pick = (p: P) => {
  const id = pid(p);
  const c = [
    p?.image,
    p?.img,
    Array.isArray(p?.images) ? p.images[0] : undefined,
    `/images/${id}.png`,
    `/images/${id}.jpg`,
  ].find(Boolean) as string | undefined;
  return c || "/images/placeholder.png";
};

const norm = (p: P) => ({
  id: pid(p),
  title: String(p?.title || p?.name || pid(p)),
  price: Number(num(p?.price) || (typeof p?.price_cents === "number" ? p.price_cents / 100 : 0)),
  image: pick(p),
  images: Array.isArray(p?.images) && p.images.length ? p.images : [pick(p)],
  ...p,
});

export function getProducts() { return (STORE as any[]).map(norm); }
export function getProductById(id: string) { return getProducts().find(p => p.id === id); }
export async function fetchProducts() { return getProducts(); }

