#!/usr/bin/env python3
import os, json, time, datetime, requests, sys, re
from price_rules import compute_price_cents

ENV=os.path.expanduser("~/keystone_storefront/.env")
LOG=os.path.expanduser("~/keystone_storefront/logs/ops_runner.log")

def load():
    env={}
    with open(ENV) as f:
        for ln in f:
            if "=" in ln and not ln.strip().startswith("#"):
                k,v=ln.rstrip("\n").split("=",1); env[k]=v
    for k in ["KEYSTONE_CATALOG_URL","KEYSTONE_PRICING_URL","KEYSTONE_INVENTORY_URL","ADMIN_TOKEN"]:
        if not env.get(k): sys.exit(f"env {k} missing")
    return env

def fetch(env, kind, limit):
    u=env["KEYSTONE_CATALOG_URL"].rstrip("/")+"/top"
    r=requests.get(u,params={"kind":kind,"limit":limit},timeout=30)
    r.raise_for_status()
    return r.json()

def enrich_and_price(items):
    out=[]
    for it in items:
        # normalize fields from catalog
        name = it.get("name") or it.get("title") or "Product"
        slug = it.get("slug") or re.sub(r'[^a-z0-9]+','-', name.lower()).strip('-')
        img = it.get("imageUrl") or (it.get("images") or [None])[0] or f"https://picsum.photos/seed/{slug}/640/640"
        # cost and comps if provided by catalog
        draft = {
            "name": name,
            "slug": slug,
            "imageUrl": img,
            "cost_cents": it.get("cost_cents"),
            "shipping_cents": it.get("shipping_cents", 0),
            "map_cents": it.get("map_cents"),
            "competitors": it.get("competitors", []),
            "baseline_cents": it.get("baseline_cents"),
            "min_margin_pct": it.get("min_margin_pct", 0.20),
            # keep any SKU/MSRP if present
            "sku": it.get("sku") or slug,
            "msrp_cents": it.get("msrp_cents"),
            "category": it.get("category") or it.get("kind"),
        }
        price_cents = compute_price_cents(draft)
        draft["price_cents"] = price_cents
        out.append(draft)
    return out

def upsert(env, items):
    api="http://localhost:3000/api/admin/upsert"
    r=requests.post(api,headers={"X-Admin-Token":env["ADMIN_TOKEN"]},json={"items":items},timeout=60)
    r.raise_for_status(); return r.json()

def prune(env):
    api="http://localhost:3000/api/admin/prune"
    cutoff=(datetime.datetime.utcnow()-datetime.timedelta(days=2)).date().isoformat()
    r=requests.post(api,headers={"X-Admin-Token":env["ADMIN_TOKEN"]},json={"before":cutoff},timeout=20)
    return r.json() if r.ok else {"prune":"skipped","code":r.status_code}

def main():
    env=load()
    general = fetch(env,"general",50)
    electronics = fetch(env,"electronics",50)
    priced = enrich_and_price(general + electronics)
    res = upsert(env, priced)
    pr = prune(env)
    out={"ts":int(time.time()),"count":len(priced),"upsert":res,"prune":pr}
    print(json.dumps(out))
    with open(LOG,"a") as f: f.write(json.dumps(out)+"\n")

if __name__=="__main__": main()
