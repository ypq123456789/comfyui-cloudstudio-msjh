#!/bin/bash
# CNB 域名上报脚本 - 持续上报 ComfyUI 访问地址

set -e

# 上报配置（硬编码，避免环境变量未注入）
SYNC_WEBHOOK_URL="https://msjh.bacon.de5.net/api/image-backend/cnb-sync"
SYNC_WEBHOOK_TOKEN="msjh_cnb_sync_2026_bacon_only"
SYNC_CUSTOMER_ID="${CNB_REPO_SLUG_LOWERCASE:-unknown}"

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

# 上报函数
sync_once() {
  curl -fsS -X POST "$SYNC_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SYNC_WEBHOOK_TOKEN" \
    -d "{\"customerId\":\"$SYNC_CUSTOMER_ID\",\"backendType\":\"comfyui\",\"url\":\"$COMFY_URL\",\"source\":\"cnb\",\"workspace\":\"${CNB_REPO_SLUG_LOWERCASE:-unknown}\"}"
}

# 首次上报
sync_once && echo "initial sync ok"

# 持续心跳上报（每60秒）
while true; do
  sleep 60
  sync_once && echo "heartbeat ok $(date)"
done
