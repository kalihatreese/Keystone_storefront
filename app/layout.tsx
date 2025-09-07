export const metadata = { title: "Keystone Storefront", description: "AI-powered storefront" };
export default function RootLayout({children}:{children:React.ReactNode}) {
  return (
    <html lang="en">
      <body style={{fontFamily:"Inter, system-ui, Arial"}}>
        <header style={{padding:"12px 20px", borderBottom:"1px solid #eee"}}>
          <a href="/" style={{textDecoration:"none", color:"#111", fontWeight:700}}>Keystone Storefront</a>
          <nav style={{float:"right"}}>
            <a href="/admin" style={{marginLeft:16}}>Admin</a>
            <a href="/cart" style={{marginLeft:16}}>Cart</a>
          </nav>
        </header>
        <main style={{padding:"20px"}}>{children}</main>
      </body>
    </html>
  );
}
