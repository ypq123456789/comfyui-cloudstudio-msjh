# MoRanJiangHu Cloud Studio ComfyUI Backend

本仓库是墨色江湖云端 ComfyUI 生图后端的 Cloud Studio 迁移版。CNB 只作为历史来源，后续维护以 Cloud Studio 为准。

## Cloud Studio 快速启动

1. 在 Cloud Studio 从 GitHub 导入仓库 `https://github.com/ypq123456789/comfyui-cloudstudio-msjh.git`。
2. 创建应用/复刻工作区时，算力规格优先选择 `GPU T4`，工作区布局选择 `VS Code`。
3. 本仓库已内置 Cloud Studio 运行配置：
   - `.vscode/preview.yml` 会把主服务设置为 `8188`，并使用 `bash cloudstudio_start.sh` 作为启动命令。
   - `.vscode/tasks.json` 会在 VS Code 工作区打开后拉起集成终端，自动运行 `bash cloudstudio_start.sh`。
4. 如果首次打开时 Cloud Studio / VS Code 询问是否允许自动任务，请选择允许。若自动任务未触发，手动打开终端运行：

```bash
bash cloudstudio_start.sh
```

5. 确认 Cloud Studio 的端口/预览面板开放 `8188`。
6. 如果脚本没有自动识别公网预览地址，手动设置：

```bash
export CLOUDSTUDIO_IMAGE_BACKEND_URL="https://你的-8188-预览地址"
bash cloudstudio_sync.sh
```

7. 回到墨色江湖的文生图设置，选择 ComfyUI，刷新“云端 ComfyUI 后端”，用自动连接口令筛选自己的后端。

更完整的 Cloud Studio 导入、T4 算力、VS Code 布局与验收步骤见 [CLOUDSTUDIO.md](CLOUDSTUDIO.md)。

建议在启动前设置自己的自动连接口令：

```bash
export CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN="你的名字或随机短码"
```

墨色江湖设置页填写同一个口令后，会只显示匹配的 Cloud Studio 后端。不要依赖 Cloud Studio 默认 `USER=root` 来区分用户。

### 环境变量

| 变量 | 用途 |
| - | - |
| `CLOUDSTUDIO_IMAGE_BACKEND_URL` | Cloud Studio 8188 公网预览地址，自动识别失败时手动填写 |
| `CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN` | 墨色江湖自动发现筛选口令，不填时使用 Cloud Studio 用户名或 `USER` |
| `CLOUDSTUDIO_IMAGE_BACKEND_PORT` | ComfyUI 端口，默认 `8188` |
| `MSJH_IMAGE_BACKEND_SYNC_URL` | 上报地址，默认 `https://msjh.bacon.de5.net/api/image-backend/sync` |
| `MSJH_IMAGE_BACKEND_SYNC_TOKEN` | 上报鉴权 token，应放在 Cloud Studio Secret 或本机环境变量 |

不要把 Cloud Studio token、同步 token 或任何私密凭据提交进仓库。

---

# 云原生构建的[ComfyUI](https://github.com/comfyanonymous/ComfyUI)运行环境-多镜像协作-预装版

[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/CNB.svg)](https://cnb.cool)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/Docker.svg)](https://www.docker.com)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/ComfyUI.svg)](https://github.com/comfyanonymous/ComfyUI)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/CUDA.svg)](https://developer.nvidia.cn/cuda-toolkit)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/Python.svg)](https://www.python.org)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/PyTorch.svg)](https://pytorch.org)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/xFormers.svg)](https://github.com/facebookresearch/xformers)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/FlashAttention.svg)](https://github.com/Dao-AILab/flash-attention)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/SageAttention.svg)](https://github.com/thu-ml/SageAttention)
[![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/badge/nunchaku.svg)](https://github.com/nunchaku-tech/nunchaku)

首创**多镜像协作**方案，将ComfyUI运行环境拆分为多个子镜像，实现了用户自定义内容与预置镜像的自动组合。

Fork仓库后点击右上角 **启动 L40 预装环境** 稍等一会即可开始玩耍。

本仓库已把 CNB 欢迎命令改成真实启动链路：`bash /workspace/自定义初始化命令`。启动脚本会先做必要补丁和后台上报，再直接执行 `qd --listen 0.0.0.0 --port 8188 --enable-cors-header "*"` 启动 ComfyUI；不再依赖环境里可能不存在的 `init2` 命令。

了解更多：
[![](https://img.shields.io/badge/ComfyUI交流群-5C5C5C?logo=wechat)](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/image/qrcode.png)
[![](https://img.shields.io/badge/详细教程-5C5C5C?logo=quicklook)](https://cnb.cool/cnb-xu/docs/-/blob/main/comfyui/README.md)

## 特色功能

| 功能 | 说明 |
| - | :- |
| [自动启动](#打开ComfyUI界面) | 环境启动后自动启动ComfyUI |
| [图形化下载工具](#打开图形化下载工具界面) | 在ComfyUI界面中点击CNB-Xu按钮打开 |
| [自定义初始化](自定义初始化命令) | 可在 [自定义初始化命令](自定义初始化命令) 文件中添加命令 |
| [内置终端命令](#内置终端命令) | 一些常用的、简化操作的终端命令 |
| [模型自动下载](#模型自动下载) | 基于[AI Models](https://cnb.cool/ai-models)的海量模型自动下载 |

## 内置终端命令

| 命令 | 说明 |
| - | :- |
| qd | 启动ComfyUI，可加启动参数，示例：```qd --use-sage-attention``` |
| kill 1 | 关闭环境，可选择是否保存更改 |
| install-node | 从url安装插件，示例：```install-node url1 url2 ...``` |

## 模型自动下载

ComfyUI启动后界面内**可选择的模型**在运行时会自动下载到云节点缓存/工作区，无需人为操作，也不需要保存到个人仓库！！！

除了预设模型，还可以在 [**自定义下载链接.yaml**](自定义下载链接.yaml) 文件里添加自己喜欢的模型，注意格式！！！

详细代码实现见 [**ComfyUI源码修改**](https://cnb.cool/cnb-xu/docs/-/blob/main/comfyui/hook.md)，开源项目欢迎复制/参考代码，但希望**注明代码出处**~

**注意**：
1. 自动下载的模型优先保存在models_cnb_cache文件夹内，该文件夹直接缓存在云节点上，空间上限512GB，可在终端内运行 **clear-cache** 清空。
2. models_cnb_cache文件夹超过450GB后，自动下载的模型将保存在models_workspace文件夹内，工作区空间上限1.6TB。
3. 预置模型来源于互联网，如：[AI Models](https://cnb.cool/ai-models)，**不可商用！不可商用！不可商用！**

## 打开ComfyUI界面

环境启动后会**自动启动**ComfyUI。如需关闭，终端中按 **Ctrl+c**。

再次启动ComfyUI，终端输入 **qd**，回车运行。可添加其他启动参数，如 **qd --use-sage-attention**，启用sageattention。

四种打开外链的方法（**选一种**即可）：
1. ComfyUI启动后，会弹出一个对话框，点**打开**。
2. 点击右下角弹出的对话框中的**在浏览器中打开**。
3. 按住Ctrl键点击终端输出内容中的http://0.0.0.0:8188。
4. 在**端口**下，按住Ctrl键点击外部链接。

![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/image/guide1.png)

## 打开图形化下载工具界面

在ComfyUI界面中点击**CNB-Xu**按钮，即可打开图形化下载工具界面。

![](https://cnb.cool/cnb-xu/docs/-/git/raw/main/comfyui/image/guide2.png)

**Aria2c**和**Wget**模块均可自定义下载链接和保存路径，对于多数下载链接可以直接识别文件名，无法识别的需要手工输入。

**预设下载**模块中预置了一些模型的下载链接和存放路径，首先选择**一级分类**和**二级分类**，然后选择**预设文件列表（可多选）**，最后点击**开始下载**或**生成终端下载代码**。

## 相关项目

[**ComfyUI 在线体验（飞桨AI Studio星河社区）**](https://aistudio.baidu.com/projectdetail/7980211?sUid=9044961&shared=1&ts=1753991815854)
