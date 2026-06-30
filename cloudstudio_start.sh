#!/bin/bash
# Cloud Studio startup entrypoint for the MoRanJiangHu ComfyUI backend.

set -e

export CLOUDSTUDIO_IMAGE_BACKEND_PORT="${CLOUDSTUDIO_IMAGE_BACKEND_PORT:-8188}"
export PYTHON_BIN="${PYTHON_BIN:-python}"

echo "[Cloud Studio Startup] Preparing MoRanJiangHu ComfyUI backend..."

if [ -f /workspace/自定义初始化命令 ]; then
  INIT_SCRIPT="/workspace/自定义初始化命令"
else
  INIT_SCRIPT="$(pwd)/自定义初始化命令"
fi

if [ -f "$INIT_SCRIPT" ]; then
  echo "[Cloud Studio Startup] Running existing initialization script: $INIT_SCRIPT"
  export MSJH_SKIP_COMFYUI_AUTOSTART=1
  bash "$INIT_SCRIPT"
else
  echo "[Cloud Studio Startup] Initialization script not found; continuing with direct ComfyUI startup."
fi

if [ -d /workspace/comfyui ]; then
  cd /workspace/comfyui
elif [ -d comfyui ]; then
  cd comfyui
else
  echo "[Cloud Studio Startup] ComfyUI directory not found. Expected /workspace/comfyui or ./comfyui."
  exit 1
fi

echo "[Cloud Studio Startup] Starting ComfyUI on port ${CLOUDSTUDIO_IMAGE_BACKEND_PORT}"
"$PYTHON_BIN" main.py --listen 0.0.0.0 --port "$CLOUDSTUDIO_IMAGE_BACKEND_PORT" --enable-cors-header "*" &
COMFYUI_PID="$!"

echo "[Cloud Studio Startup] Starting registry sync worker"
if [ -f /workspace/cloudstudio_sync.sh ]; then
  ( bash /workspace/cloudstudio_sync.sh 2>&1 | tee /tmp/cloudstudio_sync.log ) &
elif [ -f ../cloudstudio_sync.sh ]; then
  ( bash ../cloudstudio_sync.sh 2>&1 | tee /tmp/cloudstudio_sync.log ) &
else
  echo "[Cloud Studio Startup] cloudstudio_sync.sh not found; backend will not auto-register."
fi

wait "$COMFYUI_PID"
