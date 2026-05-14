#!/usr/bin/env bash
set -euo pipefail

registry="${CNB_DOCKER_REGISTRY:-docker.cnb.cool}"
registry="${registry#https://}"
registry="${registry#http://}"
repo_prefix="${CNB_REPO_SLUG_LOWERCASE:?CNB_REPO_SLUG_LOWERCASE is required}"
user="${CNB_TOKEN_USER_NAME:-cnb}"
token="${CNB_TOKEN:?CNB_TOKEN is required}"

accept_header="Accept: application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json"

delete_tag() {
  local image="$1"
  local tag="$2"
  local repo="${repo_prefix}/${image}"
  local manifest_url="https://${registry}/v2/${repo}/manifests/${tag}"

  echo "[delete] lookup ${repo}:${tag}"
  local headers
  headers="$(curl -fsSI -u "${user}:${token}" -H "${accept_header}" "${manifest_url}" || true)"
  local digest
  digest="$(printf '%s\n' "${headers}" | awk 'BEGIN{IGNORECASE=1} /^Docker-Content-Digest:/ {gsub("\r","",$2); print $2; exit}')"

  if [ -z "${digest}" ]; then
    echo "[delete] not found or no digest, skip: ${repo}:${tag}"
    return 0
  fi

  echo "[delete] ${repo}:${tag} -> ${digest}"
  curl -fsS -X DELETE -u "${user}:${token}" "https://${registry}/v2/${repo}/manifests/${digest}" >/dev/null
  echo "[delete] removed ${repo}:${tag}"
}

delete_tag "cnb-xu-mirror-cnb-xu" "latest"
delete_tag "cnb-xu-mirror-cnb-xu" "python3.12"
delete_tag "cnb-xu-mirror-cnb-xu" "local"
delete_tag "cnb-xu-mirror-cuda" "13.0.2-zh-hans-vscode"
delete_tag "cnb-xu-mirror-cuda" "12.8.1-libs"
delete_tag "cnb-xu-mirror-site-packages" "coscmd"
delete_tag "cnb-xu-mirror-site-packages" "sageattention-cu130-cp312-for-l40"
delete_tag "cnb-xu-mirror-site-packages" "torch-2.9.1-cu130-cp312"
delete_tag "cnb-xu-mirror-site-packages" "nunchaku-for-torch-2.9.1-cu130-cp312"
delete_tag "cnb-xu-mirror-site-packages" "torch-2.11.0-cu130-cp312"
delete_tag "cnb-xu-mirror-site-packages" "nunchaku-for-torch-2.11.0-cu130-cp312"
delete_tag "cnb-xu-mirror-comfyui-classic" "comfyui"

echo "[delete] done"
