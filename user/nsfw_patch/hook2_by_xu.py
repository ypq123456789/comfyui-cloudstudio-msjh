# Stub module: 替代 hook2_by_xu.cpython-312-x86_64-linux-gnu.so
# 禁用 NSFW 检测，所有检测函数均为 no-op

import numpy as np


enable_check = False
sampling_threshold = 0.0
nsfw_check_models_folder = "/workspace/models_cnb_cache/nsfw_check_models"


class NSFW_Content_Found(Exception):
    """NSFW检测占位异常 - 永远不会被触发"""
    def __init__(self, msg="NSFW Content Found !"):
        super().__init__(msg)


def check_image(image, *args, **kwargs):
    """跳过NSFW检测，直接返回False"""
    return False


def check_vae_decode_images(images, *args, **kwargs):
    """跳过NSFW检测，直接返回原始图像"""
    return images


def detect_nsfw(image, *args, **kwargs):
    """跳过NSFW检测"""
    return False


def detect_with_nsfw_1(image, *args, **kwargs):
    """跳过NSFW检测"""
    return False


def detect_with_nsfw_2(image, *args, **kwargs):
    """跳过NSFW检测"""
    return False


def detect_with_nsfw_3(image, *args, **kwargs):
    """跳过NSFW检测"""
    return False


def prepare_detect_frame(image, *args, **kwargs):
    """跳过NSFW检测"""
    return image


def fit_frame(image, *args, **kwargs):
    """跳过NSFW检测"""
    return image


def forward_nsfw(image, *args, **kwargs):
    """跳过NSFW检测，直接放行"""
    return False


# 用于兼容可能需要的 ort / cv2 等模块引用
try:
    import onnxruntime as ort
except ImportError:
    ort = None

try:
    import cv2
except ImportError:
    cv2 = None

inference_pool = None
static_model_set = None
sess_options = None
