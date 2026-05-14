#!/usr/bin/env bash
set -euo pipefail

upstream="${CNB_XU_UPSTREAM_REGISTRY:-docker.cnb.cool/cnb-xu/docker}"
target="${CNB_XU_PATCHED_CORE_IMAGE:-${CNB_DOCKER_REGISTRY}/${CNB_REPO_SLUG_LOWERCASE}/cnb-xu-core:latest}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command not found; run this from a CNB environment with docker service enabled" >&2
  exit 1
fi

mkdir -p "${tmpdir}/nsfw_patch"
cp -f user/nsfw_patch/*.py "${tmpdir}/nsfw_patch/"

cat > "${tmpdir}/Dockerfile" <<EOF
FROM ${upstream}/cnb-xu:latest

COPY nsfw_patch/*.py /cnb-xu/script_py/

RUN set -eux; \\
    for so_name in hook_by_xu hook2_by_xu nsfw_checker_by_xu; do \\
      so_file="/cnb-xu/script_py/\${so_name}.cpython-312-x86_64-linux-gnu.so"; \\
      if [ -f "\${so_file}" ]; then mv "\${so_file}" "\${so_file}.disabled"; fi; \\
    done; \\
    for script in \\
      /cnb-xu/script/other/hotfix \\
      /cnb-xu/script/other/update-repo \\
      /cnb-xu/script/comfyui/switch; do \\
      if [ -f "\${script}" ]; then sed -i '1a exit 0' "\${script}"; fi; \\
    done
EOF

echo "[build] ${target}"
docker build -t "${target}" "${tmpdir}"
docker push "${target}"
echo "[build] done: ${target}"
