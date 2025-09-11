import { useEffect, useState } from 'react';

export default function Home() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    fetch('/api/testStore')
      .then(res => res.json())
      .then(data => setProducts(data.products));
  }, []);

  return (
    <main style={{ padding: '2rem' }}>
      <h1>Keystone Storefront</h1>
      <ul>
        {products.map(p => (
          <li key={p.id} style={{ marginBottom: '1.5rem' }}>
            <strong>{p.title}</strong><br />
            <em>${(p.price / 100).toFixed(2)}</em><br />
            <a href={p.checkout_url} target="_blank" rel="noopener noreferrer">
              Buy with Stripe
            </a>
          </li>
        ))}
      </ul>
    </main>
  );
}
