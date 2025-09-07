import Products from "../components/Products";
export default async function Home() {
  return (
    <section>
      <h1 style={{fontSize:28, fontWeight:700, marginBottom:8}}>Today’s Picks</h1>
      <p style={{color:"#555", marginBottom:16}}>Auto-populated from Keystone AI catalog.</p>
      <Products />
    </section>
  );
}
