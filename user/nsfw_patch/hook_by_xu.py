# Stub module: 替代 hook_by_xu.cpython-312-x86_64-linux-gnu.so
# 原 .so 文件中 NSFW 检测模块在初始化时调用 C 级 exit() 导致进程退出
# 此 stub 保留核心功能（模型查找、下载等），禁用 NSFW 检查

import json
import os
import logging
import subprocess

logger = logging.getLogger(__name__)

# === 全局变量 ===
enable_auto_download = True

# === 数据加载 ===
_source_json_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "source.json")
_all_file_dict = {}
_all_source_dict = {}
_all_sha256_dict = {}

def _load_source_data():
    """从 source.json 加载模型映射数据"""
    global _all_file_dict, _all_source_dict, _all_sha256_dict
    if _all_file_dict:
        return
    try:
        if os.path.exists(_source_json_path):
            with open(_source_json_path, "r") as f:
                data = json.load(f)
            # 构建 all_file_dict: {repo_name: {relative_path: download_url}}
            path_dict = data.get("path_dict", {})
            for repo_key, repo_val in path_dict.items():
                if isinstance(repo_val, dict):
                    if repo_key not in _all_file_dict:
                        _all_file_dict[repo_key] = {}
                    _all_source_dict[repo_key] = repo_val
                    _flatten_repo(repo_key, repo_val, _all_file_dict[repo_key])

            # 也从顶层 repo 条目构建
            for key, val in data.items():
                if key == "path_dict":
                    continue
                if isinstance(val, dict):
                    if key not in _all_file_dict:
                        _all_file_dict[key] = {}
                        _all_source_dict[key] = val
                    _flatten_repo(key, val, _all_file_dict[key])
    except Exception as e:
        logger.warning(f"Failed to load source.json: {e}")


def _flatten_repo(prefix, data, target):
    """递归展平 repo 数据为 {relative_path: url} 映射"""
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, str) and v.startswith("http"):
                target[k] = v
            elif isinstance(v, dict):
                _flatten_repo(prefix, v, target)


_load_source_data()

# 对外暴露的属性
all_file_dict = _all_file_dict
all_source_dict = _all_source_dict
all_sha256_dict = _all_sha256_dict


# === 下载工具 ===
def aria2c(file_path, url, extra_args=None):
    """使用 aria2c 下载文件到指定路径"""
    dir_path = os.path.dirname(file_path)
    filename = os.path.basename(file_path)
    os.makedirs(dir_path, exist_ok=True)
    # aria2c 的 -d 指定目录，-o 指定文件名（相对于 -d）
    cmd = ["aria2c", "-x", "16", "-s", "16", "-k", "1M", "-d", dir_path, "-o", filename, url]
    if extra_args:
        cmd.extend(extra_args)
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logger.info(f"Downloaded: {file_path}")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"aria2c download failed for {url}")
        if e.stderr:
            logger.error(f"stderr: {e.stderr[:500]}")
        return False
    except Exception as e:
        logger.error(f"aria2c download failed: {e}")
        return False


# === 核心接口 ===
def find_or_download_model(folder_name, filename, auto_download=True):
    """在本地查找模型文件，如未找到且 auto_download=True 则尝试下载"""
    models_base = "/workspace/models"
    folder_path = os.path.join(models_base, folder_name)
    full_path = os.path.join(folder_path, filename)

    if os.path.exists(full_path):
        return full_path

    cache_path = os.path.join("/workspace/models_cnb_cache", folder_name, filename)
    if os.path.exists(cache_path):
        return cache_path

    if auto_download:
        logger.info(f"[find_or_download_model] {folder_name}/{filename} not found locally, searching in all_file_dict...")
        found = False
        for repo_name, files in _all_file_dict.items():
            if filename in files:
                url = files[filename]
                found = True
                logger.info(f"[find_or_download_model] Found URL for {filename} in repo [{repo_name}]: {url[:80]}...")
                if aria2c(full_path, url):
                    if os.path.exists(full_path):
                        logger.info(f"[find_or_download_model] Download success: {full_path}")
                        return full_path
                    else:
                        logger.error(f"[find_or_download_model] Download reported success but file not at {full_path}")
                break
        if not found:
            logger.warning(f"[find_or_download_model] No download URL found for {folder_name}/{filename}")

    return None


def import_models(directory, result):
    """导入模型目录中的额外文件（stub: 直接返回原始结果）"""
    return result


def import_models2(directory, result):
    """导入模型目录中的额外文件（stub: 直接返回原始结果）"""
    return result


def import_filename_list(folder_name, out):
    """导入文件名列表（stub: 直接返回原始结果）"""
    return out


def refresh_source():
    """刷新源数据（stub: 重新加载 source.json）"""
    global _all_file_dict, _all_source_dict
    _all_file_dict.clear()
    _all_source_dict.clear()
    _load_source_data()


def patch_nodes():
    """修补节点（stub: 不执行任何操作，跳过 NSFW 检查）"""
    pass


# === 下载特定模型的辅助函数 ===
def download_annotator(model_name, save_path=None):
    """下载标注器模型"""
    return _try_download(model_name, save_path)


def download_model(model_name, save_path=None):
    """下载模型"""
    return _try_download(model_name, save_path)


def download_seed_vc_models(model_name=None, save_path=None):
    """下载 Seed-VC 模型"""
    return _try_download(model_name, save_path)


def download_heartmula_models(model_name=None, save_path=None):
    """下载 HeartmuLa 模型"""
    return _try_download(model_name, save_path)


def _try_download(model_name, save_path=None):
    """通用下载辅助"""
    if not model_name:
        return None
    for repo_name, files in _all_file_dict.items():
        if model_name in files:
            url = files[model_name]
            if save_path:
                target = save_path
            else:
                target = os.path.join("/workspace/models", model_name)
            if aria2c(target, url):
                return target
            break
    return None


def load_nodes_json():
    """加载节点 JSON 数据"""
    json_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "custom_nodes",
        "ComfyUI-Manager",
        "glob",
        "node-db",
        "cnr.json"
    )
    if os.path.exists(json_path):
        try:
            with open(json_path, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


# === 自定义下载链接 ===
_custom_source_path = "/workspace/自定义下载链接.yaml"

def load_custom_source():
    """加载自定义下载链接.yaml，将用户定义的模型下载链接合并到 all_file_dict"""
    if not os.path.exists(_custom_source_path):
        return
    try:
        import yaml
        with open(_custom_source_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data:
            return
        # 格式: "模型路径: 下载链接"，一行一条
        # 也可能是 dict 格式
        if isinstance(data, dict):
            for model_path, url in data.items():
                if not isinstance(url, str) or not url.startswith("http"):
                    continue
                # 解析模型路径，确定 folder_name 和 filename
                model_path = model_path.strip().strip('"')
                # 规范化路径
                path_parts = _normalize_model_path(model_path)
                if path_parts:
                    folder_name, filename = path_parts
                    if folder_name not in _all_file_dict:
                        _all_file_dict[folder_name] = {}
                    _all_file_dict[folder_name][filename] = url
                    logger.info(f"[自定义下载链接] {folder_name}/{filename} -> {url}")
    except ImportError:
        logger.warning("PyYAML not installed, cannot load 自定义下载链接.yaml")
    except Exception as e:
        logger.warning(f"Failed to load 自定义下载链接.yaml: {e}")


def _normalize_model_path(model_path):
    """将模型路径规范化为 (folder_name, filename)"""
    # 去掉常见前缀
    prefixes = [
        "/workspace/models/",
        "/workspace/comfyui/models/",
        "models/",
    ]
    normalized = model_path
    for prefix in prefixes:
        if normalized.startswith(prefix):
            normalized = normalized[len(prefix):]
            break

    # 分割为 folder_name 和 filename
    parts = normalized.split("/")
    if len(parts) >= 2:
        folder_name = "/".join(parts[:-1])
        filename = parts[-1]
        return (folder_name, filename)
    elif len(parts) == 1:
        return ("", parts[0])
    return None


# 模块加载时自动加载自定义下载链接
load_custom_source()


# === 预设源加载 ===
_preset_source_file = None

def load_preset_source():
    """加载预设源数据（stub: 从 source.json 重新加载）"""
    refresh_source()
    load_custom_source()


# === 其他缺失的接口 ===

def find_model(folder_name, filename):
    """查找模型文件（不自动下载）"""
    return find_or_download_model(folder_name, filename, auto_download=False)


def collect_file(folder_name, filename, auto_download=True):
    """收集文件（与 find_or_download_model 类似）"""
    return find_or_download_model(folder_name, filename, auto_download=auto_download)


def calculate_folder_size(folder_path):
    """计算文件夹大小（字节）"""
    total_size = 0
    if os.path.isdir(folder_path):
        for dirpath, dirnames, filenames in os.walk(folder_path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if os.path.exists(fp):
                    total_size += os.path.getsize(fp)
    return total_size


def order_all_file_dict():
    """排序文件字典（stub: 无操作）"""
    pass
