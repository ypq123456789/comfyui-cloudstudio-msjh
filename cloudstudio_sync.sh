#!/bin/bash
# Cloud Studio ComfyUI backend sync script for MoRanJiangHu.
# It reports the public 8188 preview URL to the game image backend registry.

set -e

SYNC_WEBHOOK_URL="${MSJH_IMAGE_BACKEND_SYNC_URL:-https://msjh.bacon.de5.net/api/image-backend/sync}"
SYNC_WEBHOOK_TOKEN="${MSJH_IMAGE_BACKEND_SYNC_TOKEN:-msjh_cnb_sync_2026_bacon_only}"
HOST_ID="${CLOUDSTUDIO_WORKSPACE_ID:-${HOSTNAME:-$(hostname 2>/dev/null || true)}}"
SYNC_CUSTOMER_ID="${CLOUDSTUDIO_CUSTOMER_ID:-${HOST_ID:-cloudstudio}}"
CONNECT_TOKEN="${CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN:-${MSJH_IMAGE_BACKEND_CONNECT_TOKEN:-${CLOUDSTUDIO_USER_NAME:-${USER:-cloudstudio}}}}"
PORT="${CLOUDSTUDIO_IMAGE_BACKEND_PORT:-8188}"
COMFY_URL=""
DETECTED_FROM=""

normalize_url() {
  printf '%s' "$1" | sed 's#/*$##'
}

build_from_template() {
  local template="$1"
  local value
  value="${template//\{\{port\}\}/$PORT}"
  value="${value//\$\{port\}/$PORT}"
  value="${value//%PORT%/$PORT}"
  value="${value//__PORT__/$PORT}"
  value="${value//3000/$PORT}"
  normalize_url "$value"
}

try_env_url() {
  local key="$1"
  local raw="${!key:-}"
  if [ -z "$raw" ]; then
    return 1
  fi
  COMFY_URL="$(build_from_template "$raw")"
  DETECTED_FROM="$key"
  return 0
}

try_cloudstudio_preview_url() {
  local domain="${X_IDE_PREVIEW_DOMAIN:-${CLOUDSTUDIO_PREVIEW_DOMAIN:-}}"
  local host="${HOST_ID:-$(hostname 2>/dev/null || true)}"
  if [ -z "$domain" ] || [ -z "$host" ]; then
    return 1
  fi
  COMFY_URL="$(normalize_url "https://${host}--${PORT}.${domain}")"
  DETECTED_FROM="X_IDE_PREVIEW_DOMAIN+HOSTNAME"
  return 0
}

wait_for_comfyui() {
  for _ in $(seq 1 180); do
    if curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
      echo "[Cloud Studio Sync] ComfyUI ${PORT} ready"
      return 0
    fi
    sleep 2
  done
  echo "[Cloud Studio Sync] ComfyUI ${PORT} did not become ready in time"
  return 1
}

discover_public_url() {
  try_env_url CLOUDSTUDIO_IMAGE_BACKEND_URL \
    || try_env_url CLOUDSTUDIO_COMFYUI_URL \
    || try_env_url CLOUDSTUDIO_PROXY_URI \
    || try_env_url VSCODE_PROXY_URI \
    || try_env_url PORT_FORWARDING_URI \
    || try_env_url GITPOD_WORKSPACE_URL \
    || try_cloudstudio_preview_url \
    || true

  if [ -n "$COMFY_URL" ]; then
    return 0
  fi

  echo "[Cloud Studio Sync] No public ComfyUI URL found from environment."
  echo "[Cloud Studio Sync] Open Cloud Studio's port/preview panel for ${PORT}, then set:"
  echo "[Cloud Studio Sync]   export CLOUDSTUDIO_IMAGE_BACKEND_URL=https://your-preview-url"
  echo "[Cloud Studio Sync] To identify your own backend in MoRanJiangHu, set:"
  echo "[Cloud Studio Sync]   export CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN=your-private-short-code"
  echo "[Cloud Studio Sync] Relevant environment variables:"
  env | grep -E "CLOUDSTUDIO|VSCODE|PORT|PROXY|PREVIEW|FORWARD" || true
  return 1
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

sync_once() {
  local customer_id_escaped url_escaped connect_token_escaped workspace_escaped detected_from_escaped health_url_escaped
  customer_id_escaped="$(json_escape "$SYNC_CUSTOMER_ID")"
  url_escaped="$(json_escape "$COMFY_URL")"
  connect_token_escaped="$(json_escape "$CONNECT_TOKEN")"
  workspace_escaped="$(json_escape "${CLOUDSTUDIO_WORKSPACE_NAME:-${CLOUDSTUDIO_WORKSPACE_ID:-cloudstudio}}")"
  detected_from_escaped="$(json_escape "$DETECTED_FROM")"
  health_url_escaped="$(json_escape "$COMFY_URL/system_stats")"

  curl -fsS -X POST "$SYNC_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SYNC_WEBHOOK_TOKEN" \
    -d "{\"customerId\":\"$customer_id_escaped\",\"backendType\":\"comfyui\",\"provider\":\"cloudstudio\",\"source\":\"cloudstudio\",\"port\":$PORT,\"url\":\"$url_escaped\",\"healthUrl\":\"$health_url_escaped\",\"detectedFrom\":\"$detected_from_escaped\",\"workspace\":\"$workspace_escaped\",\"connectToken\":\"$connect_token_escaped\"}"
}

wait_for_comfyui
discover_public_url

echo "[Cloud Studio Sync] Detected ComfyUI URL: $COMFY_URL"
echo "[Cloud Studio Sync] Detected from: $DETECTED_FROM"
echo "[Cloud Studio Sync] Auto connect identifier is configured; value will not be printed."

sync_once && echo "[Cloud Studio Sync] initial sync ok"

while true; do
  sleep 60
  sync_once && echo "[Cloud Studio Sync] heartbeat ok $(date)"
done
