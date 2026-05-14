# Stub module: 替代 hook_by_xu.cpython-312-x86_64-linux-gnu.so
# 原 .so 文件中 NSFW 检测模块在初始化时调用 C 级 exit() 导致进程退出
# 此 stub 保留核心功能（模型查找、下载、列表显示等），禁用 NSFW 检查

import json
import os
import logging
import subprocess

logger = logging.getLogger(__name__)

# === 全局变量 ===
enable_auto_download = False  # patch_by_xu.py 直接读写此变量控制自动下载

# === 数据结构 ===
# _all_file_dict: {repo_name: {relative_path: url}}  — 保留原始结构，供其他模块引用
# _folder_index: {folder_name: {filename: url}}  — 按 folder 索引，用于列表显示和查找
# _all_source_dict: 保留原始 source.json 结构
# _all_sha256_dict: sha256 校验

_source_json_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "source.json")
_all_file_dict = {}
_all_source_dict = {}
_all_sha256_dict = {}
_folder_index = {}  # {folder_name: {filename: url}}

# ComfyUI 标准模型目录名（用于路径匹配）
_MODEL_FOLDERS = [
    "checkpoints", "diffusion_models", "unet", "vae", "vae_approx",
    "loras", "clip", "clip_vision", "text_encoders", "controlnet",
    "embeddings", "style_models", "unet_gguf", "loras_gguf",
    "hypernetworks", "annotators", "insightface", "classifiers",
    "mmdets", "sams", "sam2", "onnx", "ultralytics", "unets",
    "audio_encoders", "wav2vec2", "ckpts", "inpaint", "upscalers",
    "custom_nodes", "diffusion_models_gguf",
]


def _register_repo_folder(repo_key, dir_path, repo_to_folder):
    """将 repo 映射注册到 repo_to_folder 字典"""
    # dir_path 形如 "models/unet" 或 "models/loras/Z-Image" 或 "models"
    repo_to_folder[repo_key] = dir_path


def _load_source_data():
    """从 source.json 加载模型映射数据，构建 folder 索引"""
    global _all_file_dict, _all_source_dict, _all_sha256_dict, _folder_index
    if _all_file_dict:
        return
    try:
        if not os.path.exists(_source_json_path):
            return
        with open(_source_json_path, "r") as f:
            data = json.load(f)

        # 1. 处理 path_dict（repo → 目录映射）
        path_dict = data.get("path_dict", {})
        # 构建 repo → folder_name 的扁平映射（path_dict 可能是嵌套的）
        repo_to_folder = {}
        for repo_key, repo_val in path_dict.items():
            if isinstance(repo_val, dict):
                _all_source_dict[repo_key] = repo_val
                # 嵌套 dict：值本身也是 {repo: dir} 映射
                for sub_repo, sub_dir in repo_val.items():
                    if isinstance(sub_dir, str):
                        _register_repo_folder(sub_repo, sub_dir, repo_to_folder)
            elif isinstance(repo_val, str):
                _register_repo_folder(repo_key, repo_val, repo_to_folder)

        # 2. 处理顶层 URL 列表（key 是 repo_name，value 是 {file_path: url}）
        for key, val in data.items():
            if key == "path_dict":
                continue
            if isinstance(val, dict):
                repo_name = key
                if repo_name not in _all_file_dict:
                    _all_file_dict[repo_name] = {}
                # 获取该 repo 对应的 folder 前缀
                folder_prefix = repo_to_folder.get(repo_name, "")
                # 去掉 "models/" 前缀
                if folder_prefix.startswith("models/"):
                    folder_prefix = folder_prefix[len("models/"):]
                elif folder_prefix == "models":
                    folder_prefix = ""
                for file_path, url in val.items():
                    if isinstance(url, str) and url.startswith("http"):
                        _all_file_dict[repo_name][file_path] = url
                        # 如果 file_path 自身不含 folder 前缀，则使用 path_dict 中的映射
                        if folder_prefix and "/" not in file_path and not file_path.startswith("models/"):
                            indexed_path = f"{folder_prefix}/{file_path}"
                        else:
                            indexed_path = file_path
                        _add_to_folder_index(indexed_path, url)

    except Exception as e:
        logger.warning(f"Failed to load source.json: {e}")


def _add_to_folder_index(file_path, url):
    """将 'folder_name/filename' 或 'folder/sub/file.ext' 添加到 folder_index"""
    # 去掉 "models/" 前缀
    normalized = file_path
    if normalized.startswith("models/"):
        normalized = normalized[len("models/"):]

    # 尝试匹配已知的模型目录
    parts = normalized.split("/")
    if len(parts) >= 2:
        folder_name = parts[0]
        filename = "/".join(parts[1:])
        # 如果第一级目录是已知模型目录
        if folder_name in _MODEL_FOLDERS:
            if folder_name not in _folder_index:
                _folder_index[folder_name] = {}
            _folder_index[folder_name][filename] = url
            return

    # 如果不匹配已知目录，用第一级作为 folder_name
    if len(parts) >= 2:
        folder_name = parts[0]
        filename = "/".join(parts[1:])
        if folder_name not in _folder_index:
            _folder_index[folder_name] = {}
        _folder_index[folder_name][filename] = url
    elif len(parts) == 1:
        if "" not in _folder_index:
            _folder_index[""] = {}
        _folder_index[""][parts[0]] = url


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


# === 自动下载控制 ===
# patch_by_xu.py 在提交任务时设置 hook_by_xu.enable_auto_download = True
# 页面扫描/刷新时设为 False，防止打开页面就疯狂下载


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

    # 必须同时满足：调用方请求 auto_download 且模块级开关 enable_auto_download 为 True
    if auto_download and enable_auto_download:
        logger.info(f"[find_or_download_model] {folder_name}/{filename} not found locally, searching...")
        url = _find_url(folder_name, filename)
        if url:
            logger.info(f"[find_or_download_model] Found URL: {url[:80]}...")
            if aria2c(full_path, url):
                if os.path.exists(full_path):
                    logger.info(f"[find_or_download_model] Download success: {full_path}")
                    return full_path
                else:
                    logger.error(f"[find_or_download_model] File not at {full_path} after download")
        else:
            logger.warning(f"[find_or_download_model] No download URL found for {folder_name}/{filename}")

    return None


def _find_url(folder_name, filename):
    """在 folder_index 和 all_file_dict 中查找下载 URL"""
    # 优先在 folder_index 中查找（支持别名）
    for alias in _resolve_folder_aliases(folder_name):
        if alias in _folder_index and filename in _folder_index[alias]:
            return _folder_index[alias][filename]

    # 在 all_file_dict 中按 filename 搜索（跨 repo）
    for repo_name, files in _all_file_dict.items():
        # 精确匹配: "folder_name/filename"
        key = f"{folder_name}/{filename}"
        if key in files:
            return files[key]
        # 只匹配 filename（兜底）
        if filename in files:
            return files[filename]
        # 带前缀匹配
        for file_path, url in files.items():
            if file_path.endswith(f"/{filename}") or file_path == filename:
                return url

    return None


# ComfyUI folder_name 别名映射
_FOLDER_ALIASES = {
    "diffusion_models": ["unet", "diffusion_models"],
    "unet": ["unet", "diffusion_models"],
    "unet_gguf": ["unet", "diffusion_models", "unet_gguf"],
    "diffusion_models_gguf": ["unet", "diffusion_models", "diffusion_models_gguf"],
}


def _resolve_folder_aliases(folder_name):
    """解析 folder_name 的所有可能别名"""
    if folder_name in _FOLDER_ALIASES:
        return _FOLDER_ALIASES[folder_name]
    return [folder_name]


def import_models(directory, result):
    """将 folder_index 中的可下载模型添加到扫描结果中"""
    if not isinstance(result, tuple) or len(result) < 2:
        return result

    files_list, dirs_list = result[0], result[1]
    files_set = set(files_list) if not isinstance(files_list, set) else files_list

    # 从 directory 路径推断 folder_name
    folder_name = _directory_to_folder_name(directory)
    for alias in _resolve_folder_aliases(folder_name):
        if alias in _folder_index:
            for filename in _folder_index[alias]:
                # 只添加本地不存在的（避免重复）
                full_path = os.path.join(directory, filename)
                if not os.path.exists(full_path):
                    files_set.add(filename)

    return (files_set, dirs_list)


def import_models2(directory, result):
    """同 import_models"""
    return import_models(directory, result)


def import_filename_list(folder_name, out):
    """将 folder_index 中的可下载模型添加到文件名列表"""
    if not isinstance(out, tuple) or len(out) < 2:
        return out

    files_list, dirs_list = out[0], out[1]
    # 确保 files 是可变的 set（ComfyUI 可能传入 list）
    if isinstance(files_list, list):
        files_set = set(files_list)
    else:
        files_set = set(files_list)

    for alias in _resolve_folder_aliases(folder_name):
        if alias not in _folder_index:
            continue
        models_base = "/workspace/models"
        for filename in _folder_index[alias]:
            basename = os.path.basename(filename)
            full_path = os.path.join(models_base, alias, filename)
            cache_path = os.path.join("/workspace/models_cnb_cache", alias, filename)
            # 如果文件在 models/ 中已存在，ComfyUI 已扫描到，跳过
            if os.path.exists(full_path):
                continue
            # 如果文件在 cnb_cache 中，创建软链接到 models/ 让 ComfyUI 能扫描到
            if os.path.exists(cache_path):
                link_dir = os.path.join(models_base, alias)
                os.makedirs(link_dir, exist_ok=True)
                link_path = os.path.join(link_dir, basename)
                if not os.path.exists(link_path):
                    try:
                        os.symlink(cache_path, link_path)
                        logger.info(f"[import_filename_list] symlink: {link_path} -> {cache_path}")
                    except OSError as e:
                        logger.warning(f"[import_filename_list] symlink failed: {e}")
                continue
            # 文件不存在，添加到列表让用户看到（运行时可自动下载）
            files_set.add(basename)

    return (files_set, dirs_list)


def _directory_to_folder_name(directory):
    """从文件系统路径推断 ComfyUI folder_name"""
    # /workspace/models/checkpoints -> checkpoints
    # /workspace/models/diffusion_models -> diffusion_models
    for prefix in ["/workspace/models/", "/workspace/comfyui/models/"]:
        if directory.startswith(prefix):
            relative = directory[len(prefix):]
            # 取第一级目录名
            parts = relative.split("/")
            if parts:
                return parts[0]
    return None


def refresh_source():
    """刷新源数据"""
    global _all_file_dict, _all_source_dict, _folder_index
    _all_file_dict.clear()
    _all_source_dict.clear()
    _folder_index.clear()
    _source_loaded = False
    _load_source_data()
    load_custom_source()


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
    # 在 folder_index 中搜索
    for folder_name, files in _folder_index.items():
        if model_name in files:
            url = files[model_name]
            target = save_path or os.path.join("/workspace/models", folder_name, model_name)
            if aria2c(target, url):
                return target
    # 在 all_file_dict 中搜索
    for repo_name, files in _all_file_dict.items():
        for file_path, url in files.items():
            if file_path.endswith(f"/{model_name}") or file_path == model_name:
                target = save_path or os.path.join("/workspace/models", file_path)
                if aria2c(target, url):
                    return target
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
    """加载自定义下载链接.yaml，将用户定义的模型下载链接合并到 folder_index"""
    if not os.path.exists(_custom_source_path):
        return
    try:
        import yaml
        with open(_custom_source_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data or not isinstance(data, dict):
            return
        for model_path, url in data.items():
            if not isinstance(url, str) or not url.startswith("http"):
                continue
            model_path = model_path.strip().strip('"')
            # 去掉前缀
            for prefix in ["/workspace/models/", "/workspace/comfyui/models/", "models/"]:
                if model_path.startswith(prefix):
                    model_path = model_path[len(prefix):]
                    break
            # 分割为 folder_name 和 filename
            parts = model_path.split("/")
            if len(parts) >= 2:
                folder_name = parts[0]
                filename = "/".join(parts[1:])
                if folder_name not in _folder_index:
                    _folder_index[folder_name] = {}
                _folder_index[folder_name][filename] = url
                # 同时添加到 all_file_dict
                custom_repo = "自定义下载链接"
                if custom_repo not in _all_file_dict:
                    _all_file_dict[custom_repo] = {}
                _all_file_dict[custom_repo][model_path] = url
                logger.info(f"[自定义下载链接] {folder_name}/{filename} -> {url[:60]}...")
            elif len(parts) == 1:
                if "" not in _folder_index:
                    _folder_index[""] = {}
                _folder_index[""][parts[0]] = url
    except ImportError:
        logger.warning("PyYAML not installed, cannot load 自定义下载链接.yaml")
    except Exception as e:
        logger.warning(f"Failed to load 自定义下载链接.yaml: {e}")


# 模块加载时自动加载自定义下载链接
load_custom_source()


# === 预设源加载 ===
_preset_source_file = None

def load_preset_source():
    """加载预设源数据"""
    refresh_source()


# === 其他接口 ===

def find_model(folder_name, filename):
    """查找模型文件（不自动下载）"""
    return find_or_download_model(folder_name, filename, auto_download=False)


def collect_file(folder_name, filename, auto_download=True):
    """收集文件"""
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
    """排序文件字典"""
    pass
