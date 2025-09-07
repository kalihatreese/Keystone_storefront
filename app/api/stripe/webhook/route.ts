import { NextRequest } from "next/server";
import Stripe from "stripe";
import { appendEvent } from "../../../../lib/db";

export const runtime = "nodejs";

const SK = process.env.STRIPE_SECRET_KEY || "";
const WH = process.env.STRIPE_WEBHOOK_SECRET || "";

if (!SK) throw new Error("Missing STRIPE_SECRET_KEY");
if (!WH) throw new Error("Missing STRIPE_WEBHOOK_SECRET");

const stripe = new Stripe(SK, { apiVersion: "2024-06-20" });

export async function POST(req: NextRequest) {
  const sig = req.headers.get("stripe-signature");
  if (!sig) return new Response("Missing Stripe-Signature", { status: 400 });

  const raw = await req.text();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(raw, sig, WH);
  } catch (e: any) {
    return new Response(`Bad signature: ${e.message}`, { status: 400 });
  }

  const type = String(event.type || "").replace(/[^a-zA-Z0-9._-]/g, "");
  appendEvent("stripe.event", { id: event.id, type });

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
