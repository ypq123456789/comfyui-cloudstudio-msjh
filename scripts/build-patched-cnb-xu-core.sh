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

COPY nsfw_patch/*.py /tmp/nsfw_patch/

RUN set -eux; \\
    core_dir=""; \\
    for candidate in /O.o-AI /cnb-xu; do \\
      if [ -d "\${candidate}" ]; then core_dir="\${candidate}"; break; fi; \\
    done; \\
    if [ -z "\${core_dir}" ]; then echo "cnb-xu core directory not found" >&2; exit 1; fi; \\
    mkdir -p "\${core_dir}/script_py"; \\
    cp -f /tmp/nsfw_patch/*.py "\${core_dir}/script_py/"; \\
    for so_name in hook_by_xu hook2_by_xu nsfw_checker_by_xu; do \\
      so_file="\${core_dir}/script_py/\${so_name}.cpython-312-x86_64-linux-gnu.so"; \\
      if [ -f "\${so_file}" ]; then mv "\${so_file}" "\${so_file}.disabled"; fi; \\
    done; \\
    for script in \\
      "\${core_dir}/script/other/hotfix" \\
      "\${core_dir}/script/other/update-repo" \\
      "\${core_dir}/script/comfyui/switch"; do \\
      if [ -f "\${script}" ]; then sed -i '1a exit 0' "\${script}"; fi; \\
    done
EOF

echo "[build] ${target}"
docker build -t "${target}" "${tmpdir}"
docker push "${target}"
echo "[build] done: ${target}"
