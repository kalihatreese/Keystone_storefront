#!/usr/bin/env python3
import os, json, time, re, datetime, requests, tweepy

ENV = os.path.expanduser("~/keystone_storefront/.env")
TUNNEL_LOG = os.path.expanduser("~/keystone_storefront/logs/tunnel.log")
STATE = os.path.expanduser("~/keystone_storefront/ads/post_state.json")
ADS_DIR = os.path.expanduser("~/keystone_storefront/ads")
os.makedirs(ADS_DIR, exist_ok=True)

def load_env(path):
    if not os.path.exists(path): raise SystemExit(".env missing")
    with open(path) as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                k,v = line.strip().split("=",1); os.environ.setdefault(k, v)

def req(k):
    v = os.getenv(k,"").strip()
    if not v: raise SystemExit(f"env {k} missing")
    return v

def get_pub_url():
    if not os.path.exists(TUNNEL_LOG): raise SystemExit("tunnel.log missing")
    t = open(TUNNEL_LOG).read()
    m = re.findall(r"https://[A-Za-z0-9-]+\.trycloudflare\.com", t)
    if not m: raise SystemExit("no trycloudflare URL found")
    return m[-1]

def load_state():
    if os.path.exists(STATE):
        try: return json.load(open(STATE))
        except: pass
    return {"day": datetime.date.today().isoformat(), "count": 0}

def save_state(s): json.dump(s, open(STATE,"w"))

def compose_message(url):
    try:
        html = requests.get(url, timeout=5).text
        names = re.findall(r'>([A-Za-z0-9 ,.&\'/-]{3,40})</div><div style="color:#666', html)
        picks = [n.strip() for n in names[:3] if len(n.strip())>2]
        if picks: return f"Trending today: {', '.join(picks[:3])}. Shop → {url}"
    except: pass
    return f"Today’s hottest picks are live. Shop → {url}"

def post_tweet(text):
    client = tweepy.Client(
        consumer_key=req("TWITTER_API_KEY"),
        consumer_secret=req("TWITTER_API_SECRET"),
        access_token=req("TWITTER_ACCESS_TOKEN"),
        access_token_secret=req("TWITTER_ACCESS_SECRET"),
        bearer_token=req("TWITTER_BEARER_TOKEN"),
    )
    r = client.create_tweet(text=text)
    return r.data

def main():
    load_env(ENV)
    s = load_state()
    today = datetime.date.today().isoformat()
    DAILY_CAP = int(os.getenv("TWITTER_DAILY_CAP","12"))
    if s["day"] != today: s = {"day": today, "count": 0}
    if s["count"] >= DAILY_CAP:
        print(f"skip: cap {DAILY_CAP}"); save_state(s); return
    url = get_pub_url()
    text = compose_message(url)
    data = post_tweet(text)
    s["count"] += 1; save_state(s)
    with open(os.path.join(ADS_DIR, f"ads_live_{today}.jsonl"),"a") as f:
        f.write(json.dumps({"ts":int(time.time()),"tweet":data,"text":text})+"\n")
    print(f"posted: {data} -> {text}")

if __name__ == "__main__": main()
