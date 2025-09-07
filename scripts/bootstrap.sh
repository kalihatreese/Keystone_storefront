#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v node >/dev/null 2>&1 || { echo "Install Node 20+"; exit 1; }
npm install --silent
[ -f .env ] || cp .env.example .env
node services/worker/index.js --seed-only || true
npm run build
npm run start
