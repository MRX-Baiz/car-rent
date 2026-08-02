#!/usr/bin/env bash
# CarRent Manager - PIN reset token generator.
#
# For the customer who forgot their PIN *and* lost their recovery code. The
# token unlocks one device, briefly, and leaves all their data in place.
#
# Like generate_license.sh it needs only `openssl` and `base64`, so it runs on
# macOS, Linux, or Windows via Git Bash / WSL without the Flutter SDK.
#
# Usage:
#   ./generate_reset_token.sh                        # interactive
#   ./generate_reset_token.sh DEVICE_ID              # 24 hours
#   ./generate_reset_token.sh DEVICE_ID 72           # valid 72 hours
#
# Requires private_key.pem beside this script (or set PRIVATE_KEY=/path).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_KEY="${PRIVATE_KEY:-$SCRIPT_DIR/private_key.pem}"

if [ ! -f "$PRIVATE_KEY" ]; then
  echo "ERROR: private key not found at: $PRIVATE_KEY" >&2
  echo "Place private_key.pem next to this script, or set PRIVATE_KEY=/path/to/key" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is not installed or not on PATH." >&2
  exit 1
fi

DEVICE_ID="${1:-}"
HOURS="${2:-24}"

if [ -z "$DEVICE_ID" ]; then
  printf 'Device ID (read it from the app lock screen): '
  read -r DEVICE_ID
fi

if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: device ID is required - a token unlocks exactly one device." >&2
  exit 1
fi

if ! printf '%s' "$HOURS" | grep -Eq '^[0-9]+$' || [ "$HOURS" -lt 1 ]; then
  echo "ERROR: validity must be a whole number of hours, e.g. 24" >&2
  exit 1
fi

# UTC with a trailing Z, so the token means the same instant whichever timezone
# you and the customer are in.
if date -u -v+1H >/dev/null 2>&1; then
  EXPIRY="$(date -u -v+"${HOURS}"H +%Y-%m-%dT%H:%M:%S.000Z)"   # BSD / macOS
else
  EXPIRY="$(date -u -d "+${HOURS} hours" +%Y-%m-%dT%H:%M:%S.000Z)"  # GNU
fi

# The serial only has to increase, and the app remembers the highest it has
# accepted. Using the current epoch second means you never have to track what
# you last issued for a device - it is monotonic for free.
SERIAL="$(date -u +%s)"

# Must match PinResetToken.encodeData byte for byte: compact separators and
# this key order. The signature covers this exact string.
DATA_JSON="{\"device_id\":\"$DEVICE_ID\",\"serial\":$SERIAL,\"expiry\":\"$EXPIRY\"}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf '%s' "$DATA_JSON" > "$TMP_DIR/data.json"

# RSA-PSS with SHA-256, matching AsymmetricCryptoHelper.verify in the app.
openssl dgst -sha256 \
  -sign "$PRIVATE_KEY" \
  -sigopt rsa_padding_mode:pss \
  -sigopt rsa_pss_saltlen:digest \
  -out "$TMP_DIR/sig.bin" \
  "$TMP_DIR/data.json"

SIGNATURE="$(base64 < "$TMP_DIR/sig.bin" | tr -d '\n')"

PACKAGE_JSON="{\"data\":$DATA_JSON,\"signature\":\"$SIGNATURE\"}"
TOKEN="$(printf '%s' "$PACKAGE_JSON" | base64 | tr -d '\n')"

printf '%s' "$TOKEN" > "$SCRIPT_DIR/reset_token_out.txt"

echo
echo "--- RESET TOKEN GENERATED ---"
echo "  device  : $DEVICE_ID"
echo "  expires : $EXPIRY (in ${HOURS}h)"
echo "  serial  : $SERIAL"
echo
echo "$TOKEN"
echo
echo "Saved to: $SCRIPT_DIR/reset_token_out.txt"
echo
echo "Send it to the customer. On the lock screen they tap 'Code oublié ?',"
echo "then 'J'ai un code fourni par le vendeur'. Their data is untouched:"
echo "only the PIN is cleared, and they choose a new one straight after."
