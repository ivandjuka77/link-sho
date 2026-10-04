#!/usr/bin/env bash

set -euo pipefail

# Send example.com, assign return value as the CODE variable.
# Return is JSON, extract actual code value from JSON.
CODE=$(curl -s -X POST http://localhost:8080/api/shorten \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com"}' | jq -r .code)

# Check if it's empty or null
if [ -z "$CODE" ] || [ "$CODE" = "null" ]; then
  echo "FAIL: POST /shorten did not return a code" >&2
  exit 1
fi

# Verify code works, use the shortened link and get the location
URL=$(curl -s -o /dev/null -w '%{redirect_url}' http://localhost:8080/$CODE)
echo "$URL"

# Set expected variable
EXPECTED="https://example.com/"

# Check if it's a missmatch, otherwise pass
if [ "$URL" != "$EXPECTED" ]; then
  echo "FAIL: Expected $EXPECTED, got $URL" >&2
  exit 1
fi

echo "passes."
