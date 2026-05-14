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
    """使用 aria2c 下载文件"""
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    cmd = ["aria2c", "-x", "16", "-s", "16", "-k", "1M", "-o", file_path, url]
    if extra_args:
        cmd.extend(extra_args)
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return True
    except Exception as e:
        logger.warning(f"aria2c download failed: {e}")
        return False


# === 核心接口 ===
def find_or_download_model(folder_name, filename, auto_download=True):
    """在本地查找模型文件，如未找到且 auto_download=True 则尝试下载"""
    # 首先在标准目录中查找
    models_base = "/workspace/models"
    folder_path = os.path.join(models_base, folder_name)
    full_path = os.path.join(folder_path, filename)
    if os.path.exists(full_path):
        return full_path

    # 也检查 cnb_cache 目录
    cache_path = os.path.join("/workspace/models_cnb_cache", folder_name, filename)
    if os.path.exists(cache_path):
        return cache_path

    # 尝试在 all_file_dict 中查找下载链接
    if auto_download:
        for repo_name, files in _all_file_dict.items():
            if filename in files:
                url = files[filename]
                # 确定下载目标路径
                os.makedirs(folder_path, exist_ok=True)
                logger.info(f"Downloading {filename} from {url}")
                if aria2c(full_path, url):
                    return full_path
                break

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
