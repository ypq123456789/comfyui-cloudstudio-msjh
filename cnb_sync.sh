#!/bin/bash
# CNB 域名上报脚本 - 持续上报 ComfyUI 访问地址
# 自动连接标识默认使用 CNB 用户名称：CNB_BUILD_USER_NICKNAME

set -e

# 上报配置（硬编码，避免环境变量未注入）
SYNC_WEBHOOK_URL="https://msjh.bacon.de5.net/api/image-backend/cnb-sync"
SYNC_WEBHOOK_TOKEN="msjh_cnb_sync_2026_bacon_only"
SYNC_CUSTOMER_ID="${CNB_REPO_SLUG_LOWERCASE:-${CNB_REPO_SLUG:-unknown}}"

# 自动连接标识：
# 1. 如果客户显式设置 CNB_IMAGE_BACKEND_CONNECT_TOKEN / CNB_SYNC_CONNECT_TOKEN，则优先使用
# 2. 否则默认使用 CNB 用户名称 CNB_BUILD_USER_NICKNAME
# 3. 再兜底到 ACC_USER_NICKNAME / CNB_BUILD_USER / 仓库路径
CONNECT_TOKEN="${CNB_IMAGE_BACKEND_CONNECT_TOKEN:-${CNB_SYNC_CONNECT_TOKEN:-}}"
if [ -z "$CONNECT_TOKEN" ]; then
  CONNECT_TOKEN="${CNB_BUILD_USER_NICKNAME:-${ACC_USER_NICKNAME:-${CNB_BUILD_USER:-${CNB_REPO_SLUG_LOWERCASE:-${CNB_REPO_SLUG:-unknown}}}}}"
fi

# 等待 ComfyUI 就绪
for i in $(seq 1 180); do
  if curl -fsS --max-time 5 http://127.0.0.1:8188/ > /dev/null; then
    echo "ComfyUI 8188 ready"
    break
  fi
  sleep 2
done

if ! curl -fsS --max-time 5 http://127.0.0.1:8188/ > /dev/null; then
  echo "ComfyUI 8188 did not become ready in time"
  tail -n 200 /tmp/comfyui.log 2>/dev/null || true
  exit 1
fi

# 获取代理 URI
BASE_URI="${CNB_VSCODE_PROXY_URI:-${VSCODE_PROXY_URI:-${PORT_FORWARDING_URI:-}}}"
if [ -z "$BASE_URI" ]; then
  echo "No CNB proxy URI found from environment"
  env | grep -E "CNB|VSCODE|PORT" || true
  exit 1
fi

# 拼接 ComfyUI 访问地址
COMFY_URL="${BASE_URI//\{\{port\}\}/8188}"
COMFY_URL="${COMFY_URL%/}"

echo "Detected ComfyUI URL: $COMFY_URL"
echo "Auto connect identifier: $CONNECT_TOKEN"

# JSON 转义，避免昵称里有特殊字符时 payload 坏掉
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# 上报函数
sync_once() {
  CUSTOMER_ID_ESCAPED="$(json_escape "$SYNC_CUSTOMER_ID")"
  COMFY_URL_ESCAPED="$(json_escape "$COMFY_URL")"
  CONNECT_TOKEN_ESCAPED="$(json_escape "$CONNECT_TOKEN")"
  WORKSPACE_ESCAPED="$(json_escape "${CNB_REPO_SLUG_LOWERCASE:-${CNB_REPO_SLUG:-unknown}}")"

  curl -fsS -X POST "$SYNC_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SYNC_WEBHOOK_TOKEN" \
    -d "{\"customerId\":\"$CUSTOMER_ID_ESCAPED\",\"backendType\":\"comfyui\",\"url\":\"$COMFY_URL_ESCAPED\",\"source\":\"cnb\",\"workspace\":\"$WORKSPACE_ESCAPED\",\"connectToken\":\"$CONNECT_TOKEN_ESCAPED\"}"
}

# 首次上报
sync_once && echo "initial sync ok"

# 持续心跳上报（每60秒）
while true; do
  sleep 60
  sync_once && echo "heartbeat ok $(date)"
done
