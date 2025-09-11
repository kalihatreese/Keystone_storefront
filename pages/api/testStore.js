import { createCheckoutSession } from '@/lib/stripe';

export default async function handler(req, res) {
  const products = [
    { id: 'p001', title: 'Smart LED Light Strip', price: 2499 },
    { id: 'p002', title: 'Wireless Earbuds Pro', price: 7999 },
    { id: 'p003', title: 'Ergonomic Gaming Chair', price: 12999 }
  ];

  const indexed = await Promise.all(products.map(async p => ({
    ...p,
    title: p.title.toLowerCase(),
    keywords: Array.from(new Set([p.title, ...p.title.split(' ')])).map(k => k.toLowerCase()),
    checkout_url: await createCheckoutSession(p)
  })));

  res.status(200).json({ products: indexed });
}
