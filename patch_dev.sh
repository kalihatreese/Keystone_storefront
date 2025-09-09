#!/usr/bin/env bash
# Patch package.json dev script to default to port 3001
tmpfile=$(mktemp)
jq '.scripts.dev="PORT=${PORT:-3001} next dev"' package.json > "$tmpfile" && mv "$tmpfile" package.json
echo "package.json dev script updated to use port 3001 by default."
