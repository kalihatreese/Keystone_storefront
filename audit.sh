#!/usr/bin/env bash
set -euo pipefail
ROOT=~/keystone_storefront
. "$ROOT/.venv/bin/activate" || { echo "venv missing"; exit 1; }

# availability check on home page instead of /api/health
URL=$(grep -o 'https://[^ ]*trycloudflare.com' "$ROOT/logs/tunnel.log" | tail -n1 || true)
URL=${URL:-http://localhost:3000}
curl -sS -o /dev/null -w "%{http_code}\n" "$URL/" | grep -qE '^(200|304)$' || { echo "store down: $URL"; exit 1; }

# refresh if route exists (ignore non-2xx)
CRON_PATH="${CRON_DAILY_REFRESH_PATH:-/api/tasks/daily-refresh}"
curl -sS -X POST "$URL$CRON_PATH" -H "X-Cron-Secret: ${CRON_SECRET:-change-this-cron-secret}" >/dev/null || true

# price + image update
python "$ROOT/reprice_and_enrich.py" | tee "$ROOT/logs/reprice_and_enrich.log"

# image audit
python "$ROOT/verify_images.py" | tee "$ROOT/logs/verify_images.log"

# stripe webhook ensure
python "$ROOT/payment_check.py" | tee "$ROOT/logs/payment_check.log"

# simple homepage verification
HP=$(curl -sS "$URL/")
distinct_prices=$(echo "$HP" | grep -Eo '\$[0-9]+\.[0-9]{2}' | sort -u | wc -l)
count_1999=$(echo "$HP" | grep -Eo '\$19\.99' | wc -l)
img_count=$(echo "$HP" | grep -Eo '<img[^>]+src="' | wc -l)

echo "URL=$URL"
echo "distinct_prices=$distinct_prices"
echo "price_19_99_count=$count_1999"
echo "home_img_tags=$img_count"
