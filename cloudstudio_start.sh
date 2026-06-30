#!/bin/bash
# Cloud Studio startup entrypoint for the MoRanJiangHu ComfyUI backend.

set -e

export CLOUDSTUDIO_IMAGE_BACKEND_PORT="${CLOUDSTUDIO_IMAGE_BACKEND_PORT:-${PORT:-8188}}"
export PYTHON_BIN="${PYTHON_BIN:-python}"
WORKSPACE_DIR="${CLOUDSTUDIO_WORKSPACE_DIR:-/workspace}"
COMFYUI_DIR="${CLOUDSTUDIO_COMFYUI_DIR:-${WORKSPACE_DIR}/comfyui}"

echo "[墨色江湖云端生图] 正在准备 Cloud Studio ComfyUI 后端..."

ensure_comfyui_source() {
  if [ -f "${COMFYUI_DIR}/main.py" ]; then
    echo "[墨色江湖云端生图] 已找到 ComfyUI 源码：${COMFYUI_DIR}"
    return 0
  fi

  echo "[墨色江湖云端生图] 未找到 ComfyUI main.py，正在初始化源码到 ${COMFYUI_DIR}"
  mkdir -p "${COMFYUI_DIR}"

  TMP_DIR="$(mktemp -d)"
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${TMP_DIR}/ComfyUI"
  cp -af "${TMP_DIR}/ComfyUI"/. "${COMFYUI_DIR}/"
  rm -rf "${TMP_DIR}"
}

install_comfyui_requirements() {
  if [ ! -f "${COMFYUI_DIR}/requirements.txt" ]; then
    echo "[墨色江湖云端生图] 未找到 requirements.txt，跳过依赖安装"
    return 0
  fi

  echo "[墨色江湖云端生图] 正在安装 ComfyUI Python 依赖..."
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
  echo "[墨色江湖云端生图] 正在运行初始化脚本：$INIT_SCRIPT"
  export MSJH_SKIP_COMFYUI_AUTOSTART=1
  bash "$INIT_SCRIPT"
else
  echo "[墨色江湖云端生图] 未找到初始化脚本，将直接启动 ComfyUI"
fi

if [ ! -f "${COMFYUI_DIR}/main.py" ]; then
  echo "[墨色江湖云端生图] 初始化后仍未找到 ComfyUI main.py：${COMFYUI_DIR}/main.py"
  exit 1
fi

cd "${COMFYUI_DIR}"

echo "[墨色江湖云端生图] 正在启动 ComfyUI，端口 ${CLOUDSTUDIO_IMAGE_BACKEND_PORT}"
"$PYTHON_BIN" main.py --listen 0.0.0.0 --port "$CLOUDSTUDIO_IMAGE_BACKEND_PORT" --enable-cors-header "*" &
COMFYUI_PID="$!"

echo "[墨色江湖云端生图] 正在启动墨色江湖自动发现上报进程"
if [ -f "${WORKSPACE_DIR}/cloudstudio_sync.sh" ]; then
  ( bash "${WORKSPACE_DIR}/cloudstudio_sync.sh" 2>&1 | tee /tmp/cloudstudio_sync.log ) &
elif [ -f ../cloudstudio_sync.sh ]; then
  ( bash ../cloudstudio_sync.sh 2>&1 | tee /tmp/cloudstudio_sync.log ) &
else
  echo "[墨色江湖云端生图] 未找到 cloudstudio_sync.sh，后端不会自动出现在游戏列表里"
fi

wait "$COMFYUI_PID"
