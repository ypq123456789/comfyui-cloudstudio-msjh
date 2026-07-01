#!/bin/bash
# Cloud Studio ComfyUI backend sync script for MoRanJiangHu.
# It reports the public 8188 preview URL to the game image backend registry.

set -e

SYNC_WEBHOOK_URL="${MSJH_IMAGE_BACKEND_SYNC_URL:-https://msjh.bacon.de5.net/api/image-backend/sync}"
SYNC_WEBHOOK_TOKEN="${MSJH_IMAGE_BACKEND_SYNC_TOKEN:-msjh_cnb_sync_2026_bacon_only}"
SPACE_ID="${X_IDE_SPACE_KEY:-${CLOUDSTUDIO_WORKSPACE_ID:-${HOSTNAME:-$(hostname 2>/dev/null || true)}}}"
USER_ID="${ACC_USER_ID:-${CLOUDSTUDIO_USER_ID:-}}"
USER_LABEL="${ACC_USER_NICKNAME:-${CLOUDSTUDIO_USER_NAME:-}}"
SYNC_CUSTOMER_ID="${CLOUDSTUDIO_CUSTOMER_ID:-${USER_ID:-${SPACE_ID:-cloudstudio}}}"
if [ -n "${CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN:-}" ]; then
  CONNECT_TOKEN="$CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN"
  CONNECT_TOKEN_SOURCE="CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN"
elif [ -n "${MSJH_IMAGE_BACKEND_CONNECT_TOKEN:-}" ]; then
  CONNECT_TOKEN="$MSJH_IMAGE_BACKEND_CONNECT_TOKEN"
  CONNECT_TOKEN_SOURCE="MSJH_IMAGE_BACKEND_CONNECT_TOKEN"
elif [ -n "${USER_ID:-}" ]; then
  CONNECT_TOKEN="$USER_ID"
  CONNECT_TOKEN_SOURCE="ACC_USER_ID"
elif [ -n "${SPACE_ID:-}" ]; then
  CONNECT_TOKEN="$SPACE_ID"
  CONNECT_TOKEN_SOURCE="X_IDE_SPACE_KEY"
else
  CONNECT_TOKEN="cloudstudio-$(date +%s)"
  CONNECT_TOKEN_SOURCE="generated-runtime-id"
fi
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
  local host="${SPACE_ID:-$(hostname 2>/dev/null || true)}"
  if [ -z "$domain" ] || [ -z "$host" ]; then
    return 1
  fi
  COMFY_URL="$(normalize_url "https://${host}--${PORT}.${domain}")"
  DETECTED_FROM="X_IDE_PREVIEW_DOMAIN+X_IDE_SPACE_KEY"
  return 0
}

wait_for_comfyui() {
  for _ in $(seq 1 180); do
    if curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
      echo "[墨色江湖云端生图] ComfyUI ${PORT} 已启动"
      return 0
    fi
    sleep 2
  done
  echo "[墨色江湖云端生图] ComfyUI ${PORT} 等待超时，请检查上方 ComfyUI 启动日志"
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

  echo "[墨色江湖云端生图] 没有自动识别到 Cloud Studio ${PORT} 公网预览地址。"
  echo "[墨色江湖云端生图] 请先在 Cloud Studio 端口预览里打开 ${PORT}，复制浏览器地址后执行："
  echo "[墨色江湖云端生图]   export CLOUDSTUDIO_IMAGE_BACKEND_URL=https://你的8188预览地址"
  echo "[墨色江湖云端生图] 如果想自定义游戏里填写的连接口令，可以执行："
  echo "[墨色江湖云端生图]   export CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN=你的私人短口令"
  echo "[墨色江湖云端生图] 下面是可用于排查的相关环境变量："
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
  workspace_escaped="$(json_escape "${CLOUDSTUDIO_WORKSPACE_NAME:-${USER_LABEL:-${SPACE_ID:-cloudstudio}}}")"
  detected_from_escaped="$(json_escape "$DETECTED_FROM")"
  health_url_escaped="$(json_escape "$COMFY_URL/system_stats")"

  curl -fsS -X POST "$SYNC_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SYNC_WEBHOOK_TOKEN" \
    -d "{\"customerId\":\"$customer_id_escaped\",\"backendType\":\"comfyui\",\"provider\":\"cloudstudio\",\"source\":\"cloudstudio\",\"port\":$PORT,\"url\":\"$url_escaped\",\"healthUrl\":\"$health_url_escaped\",\"detectedFrom\":\"$detected_from_escaped\",\"workspace\":\"$workspace_escaped\",\"connectToken\":\"$connect_token_escaped\"}"
}

wait_for_comfyui
discover_public_url

echo "[墨色江湖云端生图] 已识别 8188 公网地址：$COMFY_URL"
echo "[墨色江湖云端生图] 地址识别来源：$DETECTED_FROM"
echo "[墨色江湖云端生图] 连接口令来源：$CONNECT_TOKEN_SOURCE"

if sync_once; then
  echo "[墨色江湖云端生图] 已静默上报到墨色江湖自动发现注册表"
else
  echo "[墨色江湖云端生图] 首次上报失败。若 ComfyUI 页面能打开，请稍后执行 bash cloudstudio_sync.sh 重试"
  exit 1
fi

cat <<EOF

============================================================
墨色江湖 Cloud Studio ComfyUI 已就绪

请复制下面这一整行到墨色江湖设置页的“连接口令”：
$CONNECT_TOKEN

然后在墨色江湖里点击“刷新在线后端列表”，选择 cloudstudio 后端。
后台会继续自动保活上报；后续心跳只写入 /tmp/cloudstudio_sync.log，不再刷屏。
============================================================
EOF

while true; do
  sleep 60
  if sync_once; then
    echo "[墨色江湖云端生图] 后台保活上报成功 $(date)" >> /tmp/cloudstudio_sync.log
  else
    echo "[墨色江湖云端生图] 后台保活上报失败 $(date)" >> /tmp/cloudstudio_sync.log
  fi
done
