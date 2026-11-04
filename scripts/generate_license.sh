#!/usr/bin/env bash
# CarRent Manager - portable licence generator.
#
# Needs only `openssl` and `base64`, so it runs anywhere without the Flutter
# or Dart SDK: macOS, Linux, or Windows via Git Bash / WSL.
#
# Usage:
#   ./generate_license.sh                     # interactive
#   ./generate_license.sh "Name" 2027-12-31 DEVICE_ID
#   ./generate_license.sh "Name" 2027-12-31 DEVICE_ID customer_history
#
# The 4th argument is an optional comma-separated list of feature keys to
# include (see lib/core/license/license_features.dart for the known keys).
# Leave it empty for a licence with no gated features.
#
# Needs the vendor private key, which is NOT in this repository. It is read from
# $PRIVATE_KEY if set, otherwise ~/.carrent/private_key.pem (see docs/licensing.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_KEY="${PRIVATE_KEY:-$HOME/.carrent/private_key.pem}"

if [ ! -f "$PRIVATE_KEY" ]; then
  echo "ERROR: private key not found at: $PRIVATE_KEY" >&2
  echo "Keep the vendor key outside the repo at ~/.carrent/private_key.pem, or set PRIVATE_KEY=/path/to/key" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is not installed or not on PATH." >&2
  exit 1
fi

NAME="${1:-}"
EXPIRY="${2:-}"
DEVICE_ID="${3:-}"
FEATURES="${4:-}"

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
if [ $# -lt 4 ]; then
  printf 'Features, comma-separated, or leave empty (e.g. customer_history): '
  read -r FEATURES
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
# `features` must be entirely absent (not even an empty array) when there are
# none, and sorted when there are - LicenseData.toMap() only emits it that
# way, so a licence with a different shape here fails to verify in the app.
if [ -n "$FEATURES" ]; then
  SORTED_FEATURES="$(printf '%s' "$FEATURES" | tr ',' '\n' | sed '/^$/d' | sort | paste -sd, -)"
  FEATURES_JSON="$(printf '%s' "$SORTED_FEATURES" | awk -F, '{
    printf "["; for (i=1;i<=NF;i++) { printf "%s\"%s\"", (i>1?",":""), $i } printf "]"
  }')"
  DATA_JSON="{\"name\":\"$NAME\",\"expiry\":\"${EXPIRY}T00:00:00.000\",\"device_id\":\"$DEVICE_ID\",\"features\":$FEATURES_JSON}"
else
  DATA_JSON="{\"name\":\"$NAME\",\"expiry\":\"${EXPIRY}T00:00:00.000\",\"device_id\":\"$DEVICE_ID\"}"
fi

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
echo "  features : ${FEATURES:-(none)}"
echo
echo "$LICENCE"
echo
echo "Also saved to: $SCRIPT_DIR/license_out.txt"
echo "Paste it into the app's licence screen on that device."
