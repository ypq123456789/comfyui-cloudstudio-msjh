#!/usr/bin/env bash
set -euo pipefail

upstream="${CNB_XU_UPSTREAM_REGISTRY:-docker.cnb.cool/cnb-xu/docker}"
target_prefix="${CNB_XU_MIRROR_PREFIX:-${CNB_DOCKER_REGISTRY}/${CNB_REPO_SLUG_LOWERCASE}/cnb-xu-mirror}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command not found; run this from a CNB environment with docker service enabled" >&2
  exit 1
fi

mirror_image() {
  local image="$1"
  local tag="$2"
  local required="${3:-required}"
  local flat_image="${image//\//-}"
  local src="${upstream}/${image}:${tag}"
  local dst="${target_prefix}-${flat_image}:${tag}"

  echo "[mirror] ${src} -> ${dst}"
  if ! docker pull "${src}"; then
    if [ "${required}" = "optional" ]; then
      echo "[mirror] optional image not found, skip: ${src}"
      return 0
    fi
    return 1
  fi
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
mirror_image "comfyui-classic" "comfyui"
mirror_image "comfyui-classic" "custom_nodes" optional
mirror_image "comfyui-classic" "libs" optional
mirror_image "comfyui-classic" "comfy-libs" optional
mirror_image "comfyui-classic" "venv" optional
mirror_image "comfyui-dev" "custom_nodes" optional
mirror_image "comfyui-dev" "libs" optional
mirror_image "comfyui-dev" "comfy-libs" optional

echo "[mirror] done: ${target_prefix}-*"
