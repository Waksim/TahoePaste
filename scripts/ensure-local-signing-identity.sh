#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${IDENTITY_NAME:-TahoePaste Local Development}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

if security find-certificate -a -c "$IDENTITY_NAME" "$KEYCHAIN_PATH" >/dev/null 2>&1; then
  exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

OPENSSL_CONFIG="$WORK_DIR/openssl.cnf"
PRIVATE_KEY_PATH="$WORK_DIR/tahoepaste-local.key"
CERTIFICATE_PATH="$WORK_DIR/tahoepaste-local.crt"
ARCHIVE_PATH="$WORK_DIR/tahoepaste-local.p12"
ARCHIVE_PASSWORD="TahoePasteLocalSigning"

cat > "$OPENSSL_CONFIG" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no

[dn]
CN = TahoePaste Local Development

[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -days 3650 \
  -nodes \
  -config "$OPENSSL_CONFIG" \
  -keyout "$PRIVATE_KEY_PATH" \
  -out "$CERTIFICATE_PATH" \
  >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -legacy \
  -inkey "$PRIVATE_KEY_PATH" \
  -in "$CERTIFICATE_PATH" \
  -out "$ARCHIVE_PATH" \
  -passout "pass:$ARCHIVE_PASSWORD" \
  >/dev/null 2>&1

security import "$ARCHIVE_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$ARCHIVE_PASSWORD" \
  -A \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  >/dev/null

if ! security find-certificate -a -c "$IDENTITY_NAME" "$KEYCHAIN_PATH" >/dev/null 2>&1; then
  echo "Failed to create local code signing identity: $IDENTITY_NAME" >&2
  exit 1
fi
