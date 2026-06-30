#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SCRIPT="$ROOT_DIR/自定义初始化命令"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

extract_prefetch_functions() {
    awk '
        /^resolve_model_relpath\(\) \{/ { capture=1 }
        /^run_model_prefetch\(\) \{/ { exit }
        capture { print }
    ' "$INIT_SCRIPT"
}

MODEL_CACHE_DIR="$TMP_DIR/cache"
MODEL_LINK_DIR="$TMP_DIR/models"
export MODEL_CACHE_DIR MODEL_LINK_DIR

# shellcheck disable=SC1090
source <(extract_prefetch_functions)

assert_success() {
    local message="$1"
    shift
    if ! "$@"; then
        echo "FAIL: $message" >&2
        exit 1
    fi
}

assert_failure() {
    local message="$1"
    shift
    if "$@"; then
        echo "FAIL: $message" >&2
        exit 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $message" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    fi
}

expected_sha="96b875e4e3904555688998a07c45166322f98bb566f870b7d7e7f86cb5aecf70"
actual_sha="$(extract_expected_sha256 "https://cnb.cool/bacon159-2026/model/-/lfs/${expected_sha}?name=mPMix_NSFW_V9_fp8.safetensors")"
assert_equals "$expected_sha" "$actual_sha" "should extract sha256 from CNB LFS URL"

rel_path="diffusion_models/mPMix_NSFW_V9_fp8.safetensors"
cache="$MODEL_CACHE_DIR/$rel_path"
target="$MODEL_LINK_DIR/$rel_path"
mkdir -p "$(dirname "$cache")" "$(dirname "$target")"
printf 'broken partial content' > "$cache"
ln -s "$cache" "$target"
assert_failure "corrupt cached model must not be treated as ready" is_model_ready "$target" "$cache" "$expected_sha"

printf 'download in progress' > "$cache.part"
assert_failure ".part download must not be treated as ready" is_model_ready "$target" "$cache.part" "$expected_sha"

printf 'hello world' > "$cache"
good_sha="$(sha256sum "$cache" | awk '{print $1}')"
assert_success "matching cached model should be ready" is_model_ready "$target" "$cache" "$good_sha"

echo "model_prefetch_test passed"
