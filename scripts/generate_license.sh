#!/usr/bin/env bash
# CarRent Manager - portable licence generator.
#
# Needs only `openssl` and `base64`, so it runs anywhere without the Flutter
# or Dart SDK: macOS, Linux, or Windows via Git Bash / WSL.
#
# Usage:
#   ./generate_license.sh                     # interactive
#   ./generate_license.sh "Name" 2027-12-31 DEVICE_ID
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

NAME="${1:-}"
EXPIRY="${2:-}"
DEVICE_ID="${3:-}"

if [ -z "$NAME" ]; then
  printf 'Customer name: '
  read -r NAME
fi
if [ -z "$EXPIRY" ]; then
  printf 'Expiry date (YYYY-MM-DD): '
  read -r EXPIRY
fi
if [ -z "$DEVICE_ID" ]; then
  printf 'Device ID (copy it from the app licence screen): '
  read -r DEVICE_ID
fi

if ! printf '%s' "$EXPIRY" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "ERROR: expiry must look like 2027-12-31" >&2
  exit 1
fi
if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: device ID is required - a licence is bound to one device." >&2
  exit 1
fi

# Must match Dart's json.encode(LicenseData.toMap()) byte for byte: compact
# separators, this key order, and DateTime.toIso8601String()'s milliseconds.
# The signature covers this exact string, so any difference breaks validation.
DATA_JSON="{\"name\":\"$NAME\",\"expiry\":\"${EXPIRY}T00:00:00.000\",\"device_id\":\"$DEVICE_ID\"}"

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
LICENCE="$(printf '%s' "$PACKAGE_JSON" | base64 | tr -d '\n')"

printf '%s' "$LICENCE" > "$SCRIPT_DIR/license_out.txt"

echo
echo "--- LICENCE GENERATED ---"
echo "  customer : $NAME"
echo "  expires  : $EXPIRY"
echo "  device   : $DEVICE_ID"
echo
echo "$LICENCE"
echo
echo "Also saved to: $SCRIPT_DIR/license_out.txt"
echo "Paste it into the app's licence screen on that device."
