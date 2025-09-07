#!/usr/bin/env python3
import subprocess, time, logging, json, os, re

# main watchdog log
logging.basicConfig(
    filename="logs/keystone_ai_runner.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s"
)

TARGETS = ["storefront", "tunnel"]
ENV_PATH = ".env"
TUNNEL_LOG = "logs/tunnel.log"
WEBHOOK_LOG = "logs/webhook_updates.log"

def pm2_status():
    try:
        return json.loads(subprocess.check_output(["pm2", "jlist"], text=True))
    except Exception as e:
        logging.error(f"pm2 jlist failed: {e}")
        return []

def restart(name):
    try:
        subprocess.check_call(["pm2", "restart", name])
        logging.info(f"restarted {name}")
    except Exception as e:
        logging.error(f"restart {name} failed: {e}")

def read_stripe_key():
    if not os.path.exists(ENV_PATH):
        logging.error(".env missing")
        return None
    with open(ENV_PATH) as f:
        for line in f:
            if line.startswith("STRIPE_SECRET_KEY="):
                return line.strip().split("=",1)[1]
    logging.error("STRIPE_SECRET_KEY not found in .env")
    return None

def get_pub_url():
    if not os.path.exists(TUNNEL_LOG):
        return None
    with open(TUNNEL_LOG) as f:
        text = f.read()
    m = re.findall(r"https://[A-Za-z0-9-]+\.trycloudflare\.com", text)
    return m[-1] if m else None

def register_webhook(pub_url, sk):
    try:
        out = subprocess.check_output([
            "curl", "-s", "https://api.stripe.com/v1/webhook_endpoints",
            "-u", f"{sk}:",
            "-d", f"url={pub_url}/api/stripe/webhook",
            "-d", "enabled_events[]=checkout.session.completed",
            "-d", "enabled_events[]=payment_intent.succeeded",
            "-d", "enabled_events[]=payment_intent.payment_failed"
        ], text=True)
        data = json.loads(out)
        whsec = data.get("secret")
        if whsec:
            lines = []
            with open(ENV_PATH) as f: lines = f.readlines()
            with open(ENV_PATH,"w") as f:
                written = False
                for line in lines:
                    if line.startswith("STRIPE_WEBHOOK_SECRET="):
                        f.write(f"STRIPE_WEBHOOK_SECRET={whsec}\n")
                        written = True
                    else:
                        f.write(line)
                if not written:
                    f.write(f"STRIPE_WEBHOOK_SECRET={whsec}\n")
            msg = f"Webhook registered with {pub_url} WHSEC={whsec}"
            logging.info(msg)
            with open(WEBHOOK_LOG, "a") as wf:
                wf.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
        else:
            logging.error(f"Webhook registration failed: {data}")
    except Exception as e:
        logging.error(f"register_webhook error: {e}")

last_pub_url = None
while True:
    procs = pm2_status()
    for t in TARGETS:
        found = next((p for p in procs if p["name"] == t), None)
        if not found or found["pm2_env"]["status"] != "online":
            logging.warning(f"{t} not online, restarting")
            restart(t)

    pub_url = get_pub_url()
    if pub_url and pub_url != last_pub_url:
        sk = read_stripe_key()
        if sk:
            register_webhook(pub_url, sk)
            last_pub_url = pub_url

    time.sleep(30)
