#!/usr/bin/env python3
import os,re,time,json,random,urllib.parse,requests
from pathlib import Path
from bs4 import BeautifulSoup
from envutil import load_env

ROOT = Path.home()/ "keystone_storefront"
HEADERS={"User-Agent":"Mozilla/5.0"}
TIMEOUT=12

def base_url():
    t=ROOT/"logs"/"tunnel.log"
    if t.exists():
        m=re.findall(r"https://[A-Za-z0-9-]+\.trycloudflare\.com", t.read_text())
        if m: return m[-1].rstrip("/")
    return "http://localhost:3000"

def fetch_home_items(base):
    r=requests.get(base,headers=HEADERS,timeout=TIMEOUT); r.raise_for_status()
    html=r.text
    names=re.findall(r'<div style="font-weight:700">([^<]{3,120})</div>',html)
    slugs=re.findall(r'href="(/product/[a-z0-9-]+)"',html)
    out=[]; seen=set()
    for i,n in enumerate(names):
        n=n.strip()
        if n in seen: continue
        seen.add(n)
        slug=slugs[i] if i < len(slugs) else "/product/"+re.sub(r'[^a-z0-9]+','-',n.lower()).strip('-')
        out.append({"name":n,"slug":slug})
    return out[:100]

def prices_from(text):
    return [float(x.replace(",","")) for x in re.findall(r"\$([0-9]{1,5}(?:\.[0-9]{2})?)", text)]

def price_google(q):
    u=f"https://www.google.com/search?q={urllib.parse.quote(q+' price buy')}"
    r=requests.get(u,headers=HEADERS,timeout=TIMEOUT); r.raise_for_status()
    c=prices_from(r.text)
    if not c: return None
    c=sorted(c)[:max(1,len(c)//4 or 1)]
    return round(c[len(c)//2],2)

def price_ebay(q):
    u=f"https://www.ebay.com/sch/i.html?_nkw={urllib.parse.quote(q)}"
    r=requests.get(u,headers=HEADERS,timeout=TIMEOUT); r.raise_for_status()
    c=prices_from(r.text)
    return round(min(c),2) if c else None

def price_walmart(q):
    u=f"https://www.walmart.com/search?q={urllib.parse.quote(q)}"
    r=requests.get(u,headers=HEADERS,timeout=TIMEOUT); r.raise_for_status()
    c=prices_from(r.text)
    return round(min(c),2) if c else None

def best_competitor_price(name):
    for fn in (price_walmart, price_ebay, price_google):
        try:
            p=fn(name)
            if p and p>0: return p
        except Exception:
            pass
    return None

def image_bing(name):
    u=f"https://www.bing.com/images/search?q={urllib.parse.quote(name)}"
    r=requests.get(u,headers=HEADERS,timeout=TIMEOUT)
    m=re.findall(r'murl&quot;:&quot;([^&"]+)', r.text)
    return m[0] if m else None

def cents(x): return int(round(x*100))
def undercut(p): return max(0.01, round(p-1.00,2))

def upsert(item, price, img, env):
    name=item["name"]; slug=item["slug"].split("/")[-1]
    adm=env.get("ADMIN_TOKEN","")
    payload={"slug":slug,"name":name,"price_cents":cents(price),"image_url":img or ""}
    urls=[]
    kc=(env.get("KEYSTONE_CATALOG_URL") or "").rstrip("/")
    if kc:
        urls += [kc+"/upsert", kc]
    base=base_url()
    urls += [f"{base}/api/catalog/upsert", f"{base}/api/admin/upsert"]
    for u in urls:
        try:
            r=requests.post(u,headers={"X-Admin-Token":adm},json=payload,timeout=TIMEOUT)
            if r.ok: return True,u
        except Exception:
            pass
    return False,None

def main():
    env=load_env()
    base=base_url()
    items=fetch_home_items(base)
    updated=0; flagged=[]
    for it in items:
        cp=best_competitor_price(it["name"])
        if not cp: flagged.append({"name":it["name"],"reason":"no_competitor"}); continue
        np=undercut(cp)
        img=image_bing(it["name"])
        ok,where=upsert(it,np,img,env)
        if ok: updated+=1
        else: flagged.append({"name":it["name"],"reason":"upsert_failed","price":np,"img":bool(img)})
        time.sleep(0.6+random.random()*0.5)
    print(json.dumps({"updated":updated,"flagged":flagged[:20],"total":len(items)}, indent=2))

if __name__=="__main__":
    main()
