#!/usr/bin/env python3
import os,re,sys,json,requests,stripe
from pathlib import Path
from envutil import load_env
def base_url():
    t=Path.home()/ "keystone_storefront"/"logs"/"tunnel.log"
    if t.exists():
        m=re.findall(r"https://[A-Za-z0-9-]+\.trycloudflare\.com", t.read_text())
        if m: return m[-1].rstrip("/")
    return "http://localhost:3000"
env=load_env()
sk=env.get("STRIPE_SECRET_KEY","").strip()
if not sk: sys.exit("STRIPE_SECRET_KEY missing")
stripe.api_key=sk
pub=base_url()
target=f"{pub}/api/stripe/webhook"
# find or create
eps=stripe.WebhookEndpoint.list(limit=100)
ep=[e for e in eps.data if e.url==target]
if not ep:
    ep=[stripe.WebhookEndpoint.create(
        url=target,
        enabled_events=["checkout.session.completed","payment_intent.succeeded","payment_intent.payment_failed"]
    )]
whsec=ep[0].secret
# persist to .env
envp=Path.home()/ "keystone_storefront"/".env"
txt=envp.read_text()
if re.search(r'^STRIPE_WEBHOOK_SECRET=', txt, flags=re.M):
    txt=re.sub(r'^STRIPE_WEBHOOK_SECRET=.*', f'STRIPE_WEBHOOK_SECRET={whsec}', txt, flags=re.M)
else:
    txt += f'\nSTRIPE_WEBHOOK_SECRET={whsec}\n'
envp.write_text(txt)
print(json.dumps({"webhook_url":target,"secret_written":True},indent=2))
