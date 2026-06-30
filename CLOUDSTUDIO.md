# Cloud Studio 导入与启动配置

## 创建应用时的推荐选择

- 仓库地址：`https://github.com/ypq123456789/comfyui-cloudstudio-msjh.git`
- 应用标题：`comfyui-cloudstudio-msjh`
- 应用描述：`墨色江湖 Cloud Studio 专用 ComfyUI 生图后端，启动后开放 8188 端口并上报到墨色江湖自动发现注册表。`
- 算力规格：优先选择 `GPU T4`。Cloud Studio 当前计费文档列出的 T4 规格是 8 核 CPU、32G 内存、16G 显存，适合作为默认生图后端。
- 工作区布局：选择 `VS Code` 布局。

## 启动方式

建议先设置一个只给自己用的自动连接口令。墨色江湖设置页填同一个口令时，就能只筛出自己的 Cloud Studio 后端：

```bash
export CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN="你的名字或随机短码"
```

本仓库按 Cloud Studio 文档提供了 `.vscode/preview.yml`：

- `run: bash cloudstudio_start.sh`
- `root: .`
- `port: 8188`
- `autoOpen: true`
- `autoPreview: true`
- `mainPort: true`

进入 VS Code 工作区后，还提供了 `.vscode/tasks.json` 的 `runOn: folderOpen` 任务。Cloud Studio 打开工作区时会在集成终端里自动执行：

```bash
bash cloudstudio_start.sh
```

如果 Cloud Studio 或 VS Code 首次打开时询问是否允许自动任务，选择允许。若自动任务没有触发，手动打开终端运行同一条命令即可。

## 启动后验收

1. 终端出现 `[Cloud Studio Startup] Starting ComfyUI on port 8188`。
2. 本地检查：

```bash
curl -fsS http://127.0.0.1:8188/system_stats
```

3. 打开 Cloud Studio 端口/预览面板，确认 8188 公网地址可访问。
4. 如果脚本没有自动识别预览地址：

```bash
export CLOUDSTUDIO_IMAGE_BACKEND_URL="https://你的-8188-预览地址"
bash cloudstudio_sync.sh
```

5. 回到墨色江湖设置页，刷新“云端 ComfyUI 后端”，应能看到 `cloudstudio` 来源。

## 上报身份字段

上报 payload 会包含：

- `provider/source: "cloudstudio"`：标记来源。
- `customerId`：优先用 `CLOUDSTUDIO_CUSTOMER_ID`，否则用 `CLOUDSTUDIO_WORKSPACE_ID`、`HOSTNAME` 或 `hostname`。
- `workspace`：优先用 `CLOUDSTUDIO_WORKSPACE_NAME` / `CLOUDSTUDIO_WORKSPACE_ID`。
- `connectToken`：优先用 `CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN`。服务端只保存哈希，设置页输入同一个口令才能匹配到。

Cloud Studio 默认系统用户常常是 `root`，所以不要依赖 `USER` 来区分用户；推荐显式设置 `CLOUDSTUDIO_IMAGE_BACKEND_CONNECT_TOKEN`。
