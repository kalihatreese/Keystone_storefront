#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_LOG="./logs/app.log"; STRIPE_LOG="./logs/stripe.log"; PORT=3000; WEBHOOK_PATH="/api/stripe/webhook"
mkdir -p logs data
ts="$(date +'%Y%m%d-%H%M%S')"
[ -f "$APP_LOG" ] && mv -f "$APP_LOG" "./logs/app.$ts.log"
[ -f "$STRIPE_LOG" ] && mv -f "$STRIPE_LOG" "./logs/stripe.$ts.log"
[ -f data/store.json ] || echo '{"config":{},"products":[],"orders":[],"events":[]}' > data/store.json
fuser -k ${PORT}/tcp 2>/dev/null || true; pkill -f 'next start' 2>/dev/null || true; pkill -f 'node .*next' 2>/dev/null || true; pkill -f 'stripe listen' 2>/dev/null || true
grep -qE '^STRIPE_SECRET_KEY=sk_(test|live)_' .env || { echo "STRIPE_SECRET_KEY invalid/missing"; exit 1; }
grep -qE '^STRIPE_WEBHOOK_SECRET=whsec_' .env || { echo "STRIPE_WEBHOOK_SECRET invalid/missing"; exit 1; }
npm run start > "$APP_LOG" 2>&1 & APP_PID=$!
stripe listen --forward-to "http://localhost:${PORT}${WEBHOOK_PATH}" > "$STRIPE_LOG" 2>&1 & LISTEN_PID=$!
echo "next pid=$APP_PID | stripe-listen pid=$LISTEN_PID"; echo "logs -> $APP_LOG , $STRIPE_LOG"; echo "tailing events..."; tail -f data/store.json
