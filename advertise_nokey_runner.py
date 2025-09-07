#!/usr/bin/env python3
import os,re,json,datetime,urllib.parse,urllib.request
ROOT=os.path.expanduser("~/keystone_storefront");PUB=os.path.join(ROOT,"public");BLOG=os.path.join(PUB,"blog");TUN=os.path.join(ROOT,"logs","tunnel.log")
def pub_url():
  t=open(TUN).read()
  m=re.findall(r"https://[A-Za-z0-9-]+\.trycloudflare\.com",t)
  if not m: raise SystemExit("no public URL")
  return m[-1].rstrip("/")
def fetch(base):
  try:
    html=urllib.request.urlopen(base,timeout=8).read().decode("utf-8","ignore")
    names=re.findall(r'<div style="font-weight:700">([^<]{3,80})</div>',html)
  except Exception:
    names=[]
  items=[]
  for n in names[:50]:
    slug=re.sub(r'[^a-z0-9]+','-',n.lower()).strip('-')
    items.append({"name":n.strip(),"slug":slug,"url":f"{base}/product/{slug}"})
  return items
def write(path,txt): 
  os.makedirs(os.path.dirname(path),exist_ok=True)
  with open(path,"w") as f: f.write(txt)
def main():
  base=pub_url();items=fetch(base)
  today=datetime.date.today().isoformat()
  now=datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S +0000")
  # sitemap
  urls=[base]+[i["url"] for i in items]
  sm=['<?xml version="1.0" encoding="UTF-8"?>','<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']+[
      f"<url><loc>{u}</loc><lastmod>{today}</lastmod><changefreq>daily</changefreq><priority>0.7</priority></url>" for u in urls]+["</urlset>"]
  write(os.path.join(PUB,"sitemap.xml"),"\n".join(sm))
  # rss
  rss=['<?xml version="1.0"?>','<rss version="2.0"><channel>',
       f"<title>Keystone Storefront</title>",f"<link>{base}</link>","<description>Daily picks</description>",
       f"<lastBuildDate>{now}</lastBuildDate>"]
  for it in items[:20]:
    rss+=["<item>",f"<title>{it['name']}</title>",f"<link>{it['url']}</link>",f"<guid>{it['url']}</guid>",f"<pubDate>{now}</pubDate>","</item>"]
  rss.append("</channel></rss>"); write(os.path.join(PUB,"rss.xml"),"\n".join(rss))
  # blog
  items_html="".join([f'<li><a href="{it["url"]}">{it["name"]}</a></li>' for it in items])
  blog=f'<!doctype html><html><head><meta charset="utf-8"><title>Top 50 · {today}</title><meta name="description" content="Top 50 trending products today"><link rel="canonical" href="{base}/blog/{today}.html"></head><body><h1>Top 50 · {today}</h1><ul>{items_html}</ul></body></html>'
  write(os.path.join(BLOG,f"{today}.html"),blog)
  # product schema
  schema=[{"@context":"https://schema.org","@type":"Product","name":it["name"],"url":it["url"],"brand":"Keystone","offers":{"@type":"Offer","price":"19.99","priceCurrency":"USD","availability":"https://schema.org/InStock"},"dateModified":datetime.datetime.utcnow().isoformat()+"Z"} for it in items]
  with open(os.path.join(PUB,"products.schema.json"),"w") as f: json.dump(schema,f,indent=2)
  # pings
  for ping in [f"https://www.google.com/ping?sitemap={urllib.parse.quote(base+'/sitemap.xml')}",f"https://www.bing.com/ping?sitemap={urllib.parse.quote(base+'/sitemap.xml')}"]:
    try: urllib.request.urlopen(ping,timeout=6).read()
    except Exception: pass
  print(json.dumps({"count":len(items),"sitemap":base+"/sitemap.xml","rss":base+"/rss.xml","blog":base+f"/blog/{today}.html","schema":base+"/products.schema.json"}))
if __name__=="__main__": main()
