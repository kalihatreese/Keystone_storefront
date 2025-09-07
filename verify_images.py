#!/usr/bin/env python3
import re,requests
from pathlib import Path
from envutil import load_env
HEADERS={"User-Agent":"Mozilla/5.0"}
TIMEOUT=10

def base_url():
    t=Path.home()/ "keystone_storefront"/"logs"/"tunnel.log"
    if t.exists():
        m=re.findall(r"https://[A-Za-z0-9-]+\.trycloudflare\.com", t.read_text())
        if m: return m[-1].rstrip("/")
    return "http://localhost:3000"

def has_img(html):
    return re.search(r'<img[^>]+src="https?://', html) is not None

def main():
    env=load_env()
    base=base_url()
    hp=requests.get(base,headers=HEADERS,timeout=TIMEOUT); hp.raise_for_status()
    slugs=sorted(set(re.findall(r'href="(/product/[a-z0-9-]+)"', hp.text)))[:50]
    missing=[]
    for s in slugs:
        r=requests.get(base+s,headers=HEADERS,timeout=TIMEOUT)
        if not has_img(r.text): missing.append(base+s)
    print({"product_pages_checked":len(slugs),"missing_images":missing[:10]})
