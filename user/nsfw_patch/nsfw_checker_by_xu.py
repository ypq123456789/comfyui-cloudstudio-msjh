# Stub module: 替代 nsfw_checker_by_xu.cpython-312-x86_64-linux-gnu.so
# 禁用 NSFW 检测，所有函数均为 no-op

import numpy as np
import torch


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


class NSFW_Checker:
    """NSFW检测节点占位 - 不执行任何检测"""
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "image": ("IMAGE", {"tooltip": "The images to check."}),
            },
            "hidden": {"prompt": "PROMPT", "extra_pnginfo": "EXTRA_PNGINFO"},
        }

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "save_images"
    OUTPUT_NODE = True
    CATEGORY = "CNB-Xu"
    DESCRIPTION = "NSFW Checker (disabled)"

    def save_images(self, image, prompt=None, extra_pnginfo=None):
        """直接返回原始图像，不执行任何检测"""
        return {"ui": {}, "result": (image,)}


NODE_CLASS_MAPPINGS = {"NSFW_Checker": NSFW_Checker}
