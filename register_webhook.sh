#!/usr/bin/env bash
set -euo pipefail

[ -f .env ] || { echo ".env missing"; exit 1; }
SK=$(grep -E '^STRIPE_SECRET_KEY=' .env | cut -d= -f2- | xargs)
[ -n "$SK" ] || { echo "STRIPE_SECRET_KEY missing"; exit 1; }

PUB_URL=$(grep -o 'https://[^ ]*trycloudflare.com' logs/tunnel.log | tail -n1)
[ -n "$PUB_URL" ] || { echo "Tunnel URL missing"; exit 1; }

WH=$(curl -s https://api.stripe.com/v1/webhook_endpoints -u "$SK:" \
  -d url="$PUB_URL/api/stripe/webhook" \
  -d 'enabled_events[]=checkout.session.completed' \
  -d 'enabled_events[]=payment_intent.succeeded' \
  -d 'enabled_events[]=payment_intent.payment_failed' | jq -r '.secret')

[ -n "$WH" ] && [ "$WH" != "null" ] || { echo "Webhook creation failed"; exit 1; }

sed -i "s/^STRIPE_WEBHOOK_SECRET=.*/STRIPE_WEBHOOK_SECRET=$WH/" .env
echo "Webhook registered. PUB_URL=$PUB_URL  WHSEC=$WH"
