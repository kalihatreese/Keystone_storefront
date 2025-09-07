#!/usr/bin/env bash
set -euo pipefail

read -rsp "Enter STRIPE_SECRET_KEY (sk_live_...): " SK && echo
read -rsp "Enter STRIPE_PUBLISHABLE_KEY (pk_live_...): " PK && echo
read -rsp "Enter STRIPE_WEBHOOK_SECRET (whsec_...): " WH && echo

echo "========================================="
echo "Captured keys (sanitized):"
echo "STRIPE_SECRET_KEY=${SK:0:8}...${SK: -4}"
echo "STRIPE_PUBLISHABLE_KEY=${PK:0:8}...${PK: -4}"
echo "STRIPE_WEBHOOK_SECRET=${WH:0:8}...${WH: -4}"
echo "========================================="

# Optionally, write them directly into .env
cat > .env <<EOF
NODE_ENV=production
PORT=3000
STRIPE_SECRET_KEY=$SK
STRIPE_PUBLISHABLE_KEY=$PK
STRIPE_WEBHOOK_SECRET=$WH
EOF
echo ".env updated"
