#!/bin/sh
apk add --no-cache openssl
set -eu
mkdir -p /secrets
if [ ! -s /secrets/homebox_api_key_pepper ]; then
  echo "[homebox-init] generating HBOX_AUTH_API_KEY_PEPPER..."
  openssl rand -base64 48 > /secrets/homebox_api_key_pepper
else
  echo "[homebox-init] HBOX_AUTH_API_KEY_PEPPER already exists"
fi
v=$(cat /secrets/homebox_api_key_pepper)
if [ "${#v}" -lt 32 ]; then
  echo "[homebox-init] pepper too short, regenerating"
  openssl rand -base64 48 > /secrets/homebox_api_key_pepper
fi
echo "HBOX_AUTH_API_KEY_PEPPER=$(cat /secrets/homebox_api_key_pepper)" > /secrets/homebox.env
echo "[homebox-init] wrote homebox.env"