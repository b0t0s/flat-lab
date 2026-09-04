#!/bin/sh
apk add --no-cache openssl
set -eu
mkdir -p /secrets
gen_hex() {
  if [ ! -s "/secrets/$1" ]; then
    echo "[outline-init] generating $1..."
    openssl rand -hex 32 > "/secrets/$1"
  else
    echo "[outline-init] $1 already exists"
  fi
  v=$(cat "/secrets/$1")
  if [ "${#v}" != 64 ] || ! echo "$v" | grep -qxE '[0-9a-f]{64}'; then
    echo "[outline-init] invalid $1, regenerating"
    openssl rand -hex 32 > "/secrets/$1"
  fi
}
gen_hex outline_secret_key
gen_hex outline_utils_secret
{
  echo "SECRET_KEY=$(cat /secrets/outline_secret_key)"
  echo "UTILS_SECRET=$(cat /secrets/outline_utils_secret)"
} > /secrets/outline.env
echo "[outline-init] wrote outline.env"
