#!/bin/bash
# Cloud Studio startup entrypoint for the MoRanJiangHu ComfyUI backend.

set -e

export CLOUDSTUDIO_IMAGE_BACKEND_PORT="${CLOUDSTUDIO_IMAGE_BACKEND_PORT:-${PORT:-8188}}"
export PYTHON_BIN="${PYTHON_BIN:-python}"
WORKSPACE_DIR="${CLOUDSTUDIO_WORKSPACE_DIR:-/workspace}"
COMFYUI_DIR="${CLOUDSTUDIO_COMFYUI_DIR:-${WORKSPACE_DIR}/comfyui}"

echo "[Cloud Studio Startup] Preparing MoRanJiangHu ComfyUI backend..."

ensure_comfyui_source() {
  if [ -f "${COMFYUI_DIR}/main.py" ]; then
    echo "[Cloud Studio Startup] Found ComfyUI source: ${COMFYUI_DIR}"
    return 0
  fi

  echo "[Cloud Studio Startup] ComfyUI main.py not found; bootstrapping source into ${COMFYUI_DIR}"
  mkdir -p "${COMFYUI_DIR}"

  TMP_DIR="$(mktemp -d)"
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${TMP_DIR}/ComfyUI"
  cp -af "${TMP_DIR}/ComfyUI"/. "${COMFYUI_DIR}/"
  rm -rf "${TMP_DIR}"
}

install_comfyui_requirements() {
  if [ ! -f "${COMFYUI_DIR}/requirements.txt" ]; then
    echo "[Cloud Studio Startup] requirements.txt not found; skip dependency install."
    return 0
  fi

  echo "[Cloud Studio Startup] Installing ComfyUI Python requirements..."
  "$PYTHON_BIN" -m pip install -r "${COMFYUI_DIR}/requirements.txt"
}

ensure_comfyui_source
install_comfyui_requirements

if [ -f "${WORKSPACE_DIR}/自定义初始化命令" ]; then
  INIT_SCRIPT="${WORKSPACE_DIR}/自定义初始化命令"
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

if [ ! -f "${COMFYUI_DIR}/main.py" ]; then
  echo "[Cloud Studio Startup] ComfyUI main.py still not found after bootstrap: ${COMFYUI_DIR}/main.py"
  exit 1
fi

cd "${COMFYUI_DIR}"

echo "[Cloud Studio Startup] Starting ComfyUI on port ${CLOUDSTUDIO_IMAGE_BACKEND_PORT}"
"$PYTHON_BIN" main.py --listen 0.0.0.0 --port "$CLOUDSTUDIO_IMAGE_BACKEND_PORT" --enable-cors-header "*" &
COMFYUI_PID="$!"

echo "[Cloud Studio Startup] Starting registry sync worker"
if [ -f "${WORKSPACE_DIR}/cloudstudio_sync.sh" ]; then
  ( bash "${WORKSPACE_DIR}/cloudstudio_sync.sh" 2>&1 | tee /tmp/cloudstudio_sync.log ) &
elif [ -f ../cloudstudio_sync.sh ]; then
  ( bash ../cloudstudio_sync.sh 2>&1 | tee /tmp/cloudstudio_sync.log ) &
else
  echo "[Cloud Studio Startup] cloudstudio_sync.sh not found; backend will not auto-register."
fi

wait "$COMFYUI_PID"
