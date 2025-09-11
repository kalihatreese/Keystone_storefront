import { getTrendingProducts } from '@/lib/trending';

export default async function handler(req, res) {
  const products = await getTrendingProducts(); // pulls top 100 items

  const indexProducts = products => products.map(p => ({
    id: p.id,
    title: p.title.toLowerCase(),
    keywords: Array.from(new Set([p.title, ...p.title.split(' ')])).map(k => k.toLowerCase())
  }));

  const indexed = indexProducts(products);
  res.status(200).json({ products: indexed });
}
