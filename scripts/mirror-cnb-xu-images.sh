#!/usr/bin/env bash
set -euo pipefail

upstream="${CNB_XU_UPSTREAM_REGISTRY:-docker.cnb.cool/cnb-xu/docker}"
target="${CNB_XU_MIRROR_REGISTRY:-${CNB_DOCKER_REGISTRY}/${CNB_REPO_SLUG_LOWERCASE}/cnb-xu-mirror}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command not found; run this from a CNB environment with docker service enabled" >&2
  exit 1
fi

mirror_image() {
  local image="$1"
  local tag="$2"
  local src="${upstream}/${image}:${tag}"
  local dst="${target}/${image}:${tag}"

  echo "[mirror] ${src} -> ${dst}"
  docker pull "${src}"
  docker tag "${src}" "${dst}"
  docker push "${dst}"
}

mirror_image "cnb-xu" "latest"
mirror_image "cnb-xu" "python3.12"
mirror_image "cnb-xu" "local"
mirror_image "cuda" "13.0.2-zh-hans-vscode"
mirror_image "cuda" "12.8.1-libs"
mirror_image "site-packages" "coscmd"
mirror_image "site-packages" "sageattention-cu130-cp312-for-l40"
mirror_image "site-packages" "torch-2.9.1-cu130-cp312"
mirror_image "site-packages" "nunchaku-for-torch-2.9.1-cu130-cp312"
mirror_image "site-packages" "torch-2.11.0-cu130-cp312"
mirror_image "site-packages" "nunchaku-for-torch-2.11.0-cu130-cp312"
mirror_image "comfyui-classic" "comfyui"
mirror_image "comfyui-classic" "custom_nodes"
mirror_image "comfyui-classic" "libs"
mirror_image "comfyui-classic" "comfy-libs"
mirror_image "comfyui-classic" "venv"
mirror_image "comfyui-diy" "comfyui"
mirror_image "comfyui-diy" "custom_nodes"
mirror_image "comfyui-diy" "libs"
mirror_image "comfyui-diy" "comfy-libs"
mirror_image "comfyui-diy" "venv"
mirror_image "comfyui-dev" "custom_nodes"
mirror_image "comfyui-dev" "libs"
mirror_image "comfyui-dev" "comfy-libs"
mirror_image "module" "ai-toolkit"
mirror_image "module" "ollama"

echo "[mirror] done: ${target}"
