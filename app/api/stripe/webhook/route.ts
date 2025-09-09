import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import fs from "fs";
import path from "path";

export async function POST(req: NextRequest){
  const sig = req.headers.get("stripe-signature") || "";
  const buf = await req.text();
  const wh = process.env.STRIPE_WEBHOOK_SECRET || "";
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "", { apiVersion: "2024-06-20" });
  let evt:any;
  try { evt = stripe.webhooks.constructEvent(buf, sig, wh); }
  catch(e:any){ return new NextResponse(`Webhook Error: ${e.message}`, { status: 400 }); }

  if(evt.type === "checkout.session.completed"){
    try{
      const s = await stripe.checkout.sessions.retrieve(evt.data.object.id, { expand:["line_items","line_items.data.price.product"] });
      const lines = s.line_items?.data || [];
      const logPath = path.join(process.cwd(),"logs","sales.jsonl");
      for(const li of lines){
        const meta:any = (li.price as any)?.product && typeof (li.price as any).product === "object" ? (li.price as any).product : {};
        const kid = (meta?.metadata?.keystone_product_id) || meta?.metadata?.sku || meta?.name || "";
        const rec = { ts: Date.now(), session: s.id, qty: li.quantity||1, amount: li.amount_total||li.amount_subtotal||0, product_id: kid };
        fs.appendFileSync(logPath, JSON.stringify(rec)+"\n");
      }
    }catch(e){ console.error("stripe expand/log fail", e); }
  }
  return NextResponse.json({received:true});
}
