# Licensing

Each installation needs a licence key bound to its device. Keys are verified
on the device against an embedded public key, so no server is involved.

## The signing key

The RSA-4096 private key signs licence keys and PIN-reset tokens. It is **not
part of this repository** (`*.pem` is git-ignored). The scripts read it from
`$PRIVATE_KEY`, or by default from `~/.carrent/private_key.pem`:

```bash
mkdir -p ~/.carrent && chmod 700 ~/.carrent
# place private_key.pem there, then
chmod 600 ~/.carrent/private_key.pem
```

The matching public key is embedded in
`lib/core/license/asymmetric_crypto_helper.dart`; it can verify but not sign.
Anyone holding the private key can mint licences for any device, so store it
like a password and back it up somewhere private.

To rotate it, generate a new pair, replace the embedded public key, and ship a
new build. Existing licences and reset tokens stop verifying; installed apps
keep running until they next need a new one.

## Issuing a licence

1. Open the app's licence screen and copy the device ID.
2. Generate the key (needs only `openssl`):

   ```bash
   ./scripts/generate_license.sh "Customer Name" 2027-12-31 DEVICE_ID
   ./scripts/generate_license.sh "Customer Name" 2027-12-31 DEVICE_ID customer_history,profitability
   ```

3. Paste the output into the licence screen.

The optional fourth argument is a comma-separated list of feature keys (see
`lib/core/license/license_features.dart`). Features are decided when the key is
issued; changing them means issuing a new key, as for a renewal.

When there are no features the `features` field is omitted from the signed
JSON entirely. Licences issued before the field existed were signed without
it, and verification re-derives the JSON from the parsed object, so emitting an
empty array would invalidate them.

## PIN reset

A forgotten PIN is first recovered with the 12-digit recovery code shown at PIN
creation. If that is lost too, issue a signed, single-device, expiring token:

```bash
./scripts/generate_reset_token.sh DEVICE_ID
```

Both paths clear the PIN only; clients, contracts and payments are untouched.
