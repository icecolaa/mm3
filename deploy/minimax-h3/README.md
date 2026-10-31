# MiniMax H3 视频部署包（ComfyUI · Windows 11 · RTX 3080 10GB）

面向本机：i7-13700KF / RTX 3080 10240MiB / 32GB DDR4-3600 / Windows 11 22631 / 当前驱动 560.94。

本包只做三件事：给出一份**可核实的文件清单**、一个**只下载不安装的 PowerShell 脚本**、一套**能照做的验收流程**。本包不安装任何软件、不下载任何权重、不改驱动、不运行 ComfyUI。

所有外部信息访问日期：**2026-10-29**。官方来源与社区来源分开标注。凡未能核实的内容在正文和文末第 11 节显式标"未核实"。

---

## 0. 一句话结论

在 10GB 显存上，可落地的路线是：**ComfyUI（≥0.36，建议当前稳定版 v0.43.0）+ H3 FL2VA 的 W4A8 社区量化（12.54 GB）+ Qwen3-VL 4B int8 文本编码器（5.37 GB）+ 4B ClipProj v3-mlp 投影矩阵（0.50 GB）+ H3 int8 视频 VAE（3.17 GB）**，配合社区 8GB 工作流，先跑 **608×352 / 124 帧 / 24fps / 20 步**的约 5 秒无声短片。

四个文件合计 **21,590,132,744 字节 ≈ 20.11 GiB**。

这不是本机实测结论。社区工作流的实测硬件是 RTX 4060 Laptop 8GB / 16GB 内存，**不构成对 3080 的成功保证，也不构成任何耗时承诺**。

---

## 1. 为什么选这条路线

| 决策 | 选择 | 理由 |
|---|---|---|
| 权重精度 | W4A8 社区量化 | 原始 H3 FL2VA 权重远超 10GB；W4A8 把主模型压到 12.54 GB，配合分层加载与内存卸载才有机会跑起来 |
| 文本编码器 | Qwen3-VL **4B** int8，不用官方 32B | 官方 H3-Encoder 是 Qwen3-VL-32B 的第 50 层隐状态，ClipProj 项目给出的实测是编码器占用从 15.7 GB 降到 5.2 GB（来源：ClipProj README）。4B 矩阵必须配 4B 编码器，4B 输出 2560 维、8B 输出 4096 维，节点会拒绝维度不匹配 |
| 加载方式 | ComfyUI 原生加载器 + ClipProj | 不用旧式专用加载器；`UNETLoader` / `CLIPLoader(krea2)` / `ClipProjApply` / `VAELoader` 四个原生节点即可 |
| 加速 | Spectrum（可选） | 近似加速器，会改变去噪轨迹，同种子输出也可能不同。先跑通再开 |
| 任务类型 | 先 FL2VA（首尾帧） | 官方 FL2VA 覆盖零/一/两图三种输入，一个权重能同时验证纯文生、单图、首尾帧三条路径 |

**成本提醒**：本包只装 FL2VA 权重。Ref2VA（多模态参考）需要另下 `minimax_h3_ref2va_pruned_w4a8_mixed.safetensors`（11,770,657,048 字节 ≈ 10.96 GiB，来源 Kijai 同一仓库），本包**不下载**它。Ref2VA 的具体工作流本包**未核实**。

---

## 2. 环境要求

### 2.1 ComfyUI 版本

| 结论 | 依据 |
|---|---|
| 原生 H3 支持自 **v0.30.0**（2026-08-03，PR #15224）起 | ComfyUI Release Notes |
| **int8_convrot VAE** 支持自 **v0.31.0**（2026-08-08，PR #15334）起 —— 本包 VAE 就是这种格式，低于此版本无法加载 | 同上 |
| VAE 显存与速度优化在 **v0.36.0**（2026-09-15，PR #16187 / #16332） | 同上 |
| 当前稳定版 **v0.43.0**（2026-10-27） | GitHub Releases |

**要求：≥0.36，直接用当前稳定版 v0.43.0。** 工作流还用到 `MiniMaxH3ImageToVideo`（`comfy_extras/nodes_minimax_h3.py`）和 `ModelAttentionBackend`（`comfy_extras/nodes_model_advanced.py`），两者都在较新版本中；缺这两个节点说明 ComfyUI 太旧，先升级再排查别的。

社区工作流作者只写了"更新到带原生 H3 FL2V 支持"的版本，没有给具体版本号；上面的版本区间是从 ComfyUI 官方 Release Notes 反查得到，属**推断**，未在本机验证。

### 2.2 驱动：必须先升级

- 当前 ComfyUI Windows Portable 自带 **Python 3.13 + PyTorch CUDA 13.0**（官方系统要求页原文："The Windows portable build currently comes with Python 3.13 and PyTorch CUDA 13.0. Update your Nvidia drivers if it doesn't start."）。
- NVIDIA 官方 CUDA 兼容表：**CUDA 13.x 要求驱动 ≥ 580**（12.x 为 ≥525 且 <580）。
- 本机 **560.94 不满足**。不升级就直接用 Portable，会出现 CUDA 初始化失败一类报错，与模型、节点无关。

**动作**：到 NVIDIA 官方下载页取适配 RTX 3080 / Windows 11 的 580 系列或更新的 Game Ready / Studio 驱动，按安装器要求重启。本包**不改驱动**，只记录要求。

不需要单独安装完整 CUDA Toolkit：Portable 自带配套运行环境。

### 2.3 Portable 安装位置

从 ComfyUI 官方 Portable 说明页下载 Nvidia 版压缩包，用 **7-Zip** 解压到 `D:\LocalAI\video\`。解压后结构（官方文档原文）：

```text
D:\LocalAI\video\ComfyUI_windows_portable\
├── ComfyUI\                    ← 主程序，模型目录在 ComfyUI\models\
├── python_embeded\             ← 独立 Python，装依赖只用它
├── update\                     ← update_comfyui_stable.bat 等升级脚本
├── README_VERY_IMPORTANT.txt
├── run_cpu.bat
└── run_nvidia_gpu.bat
```

不要放 C 盘：C 盘只剩约 35.8GiB，四个模型就 20.11GiB。D 盘剩约 672GiB，够用。

### 2.4 空间预算

| 项 | 大小 | 说明 |
|---|---|---|
| 四个模型文件 | 20.11 GiB | 见第 4 节，精确字节数 |
| Portable 解压后 | 数 GB | 官方未给固定值，按 6–10 GB 预留 |
| 输出视频 | 每条几十 MB 量级 | 608×352/124 帧，实际以生成为准，**未核实** |

---

## 3. 目录布局

```text
D:\LocalAI\video\
├── ComfyUI_windows_portable\
│   └── ComfyUI\
│       ├── custom_nodes\
│       │   ├── ComfyUI-ClipProj\                  ← 插件 1，≥0.1.13
│       │   └── ComfyUI-Spectrum-MiniMax-H3\       ← 插件 2，可选但工作流默认启用
│       ├── models\
│       │   ├── diffusion_models\minimax_h3_fl2va_pruned_w4a8_mixed.safetensors
│       │   ├── text_encoders\qwen3vl_4b_int8_convrot.safetensors
│       │   ├── clip_projections\mmh3-4b-ClipProj-v3-mlp.safetensors
│       │   └── vae\minimax_h3_video_vae_int8_convrot.safetensors
│       └── output\video\                          ← 生成结果
└── workflows\
    └── MiniMax_H3_FL2V_8GB_VRAM.json              ← 自行保存的工作流副本
```

`models\clip_projections\` 目录由 ComfyUI-ClipProj 首次启动时自动创建（来源：ClipProj README）。其余三个目录 Portable 自带。

---

## 4. 模型文件清单（逐项核实）

四个文件的字节数与 SHA-256 均取自 Hugging Face 仓库文件元数据，并用 `curl -I` 对下载地址做 HEAD 请求，返回的 `Content-Length` 与元数据逐字节一致。**未下载任何文件本体。**

| # | 文件名 | 大小（字节 / GiB） | 目标目录（相对 `ComfyUI\`） | 来源类型 |
|---|---|---|---|---|
| 1 | `minimax_h3_fl2va_pruned_w4a8_mixed.safetensors` | 12,540,858,008 / 11.68 GiB | `models\diffusion_models\` | 社区量化 |
| 2 | `qwen3vl_4b_int8_convrot.safetensors` | 5,374,169,456 / 5.01 GiB | `models\text_encoders\` | 社区量化 |
| 3 | `mmh3-4b-ClipProj-v3-mlp.safetensors` | 503,434,368 / 0.47 GiB | `models\clip_projections\` | 社区（MIT） |
| 4 | `minimax_h3_video_vae_int8_convrot.safetensors` | 3,171,670,912 / 2.95 GiB | `models\vae\` | 社区量化 |

合计 **21,590,132,744 字节 = 20.11 GiB**。

### 4.1 逐项明细

**1. H3 FL2VA 主模型（W4A8 混合量化）**

- 下载地址：`https://huggingface.co/Kijai/MiniMax-H3-experimental/resolve/main/minimax_h3_fl2va_pruned_w4a8_mixed.safetensors`
- 仓库页：https://huggingface.co/Kijai/MiniMax-H3-experimental （最后更新 2026-10-28）
- SHA-256：`01aa7b92c007c599890461c325f9b7e3c96fb06c36f242f95b62f7f20e538dec`
- 加载器：`UNETLoader`，weight_dtype 保持 `default`
- **重要**：`starsfriday/MiniMax-H3-w4a8` 也有**同名、同字节数**的文件，但 SHA-256 是 `29d0a0e4be82dacdc4a5849bf756c2b32d34131f7a18f9aac754e16a2e215eb5` —— 两份**不是同一份字节**。本包统一用 Kijai 那份（与 VAE 同仓库，少一个来源）。**换源必须删掉已有半成品重下**，`curl -C -` 会把两个不同文件续接成一个坏文件。

**2. 文本编码器（Qwen3-VL 4B int8 convrot）**

- 下载地址：`https://huggingface.co/Stick9190/qwen3vl_4b_int8_convrot/resolve/main/qwen3vl_4b_int8_convrot.safetensors`
- 仓库页：https://huggingface.co/Stick9190/qwen3vl_4b_int8_convrot
- SHA-256：`ebbb3efdf4a6e1b766e32f6dc4fa92af9530edede0968c070b3e604aeca413aa`
- 加载器：`CLIPLoader`，type = `krea2`（工作流固定值），device = `default`
- 必须与 4B 的 ClipProj 矩阵配对；换成 8B 编码器要同时换 8B 矩阵并改 type。

**3. ClipProj 投影矩阵（4B v3-mlp）**

- 下载地址：`https://huggingface.co/NicoLab28/ClipProj-MiniMax-H3/resolve/main/mmh3-4b-ClipProj-v3-mlp.safetensors`
- 仓库页：https://huggingface.co/NicoLab28/ClipProj-MiniMax-H3
- SHA-256：`feef06ef3b9aede3b1f3331b71eebbc873e21a867d73bcf40ea2c0b007270693`
- 加载器：`ClipProjApply`，接在 `CLIPLoader` 之后、`MiniMaxH3ImageToVideo` 之前
- `-mlp` 后缀表示该文件只带非线性残差部分，**不含线性矩阵 `W`**。所以旧版插件报 `KeyError: 'W'` 不是文件损坏，是版本太旧（见第 10 节第 4 条）。

**4. 视频 VAE（int8 convrot）**

- 下载地址：`https://huggingface.co/Kijai/MiniMax-H3-experimental/resolve/main/minimax_h3_video_vae_int8_convrot.safetensors`
- 仓库页：同上（Kijai）
- SHA-256：`9bb2d96f218c76babd85e0611b85ca8fb330a90546c01a0005e8a58a59593410`
- 加载器：`VAELoader`，同时供 `MiniMaxH3ImageToVideo` 的 vae 输入和 `VAEDecode`
- 这是**视频** VAE。本工作流 `CreateVideo` 的 audio 输入是空的，所以不需要音频 VAE，输出无声。

### 4.2 关于"官方"

- MiniMax 官方开源仓库：https://github.com/MiniMax-AI/MiniMax-H3 （模型卡 https://huggingface.co/MiniMaxAI/MiniMax-H3 ）
- 官方仓库提供的是**全精度** H3-Base（FL2VA / Ref2VA）与 Qwen3-VL-32B 编码器，本机 10GB 显存不适合直接用。
- 上面四个文件**全部是社区产物**，不属于 MiniMax 或 Comfy-UI 官方发布。使用时按其各自模型卡与 MiniMax H3 Community License 判断授权范围。本包不做授权判断。

---

## 5. 两个插件与工作流地址

| 组件 | 地址 | 版本 | 备注 |
|---|---|---|---|
| ComfyUI-ClipProj | https://github.com/nicolab28/ComfyUI-ClipProj | **≥0.1.13** | 提供 `ClipProjApply` |
| ComfyUI-Spectrum-MiniMax-H3 | https://github.com/xmarre/ComfyUI-Spectrum-MiniMax-H3 | 当前 0.2.29 | 提供 `SpectrumApplyMiniMaxH3` |
| 社区首尾帧工作流 | https://github.com/reventadirecta/MiniMax-H3-ComfyUI-8GB-VRAM/blob/main/workflows/MiniMax_H3_FL2V_8GB_VRAM.json | — | 18 节点 / 19 连线 |
| 工作流说明仓库 | https://github.com/reventadirecta/MiniMax-H3-ComfyUI-8GB-VRAM | — | 含 MODELS.md / INSTALLATION.md / TROUBLESHOOTING.md |

**ClipProj 版本陷阱**：仓库的 Git tag 只到 `v0.1.4`，但 `pyproject.toml` 里的 `version` 是 **0.1.13**。tag 与版本号不同步。所以不要用 tag 判断版本，直接装 `main` 分支，装完看 `pyproject.toml` 的 version 字段。0.1.13 之前的版本加载 `-v3-mlp` 矩阵会抛 `KeyError: 'W'`（ClipProj README 原文："The `-v3-mlp` files carry no linear matrix, and any earlier version raises `KeyError: 'W'` when loading one."）。

**Spectrum 定位**：它是**近似加速器**，跳过部分 transformer 求值并用切比雪夫多项式预测特征。README 原文："Forecasted steps change the denoising trajectory, so output can differ from native H3 even with the same seed and workflow." 所以：**先关掉 Spectrum 跑通基线，再开启对比**。它的 `dependencies = []`，没有额外 pip 依赖；许可证 GPLv3+。

**工作流 JSON 实况**（已下载该 JSON 逐节点核对，未运行）：

| 节点 | 类型 | 关键值 |
|---|---|---|
| 1 | `UNETLoader` | `minimax_h3_fl2va_pruned_w4a8_mixed.safetensors` / `default` |
| 2 | `CLIPLoader` | `qwen3vl_4b_int8_convrot.safetensors` / `krea2` / `default` |
| 3 | `ClipProjApply` | `mmh3-4b-ClipProj-v3-mlp.safetensors` |
| 4 | `VAELoader` | `minimax_h3_video_vae_int8_convrot.safetensors` |
| 5 | `ModelAttentionBackend` | `comfy kitchen attention` |
| 6 | `MiniMaxH3SigmaShift` | 12.0 / 3.0 |
| 7 | `SpectrumApplyMiniMaxH3` | 启用，历史存 `system_ram` |
| 8 | `MiniMaxH3ImageToVideo` | **608 × 352 × 124** |
| 10 / 11 | `KSamplerSelect` / `BasicScheduler` | `euler` / `simple`, **20** 步, denoise 1.0 |
| 15 / 16 | `CreateVideo` / `SaveVideo` | **24** fps；输出 `video/MiniMax_H3_FL2V_8GB_608x352` |
| 17 / 18 | `LoadImage` ×2 | 占位符 `first_frame.png` / `last_frame.png` |

即：**608×352、124 帧、24fps、20 步、euler/simple 就是工作流自带的默认值**，不需要改。你只需要把两张占位图换成自己的图。

`ModelAttentionBackend` 的下拉项 `comfy kitchen attention` 只有在 comfy-kitchen 的 INT8 attention 可用时才会出现（源码：`comfy_extras/nodes_model_advanced.py`，条件 `COMFY_KITCHEN_INT8_ATTENTION_IS_AVAILABLE`）。不可用时 ComfyUI 会打 warning 并回退 pytorch attention —— 能跑，但更慢、更吃显存。

---

## 6. 下载模型（脚本）

脚本：`download-minimax-h3.ps1`，同目录。**只下载第 4 节那四个文件**，不 clone、不安装、不改驱动、不碰 ComfyUI。

```powershell
# 1) 先看计划，不发任何网络请求
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\mm3\deploy\minimax-h3\download-minimax-h3.ps1" -DryRun

# 2) 正式下载（默认落到 D:\LocalAI\video）
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\mm3\deploy\minimax-h3\download-minimax-h3.ps1"

# 3) 下载完校验 SHA-256（可选，比较慢，要读 20GB）
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\mm3\deploy\minimax-h3\download-minimax-h3.ps1" -VerifyHash
```

参数：

| 参数 | 作用 |
|---|---|
| `-TargetRoot` | 视频根目录，默认 `D:\LocalAI\video` |
| `-ModelsRoot` | 直接指定 `models` 目录，覆盖默认推导（Portable 放在别处时用） |
| `-DryRun` | 只打印计划，零网络请求、不建目录、不写文件 |
| `-HfMirror` | 改用 `https://hf-mirror.com` 前缀下载（本机直连 huggingface.co 被代理拦截时用） |
| `-VerifyHash` | 下载后校验 SHA-256 |

行为约定：

- 用系统自带 `curl.exe -L --fail --retry 3 -C -`，支持断点续传。
- 目标文件已存在且**字节数等于**清单值 → 跳过并提示。
- 已存在但偏小 → 断点续传；偏大 → 报错退出，不删除你的文件。
- 任一文件失败 → 以非零退出码结束。
- 全程不执行 git、不调用 pip、不改系统设置。

> **本机提醒**：这台机器的 huggingface.co 直连被代理拦截（`CONNECT tunnel failed, response 502`）。正式下载时大概率需要加 `-HfMirror`。这是本机网络环境的观察，不代表你的网络一定如此。

---

## 7. 启动参数（`--lowvram` 的真实作用）

社区文档给的组合是 `--lowvram --fp16-vae`。**先照抄，但要知道它们在当前版本里的实际语义**（依据 `comfy/cli_args.py` 的官方 help 文本）：

| 参数 | 官方 help 原文 | 在本机的实际含义 |
|---|---|---|
| `--lowvram` | "Doesn't do anything if dynamic vram is enabled. If dynamic vram isn't being used this option makes the text encoders run on the CPU." | 动态显存**默认开启**，所以 `--lowvram` 在当前版本**基本是空操作**。它是历史参数，不是万能降显存开关 |
| `--fp16-vae` | "Run the VAE in fp16, might cause black images." | 官方明说**可能导致黑图**。若成品全黑，第一个要摘掉的就是它 |
| `--cpu-vae` | "Run the VAE on the CPU." | 社区明确要求**不要加**：视频 VAE 放 CPU 会慢到不可用 |
| `--vram-headroom <GB>` | "Set the amount of vram in GB for DynamicVRAM to maintain as extra headroom above default." | **真正有效**的显存旋钮。10GB 卡建议 0.5–1.0 |
| `--reserve-vram <GB>` | 为系统/其他软件预留显存 | 开着浏览器、桌面合成时有用 |
| `--disable-smart-memory` | 更激进地把模型卸到普通内存 | 显存实在不够时的下一档 |
| `--fast-disk` | 强制磁盘卸载优先于内存卸载 | D 盘是 NVMe 时可试，可能更快 |

推荐启动命令（照抄社区组合，另加一个真正生效的 headroom）：

```powershell
Set-Location 'D:\LocalAI\video\ComfyUI_windows_portable'
.\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --lowvram --fp16-vae --vram-headroom 0.8 --listen 127.0.0.1
```

若出现黑图 → 去掉 `--fp16-vae`。若仍 OOM → 依次加 `--disable-smart-memory`、`--vram-headroom 1.5`，再不行降到 512×288。

跑之前**必须**先停掉本地语言模型，否则 10GB 显存被两头抢：

```powershell
ollama stop qwen3:8b-q4_K_M
```

---

## 8. 首次验收流程

目标：**608×352、124 帧、24fps、20 步、连续 3 条**，记录真实耗时与显存。不追求画质，只验证"能不能稳定跑完"。

### 8.1 前置检查

- [ ] `nvidia-smi` 显示驱动 ≥580，`CUDA Version` 显示 13.x
- [ ] ComfyUI 启动日志无报错，浏览器能打开 `http://127.0.0.1:8188`
- [ ] 四个模型下拉框都能选中第 4 节的文件名（选不到 = 目录放错或文件名不符）
- [ ] 节点全绿，没有红色"missing node"
- [ ] D 盘剩余 > 40GiB

### 8.2 准备输入图

工作流自带 `first_frame.png` / `last_frame.png` 两个**占位符**，仓库里没有真实图片，必须换掉。

- 两张图内容要连贯（同一场景的起止状态），否则首尾帧差异过大容易崩。
- 先用简单场景：静态主体 + 缓慢镜头运动，别一上来做复杂运镜或人物特写。
- 尺寸不必等于 608×352：节点会把首帧拉伸到画布，尾帧按比例居中裁剪。

### 8.3 参数（保持工作流默认，不要改）

| 项 | 值 |
|---|---|
| 分辨率 | 608 × 352（宽高都是 32 的倍数，符合节点 step=32 约束） |
| 帧数 | 124（124 = 17×7+5，正好落在模型 17k+5 帧网格上，约 5.2 秒 @24fps） |
| fps | 24 |
| 步数 | 20 |
| 采样器 / 调度器 | euler / simple |
| denoise | 1.0 |
| 批次 | 1 |
| Sigma Shift | 12.0 / 3.0 |

608×352 是**社区的低分辨率测试尺寸**，不是标准 480p，也不等于官方默认的 768 短边。别拿它当画质基准。

**不要用 25 步**：社区 README 明确写了在其 8GB 测试机上 25 步导致不稳定，建议 20 步。

### 8.4 三条连跑

1. 第 1 条：种子固定 `42`，`RandomNoise` 的 control 设为 `fixed`。跑完记时间。
2. 第 2 条：种子改 `43`，其余不动。
3. 第 3 条：种子改 `44`，其余不动。

三条之间不重启 ComfyUI、不清缓存 —— 目的就是看连续运行会不会越跑越慢或 OOM。

### 8.5 记录项

另开一个 PowerShell 窗口采样（不占 GPU）：

```powershell
# 每 2 秒采一次显存与利用率，Ctrl+C 结束
nvidia-smi --query-gpu=timestamp,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv -l 2

# 另开一个窗口采系统可用内存
Get-Counter '\Memory\Available MBytes' -SampleInterval 2
```

每条填一行：

| 序号 | 种子 | 开始时间 | 结束时间 | 总耗时 | 峰值显存 (MiB) | 系统可用内存最低值 (MB) | 输出文件 | 文件大小 | 可播放 | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 42 | | | | | | `output\video\MiniMax_H3_FL2V_8GB_608x352_00001.mp4` | | 是/否 | |
| 2 | 43 | | | | | | `..._00002.mp4` | | 是/否 | |
| 3 | 44 | | | | | | `..._00003.mp4` | | 是/否 | |

**通过标准**（三条同时满足）：

- 三条全部跑完，无 OOM、无进程崩溃；
- 三个 mp4 都能正常播放，时长约 5 秒，画面不是全黑/全噪点；
- 第 3 条耗时相对第 1 条没有明显恶化（明显恶化说明有内存泄漏或卸载抖动，先别提高规格）。

**本包不承诺任何耗时数字。** 社区那台 8GB/16GB 的 4060 Laptop 在 480×864/158 帧下自报约 6.6 秒生成时长（这是视频时长，不是生成耗时）；3080 10GB 的实际生成耗时必须由你自己上面这张表填出来。不要从别人的数字外推。

### 8.6 通过之后

- 想提画质：先把分辨率提到 480×864（社区推荐的测试配置），帧数保持 124，观察显存；
- 想提时长：帧数往上加，但官方说训练区间约 124–362 帧，超过就属未验证区；
- 想快：再打开 Spectrum 对比，注意它改变轨迹，同种子结果会变；
- 每次只改一个变量，改完重跑 3 条。

---

## 9. 四种输入方式的差异

官方模型卡把 H3-Base 分成两个变体，输入能力不同。**本包只装了 FL2VA 权重**，所以下表的 FL2VA 三种模式可用，Ref2VA 不可用。

| 模式 | 对应节点 | 输入 | 实际能力 | 本包是否可用 |
|---|---|---|---|---|
| **纯文生**（t2va） | `MiniMaxH3ImageToVideo`，first_frame 与 last_frame **都不接** | 只有 prompt | 从文字直接生成视频，同时生成配套音频轨 | 可用 |
| **单图生视频** | 同上，**只接 first_frame** 或 **只接 last_frame** | prompt + 1 张图 | 官方 FL2VA 支持"零/一/两图"：一张图可作首帧，也可作尾帧。不是"图生视频"的独立模型 | 可用 |
| **首尾帧**（fl2va） | 同上，first_frame 与 last_frame **都接** | prompt + 2 张图 | 首帧锚定画面，尾帧按比例居中裁剪后锚定末帧，中间由模型补全 | 可用，工作流默认 |
| **多模态参考**（Ref2VA） | `MiniMaxH3ReferenceToVideo` | prompt + ≤9 图 / ≤3 视频（每条 2–15 秒，合计 ≤15 秒）/ ≤3 音频（同限制），全部文件合计 ≤12 | 参考生成，不是首尾帧约束。是另一条更复杂的路线 | **不可用**，需另下 11.77 GB 的 ref2va 权重 |

要点：

- **首帧和尾帧的几何处理不一样**：首帧是直接拉伸到画布（`_resize(..., "disabled")`），尾帧是按比例居中裁剪（`"center"`）。所以首帧变形比尾帧明显，宽高比差太多时首帧会拉伸。
- 官方规格：输出 4–15 秒、24fps、32kHz 立体声、默认 768 短边。124 帧 ≈ 5.2 秒，在官方时长区间内。
- **本工作流的输出是无声的**：`CreateVideo` 的 audio 输入没接线。这不代表 H3 不支持音频 —— H3 本身是音视频联合模型，只是这条社区工作流没接音频解码链路。
- "纯文生"和"单图"不是三个独立模板，而是同一个节点接不接图的问题。切换时**在工作流副本里**改，别覆盖原文件。

---

## 10. 故障排查

按现象查，不要按猜测改模型。

### 1. 驱动 / CUDA 报错

**现象**：启动即报 `CUDA driver version is insufficient for CUDA runtime version`、`torch.cuda.is_available()` 为 False、或 `no kernel image is available`。

- 先 `nvidia-smi` 看驱动版本，低于 580 就是驱动问题，**不要动模型和节点**。
- Portable 自带 PyTorch CUDA 13.0，CUDA 13.x 要求驱动 ≥580。
- 升级驱动后必须重启；`nvidia-smi` 里 `CUDA Version` 应显示 13.x。
- 仍失败时确认没有混用系统 Python 的 torch：只用 `python_embeded\python.exe`。

### 2. 缺节点

**现象**：画布上出现红色节点，控制台 `Cannot find node type: XXX`。

| 缺的节点 | 缺什么 | 处理 |
|---|---|---|
| `ClipProjApply` | 插件 1 未装 | 装 ComfyUI-ClipProj 到 `custom_nodes`，重启 |
| `SpectrumApplyMiniMaxH3` | 插件 2 未装 | 装 ComfyUI-Spectrum-MiniMax-H3，重启；或先旁路该节点跑基线 |
| `MiniMaxH3ImageToVideo` / `MiniMaxH3SigmaShift` | ComfyUI 版本太旧 | 用 `update\update_comfyui_stable.bat` 升级，重启 |
| `ModelAttentionBackend` | ComfyUI 版本太旧 | 同上 |

装完插件**必须重启 ComfyUI**，热加载不生效。

### 3. 量化不识别

**现象**：加载主模型时报 `Unsupported safetensors format`、`unknown quantization`、`KeyError` 于 state_dict、或进度条走到某处直接崩。

- 确认文件名逐字符一致（`pruned_w4a8_mixed`，不是 `w4a8`、不是 `w4a8_g32`）。仓库里还有 `wip/minimax_h3_ref2va_pruned_w6a8_g32.safetensors` 这类**不同格式**，别拿错。
- 确认 ComfyUI ≥0.31（int8_convrot VAE 支持起点），建议 ≥0.36。
- 确认 `UNETLoader` 的 weight_dtype 是 `default`，不要手动改成 fp8/fp16。
- 校验 SHA-256 与第 4 节一致 —— 续传中断产生的半文件不会报"文件损坏"，只会报格式错。
- **不要把"格式不识别"一律当成文件损坏**。先对版本，再对哈希。

### 4. ClipProj `KeyError: 'W'`

**现象**：`ClipProjApply` 加载矩阵时抛 `KeyError: 'W'`。

**原因（ClipProj README 原文）**：`-v3-mlp` 文件只带非线性残差，**不含线性矩阵 `W`**；0.1.13 之前的版本按老格式去找 `W`，找不到就抛这个错。

- 处理：把 ComfyUI-ClipProj 升到 **≥0.1.13**。
- 版本判断：看 `custom_nodes\ComfyUI-ClipProj\pyproject.toml` 的 `version`，**不要看 Git tag**（tag 只到 v0.1.4，与版本号不同步）。
- 升级：进目录 `git pull --ff-only`，然后重启。
- 若日志显示 `| residual only`，那是**正常的**，不是缺张量。
- 另一类同错：用 8B 矩阵配 4B 编码器（或反之），维度不匹配节点会拒绝。4B 输出 2560 维、8B 输出 4096 维。

### 5. 显存 / 内存不足

**现象**：`CUDA out of memory`、进程被系统杀掉、Windows 报"内存不足"、进度条卡在 VAE decode。

- 先确认语言模型已停：`ollama stop qwen3:8b-q4_K_M`；关浏览器、关别的 AI 客户端。
- 降规格顺序：608×352/124 帧 → 512×288/124 帧 → 480×864/124（社区推荐配置，像素量接近）→ 减帧到 90。
- 加 `--vram-headroom 1.5` 或 `--disable-smart-memory`（`--lowvram` 在动态显存下无效，见第 7 节）。
- 系统内存侧：32GB 里要给 Spectrum 的 `system_ram` 历史、编码器卸载、VAE 留空间。保持系统管理的分页文件开启，但**分页不能替代显存性能**，只会让速度掉得很难看。
- VAE decode 阶段 OOM 时，可试 `VAEDecodeTiled`（ComfyUI 原生；v0.32.0 修复了它在 H3 NestedTensor latent 上的崩溃，所以要用较新版本）。

### 6. Spectrum 报错

**现象**：`SpectrumApplyMiniMaxH3` 抛异常、跑出花屏/"confetti"、或采样直接失败。

- Spectrum 是**近似加速器**，会改变去噪轨迹。先保存工作流副本，**旁路掉 Spectrum 节点**（把 model 直连到 guider），验证基础链路能不能跑通。基线不通就不是 Spectrum 的问题。
- 它的版本迭代很快（当前 0.2.29），且对不同采样器有各自的兼容路径。用 `git pull --ff-only` 更新到最新，重启。
- 已知它对 ER-SDE、SEEDS、SA-Solver 等随机/多阶段采样器有专门修复历史；本工作流用 euler + simple，属最简单路径，出问题概率相对低。
- 对比速度时注意：`steps` 是外层 sigma 区间数，不等于 H3 实际模型调用次数。10 步 SEEDS-2 和 10 步 euler 不可直接比。
- 实在不行就长期关掉：20 步基线跑得动，就不必为了加速牺牲可复现性。

---

## 11. 未核实项与已知风险

**未核实**

1. **huggingface.co 直连可达性**：本机访问 huggingface.co 被代理拦截（`CONNECT tunnel failed, response 502`），无法直接 HEAD 官方域名。四个文件的大小与 SHA-256 是通过 hf-mirror.com（同一批仓库的镜像）的文件元数据 + 对 `resolve` 地址的 HEAD 请求（返回 `Content-Length` 与元数据逐字节一致）核实的。镜像与官方是否 100% 同源，未逐字节验证。
2. **ComfyUI 最低版本号**：官方 Release Notes 能确认 H3 支持起于 v0.30.0、int8_convrot VAE 起于 v0.31.0、VAE 优化在 v0.36.0，但社区工作流作者没给具体版本要求。本包"≥0.36"是推断。
3. **本机能否跑通**：完全没有在本机运行 ComfyUI，没有占用 GPU，没有任何实测耗时或显存数据。
4. **Ref2VA 工作流**：本包不含 ref2va 权重，也没有核实对应的节点连线与参数。
5. **输出视频文件大小**：608×352/124 帧的实际 mp4 体积未核实。
6. **`--fp16-vae` 与 int8 VAE 的组合行为**：官方 help 只说 fp16 VAE 可能黑图，没说对 int8 convrot VAE 的具体影响。社区组合里带了它，本包照抄但保留"黑图就摘掉"的处置。
7. **comfy-kitchen 是否随 Portable 预装**：`ModelAttentionBackend` 的 `comfy kitchen attention` 选项依赖 comfy-kitchen 的 INT8 attention 可用性，Portable 当前包是否预装未核实。若下拉框只有 `pytorch attention`，就是没装，工作流会回退（能跑，更慢）。

**已知风险**

1. **同名不同源**：`minimax_h3_fl2va_pruned_w4a8_mixed.safetensors` 在 Kijai 与 starsfriday 两个仓库里**同名同大小但 SHA-256 不同**。混用或换源续传会产生坏文件。
2. **社区实测硬件不同**：8GB 工作流的实测机是 RTX 4060 Laptop / 16GB 内存，与 3080 10GB / 32GB 不同架构不同代。不能直接外推成功率和耗时。
3. **608×352 不是画质基准**：它是低分辨率测试尺寸，用它跑通不代表 720p 可用。
4. **Spectrum 破坏可复现性**：同种子同工作流，开了 Spectrum 输出也会变。
5. **驱动升级是硬前置**：560.94 直接上 CUDA 13 Portable 一定失败。升驱动属于系统级变更，本包不代做，也没有回滚方案。
6. **授权**：四个文件均为社区产物，各自模型卡与 MiniMax H3 Community License 的商用范围需自行确认。

---

## 12. 来源清单（访问日期 2026-10-29）

**官方**

| 内容 | URL |
|---|---|
| MiniMax H3 官方仓库（模型变体与输入规格、输出 4–15s/24fps/32kHz） | https://github.com/MiniMax-AI/MiniMax-H3 |
| MiniMax H3 官方模型卡 | https://huggingface.co/MiniMaxAI/MiniMax-H3 |
| ComfyUI 系统要求（Portable 带 Python 3.13 + PyTorch CUDA 13.0） | https://docs.comfy.org/installation/system_requirements |
| ComfyUI Portable Windows 说明（目录结构、7-Zip、启动方式） | https://docs.comfy.org/installation/comfyui_portable_windows |
| NVIDIA CUDA 驱动兼容表（CUDA 13.x 要求 ≥580） | https://docs.nvidia.com/deploy/cuda-compatibility/minor-version-compatibility.html |
| ComfyUI Releases（v0.30.0 / v0.31.0 / v0.36.0 / v0.43.0 变更） | https://github.com/Comfy-Org/ComfyUI/releases |
| ComfyUI 启动参数定义（`comfy/cli_args.py`） | https://github.com/Comfy-Org/ComfyUI/blob/master/comfy/cli_args.py |
| ComfyUI 原生 H3 节点（`comfy_extras/nodes_minimax_h3.py`） | https://github.com/Comfy-Org/ComfyUI/blob/master/comfy_extras/nodes_minimax_h3.py |
| ComfyUI `ModelAttentionBackend`（`comfy_extras/nodes_model_advanced.py`） | https://github.com/Comfy-Org/ComfyUI/blob/master/comfy_extras/nodes_model_advanced.py |
| comfy-kitchen（INT8 attention 内核库） | https://github.com/Comfy-Org/comfy-kitchen |

**社区**

| 内容 | URL |
|---|---|
| Kijai H3 实验仓库（主模型 W4A8 + 视频 VAE int8） | https://huggingface.co/Kijai/MiniMax-H3-experimental |
| Stick9190 Qwen3-VL 4B int8 编码器 | https://huggingface.co/Stick9190/qwen3vl_4b_int8_convrot |
| NicoLab28 ClipProj 矩阵（含 `KeyError: 'W'` 说明、15.7GB→5.2GB） | https://huggingface.co/NicoLab28/ClipProj-MiniMax-H3 |
| ClipProj 插件（pyproject version 0.1.13、tag 只到 v0.1.4） | https://github.com/nicolab28/ComfyUI-ClipProj |
| Spectrum 插件（近似加速器、v0.2.29、无 pip 依赖） | https://github.com/xmarre/ComfyUI-Spectrum-MiniMax-H3 |
| 8GB 工作流仓库（实测硬件、480×864 推荐、25 步不稳定） | https://github.com/reventadirecta/MiniMax-H3-ComfyUI-8GB-VRAM |
| 工作流 JSON（18 节点，608×352/124/24fps/20 步） | https://github.com/reventadirecta/MiniMax-H3-ComfyUI-8GB-VRAM/blob/main/workflows/MiniMax_H3_FL2V_8GB_VRAM.json |
| 工作流模型清单 | https://github.com/reventadirecta/MiniMax-H3-ComfyUI-8GB-VRAM/blob/main/docs/MODELS.md |
| 工作流安装说明（ClipProj ≥0.1.13、`--lowvram --fp16-vae`） | https://github.com/reventadirecta/MiniMax-H3-ComfyUI-8GB-VRAM/blob/main/docs/INSTALLATION.md |
| starsfriday W4A8（同名文件备选源，哈希不同） | https://huggingface.co/starsfriday/MiniMax-H3-w4a8 |

---

## 13. 最短执行顺序

1. 升驱动到 580 系列以上，重启，`nvidia-smi` 确认。
2. 下载 Portable，7-Zip 解压到 `D:\LocalAI\video\`。
3. `download-minimax-h3.ps1 -DryRun` 看计划 → 去掉 `-DryRun` 下载四个文件。
4. 装两个插件到 `custom_nodes`，确认 ClipProj 的 `pyproject.toml` 是 0.1.13+。
5. `ollama stop qwen3:8b-q4_K_M`，关掉其他占显存的程序。
6. 低显存参数启动，先开空白画布确认环境正常。
7. 导入工作流 JSON 副本，换两张自己的图，确认四个下拉框指向第 4 节的文件。
8. 608×352 / 124 帧 / 24fps / 20 步，种子 42，跑第 1 条并记录。
9. 种子 43、44 再跑两条，填完第 8.5 节的表。
10. 三条全过再谈提规格；不过就按第 10 节排查。

本包不含任何安装、下载、驱动更新动作。所有执行由你本人完成。
