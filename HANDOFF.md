# HANDOFF — 本地 AI 部署项目接管说明

最后更新：2026-10-30 04:05（Asia/Shanghai）
当前状态：**图像/视频生成线已完成并通过进阶验收**——ComfyUI v0.43.0 运行中；Qwen-Image 2.1 t2i / image_edit 成功；H3 已验收 608×352（124 帧）、480×864（横版与竖版输入）与 608×352/158 帧三种配置，各三条连跑全部成功，无 OOM、无恶化。用户已决定敏感数据分析线不做，项目范围收缩为图像/视频生成。

## 1. 这是什么项目

用户要在本机（Windows 11 / i7-13700KF / RTX 3080 10GB / 32GB RAM / 驱动 621.01，2026-10-29 升级）落地本地 AI。原规划两类：

1. **敏感数据分析**：Ollama + Qwen3 8B + pandas/DuckDB，配合文档、扫描件、数据库和日志处理。**2026-10-29 用户决定不做，本条目撤销。**
2. **视频与图片生成**：ComfyUI + MiniMax H3 低显存路线；Qwen-Image 系列图片生成。**当前唯一在做的方向。**

项目目录：`E:\mm3`（非 Git 仓库）。
敏感数据要求：原始资料、索引、报告都保存在本地非云同步目录；不把真实敏感数据粘贴到在线聊天。

## 2. Codex 已完成的部分

来源会话：Codex Desktop `01a186a9-bb49-7150-b16c-72f2104da829`，工作目录 `E:\mm3`。

| 文件 | 内容 | 状态 |
|---|---|---|
| `outputs/local-ai-plan-2026-10-29/README.md` | 硬件核查、Ollama/Qwen3 8B 方案、MiniMax H3 视频路线、最短执行顺序 | 已完成 |
| `outputs/local-ai-plan-2026-10-29/ALL-DATA-CHECKLIST.md` | 表格、文档、扫描件、知识库、数据库、日志的分阶段清单 | 已完成 |
| `outputs/local-ai-plan-2026-10-29/Start-LocalOllama.ps1` | 本地 Ollama 启动脚本（模型放 D 盘、仅本机监听、关云） | 已完成，未实机验证 |
| `outputs/local-ai-plan-2026-10-29/Analyze-LocalCsv.ps1` | CSV 分组求和 + 本地模型解释 | 已用虚构数据验证，未接真实模型 |

**没有完成的部分**：没有安装 Ollama/Python/ComfyUI，没有下载模型，没有更新驱动，没有跑过真实数据分析或视频生成。

Codex 最后收到但未完成的需求：
> 视频想今天同步部署，还想增加生成图片的需求，可以部署 qwen2.1 image 吗

## 3. 本轮交付（2026-10-29，已完成）

本轮只交付**可直接执行**的部署包，未实际安装、未下载模型、未改驱动。

| 包 | 产物 | 执行者 | 状态 | 内容摘要 |
|---|---|---|---|---|
| 图像 | `deploy/qwen-image/` | Qoder CN | `verified` | 首选 Qwen-Image-2.1 int8（3 个文件，16.10 GiB）；同时覆盖 20B 文生图与 Edit-2509；1024×1024 首测；非商业许可 |
| 视频 | `deploy/minimax-h3/` | WorkBuddy AI | `verified` | H3 FL2VA W4A8 + Qwen3-VL 4B int8 + ClipProj v3-mlp + int8 VAE（4 个文件，20.11 GiB）；首测 608×352/124f/24fps/20 步；要求驱动 ≥580 |

每个包都包含：

- `README.md`：推荐路线、精确文件清单、目录布局、显存评估、启动参数、首测参数、验收流程、故障排查、来源与访问日期。
- `manifest.json`：机器可读的下载清单与版本要求。
- `download-*.ps1`：只下载、不安装的 PowerShell 5.1 脚本，支持 `-TargetRoot` 与 `-DryRun`。

用户已确认的决策：

1. 先出方案和脚本，安装与下载由用户本人执行。
2. Qwen-Image（文生图）与 Qwen-Image-Edit（改图）都要调研，最后推荐先装一个。
3. 已授权重启 Qoder CN 与 WorkBuddy AI 以开启调试端口。
4. 分工：Qoder CN 做图像，WorkBuddy AI 做视频。

## 4. 协作方式与桌面注意事项

- 使用 `C:\Users\pc\.codex\skills\work-together` 技能，workflow 模式，本地执行，不接 Gitee。
- 实际主持是当前 Qoder 会话；因为技能禁止主持方把任务派给同族执行器，`plan.json` 内部登记 `coordinator=codex`（延续 Codex 原任务）。这只影响工具内部标注，不改变验收责任。
- **绝不能重启 Qoder 国际版**（当前主持会话所在应用）。只启动 Qoder CN 与 WorkBuddy AI。
- 系统 Node 已从 v21.4.0 升级为 **v24.22.2**（满足技能 Node ≥22.13 要求），`C:\Program Files\nodejs` 符号链接已指向 `C:\Users\pc\AppData\Roaming\nvm\v24.22.2`。

### 桌面启动的关键注意事项

Qoder 会话的 Bash 环境自带 `ELECTRON_RUN_AS_NODE=1` 和一组 `QODER_*` 变量。直接启动 Electron 桌面应用会被当成 Node 执行并立刻退出（Qoder CN 表现为 exit code 9）。**启动任何桌面执行器前必须先清理环境变量**：

```powershell
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
Get-ChildItem Env: | Where-Object { $_.Name -match "^(QODER|QODERCLI)" } | ForEach-Object { Remove-Item ("Env:" + $_.Name) -ErrorAction SilentlyContinue }
$env:QODERCN_CONFIG_DIR = "C:\Users\pc\.qoder-cn"   # 仅启动 Qoder CN 时设置
```

当前实际路径与免费模型：

| 执行器 | 可执行文件 | 端口 | 模型 | 权限 |
|---|---|---|---|---|
| Qoder CN | `E:\application\Qoder CN\.qoder-versions\0.4.11\Qoder CN.exe` | 19334 | `deepseek-flash / dfmodel`（免费） | `bypassPermissions` |
| WorkBuddy AI | `E:\application\WorkBuddyAI\WorkBuddyAI.exe` | 19335 | `deepseek-v4.1-flash`（免费） | `bypassPermissions` |

已完成的会话（均 `verified`，桌面可见性已确认）：

| 包 | 执行器 | sessionId |
|---|---|---|
| `qwen-image` | Qoder CN | `f1eaf3aa-b363-4337-afc9-fbf824f6a5a0` |
| `minimax-h3` | WorkBuddy AI | `05b8ae6e-b239-4c3c-92c2-d5887d7bc1a8` |

## 5. 当前文件地图

| 路径 | 所有者 | 说明 |
|---|---|---|
| `HANDOFF.md` | 主持方 | 本文件，跨会话交接入口 |
| `SPEC.md` | 主持方 | 两包的范围、质量要求与验收条件 |
| `PLAN.md` | 主持方 | 分工、文件归属、命令与检查点 |
| `plan.json` | 主持方 | work-together 调度计划 |
| `outputs/local-ai-plan-2026-10-29/**` | Codex 原任务 | 只读的上一轮方案与脚本 |
| `docs/**` | 主持方 | 跨会话文档：实操手册、部署文档、公众号推文；`docs/assets/` 为过程对比图 |
| `deploy/qwen-image/**` | Qoder CN | 图像部署包（已验收） |
| `deploy/minimax-h3/**` | WorkBuddy AI | 视频部署包（已验收） |
| `.work-together/` | 主持方 | 调度状态、日志、验收证据，不对外发布 |

验收证据：

- `.work-together/qwen-image.verification.md`
- `.work-together/minimax-h3.verification.md`

## 6. 验收结论

SPEC 的 A1–A7、B1–B8 全部通过。独立抽查的关键结果：

- **Qwen**：官方 `image_qwen_image_2_1_t2i.json` 模板使用的正是推荐的三件套；CLIP type `qwen_image`、25 步、CFG 1、euler/simple、1024×1024 与 README 一致。ModelScope 文件 API 的 Size 与 SHA-256 已记录在验收证据中，manifest 的 8 个链接均 HTTP 200。
- **H3**：4 个文件的 hf-mirror LFS `oid` 与 manifest 的 SHA-256 完全一致，大小合计 21,590,132,744 字节；工作流 JSON 为 18 节点，608×352/124/24fps/20 步/shift 12+3 与 README 一致，音频输入未接线；ClipProj `pyproject` 版本 0.1.13、Spectrum v0.2.29 均已核实。
- **脚本**：两份脚本均通过 PowerShell 5.1 语法解析；`-DryRun` 退出码 0，不创建目录，代码路径在任何网络请求之前结束。
- **边界**：执行者只写入了各自的 `deploy/` 目录；HANDOFF/PLAN/SPEC 的改动均来自主持方，已登记并更新指纹基线。

## 7. 后续如何继续

查看状态：

```powershell
cd E:\mm3
node "C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs" status
```

重新打开原会话（只查看，不重派）：

```powershell
node "C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs" open qwen-image
node "C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs" open minimax-h3
```

建议的用户执行顺序：

1. **视频包**：608×352/124 帧、480×864（竖版输入）与 608×352/158 帧均完成三条连跑验收（7.6–7.9）。下一步可选：帧数逐档升到 176/193；或提高分辨率（需先实测显存，10GB 卡余量已很小）。每次只改一个变量并重跑 3 条。
2. **图像包**：已完成下载、1024×1024 首测、image_edit 与竖版 768×1344 生成（见 7.2、7.3、7.8）。下一步可调 `ResolutionSelector` 到 2 megapixels 或试其他版式。若需商用，改走 20B Apache-2.0 路线。
3. 敏感数据分析线已撤销，不再需要 Ollama/Qwen3 8B 安装。

### 7.1 ComfyUI 实际安装（2026-10-29 20:55）

- 安装目录：`D:\LocalAI\ComfyUI_windows_portable`；启动：双击 `run_nvidia_gpu.bat`，或运行 `python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build`。
- 访问地址：`http://127.0.0.1:8188`；当前进程已在后台运行，UI 已在浏览器中加载成功。
- 运行时：Python 3.13.14、PyTorch 2.13.0+cu130、RTX 3080 10GB、驱动 621.01（CUDA 13.5）。
- 来源：魔搭数据集 `taoluban/comfyui-portable`，压缩包 `D:\LocalAI\downloads\ComfyUI_windows_portable_nvidia_modelscope.7z`，大小 2,133,107,036 字节，SHA-256 `4a221588979b96b8244e0e50b2edca03af732acae1deba69d60aa3b4d60b9dba`（已核对）。
- 该魔搭包内置的是 ComfyUI 0.33.1（2026-08-14）；已通过 `gh-proxy.com` 拉取 tag `v0.43.0`（commit `426f5eea52a7ece1dd599fff4cb6cd1f352ddd24`）并切换，依赖从腾讯 PyPI 镜像升级到 frontend 1.57.4、templates 0.11.97、embedded-docs 0.5.15、comfy-kitchen 0.2.40、comfy-aimdo 0.6.0。
- 已核验：`/system_stats` 返回 ComfyUI 0.43.0；`/object_info` 共 1018 个节点，包含 `TextEncodeQwenImage21`、`EmptyMiniMaxH3LatentAV`、`MiniMaxH3ImageToVideo` 等原生节点；UI 中文界面正常。
- 尚未下载 H3 权重；视频路线仍需按 `deploy/minimax-h3/README.md` 执行。

### 7.2 Qwen-Image 2.1 模型下载与首测（2026-10-29 21:50）

**下载**

- 命令：`powershell -File deploy/qwen-image/download-qwen-image.ps1 -Bundle recommended -TargetRoot "D:\LocalAI\ComfyUI_windows_portable\ComfyUI"`
- 时间与速度：21:25–21:42，约 17 分钟，峰值约 23 MB/s、平均约 16 MB/s；全程走 manifest 的 ModelScope 主 URL，未回退 hf-mirror。
- 结果：3/3 下载成功，`Downloaded: 3 / Skipped: 0 / Failed: 0`，脚本按字节数校验后改名。

| 文件 | 字节 | SHA-256（本地计算，与官方元数据一致） |
|---|---|---|
| `models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors` | 7,256,783,064 | `cb74113cb03faecd79611b01fd7fd642f0aa60d6f0b95086abee214d75eaa57d` |
| `models/text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 9,350,798,360 | `8bfd0f6e12abf2d2d697ecc888e5e90b0d6741d6708f05799f53afa560452e8f` |
| `models/vae/qwen_image_2.1_vae_bf16.safetensors` | 675,509,688 | `bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9` |

合计 17,283,091,112 字节，与 manifest 完全一致。日志 `D:\LocalAI\downloads\qwen-image-download.log`，哈希记录 `D:\LocalAI\downloads\qwen-image-sha256.txt`。

**ComfyUI 识别**

- `/object_info/UNETLoader` 列出 `qwen_image_2.1_int8_convrot.safetensors`。
- `/object_info/CLIPLoader` 列出 `qwen3vl_8b_int8_convrot.safetensors`，`type` 含 `qwen_image`。
- `/object_info/VAELoader` 列出 `qwen_image_2.1_vae_bf16.safetensors`。

**首测**

- 工作流按官方模板 `image_qwen_image_2_1_t2i` 的子图构造为 API 格式：`UNETLoader → QwenImage21Cache(auto/default) → KSampler`，`TextEncodeQwenImage21`（resolution 1024，vae 已接），`EmptyLatentImage 1024×1024×1`，`KSampler` seed 12345/12346/12347、25 步、cfg 1.0、euler/simple、denoise 1.0，`SaveImage` 前缀 `Qwen21_*`。
- 提示词：`一张极简海报，白色背景，中央黑色中文大字“本地出图”，下方小字“RTX 3080 10GB”，平面设计，高清，边缘干净`；负面提示词为空；提示词增强 `refine_prompt=off`（PE 模型未下载，不影响基础出图）。
- 结果：3/3 成功，耗时 17.9 s / 14.2 s / 14.0 s（含首次加载）；采样约 1.9 it/s。
- 显存：峰值 9,529 MiB / 10,240 MiB，未观察到共享内存溢出；采样期间 GPU 利用率正常。
- 产物：`D:\LocalAI\ComfyUI_windows_portable\ComfyUI\output\Qwen21_first_test_00001_.png`、`Qwen21_run_12346_00001_.png`、`Qwen21_run_12347_00001_.png`；1024×1024 PNG，中文“本地出图”字形正确、无乱码。
- 复现文件：`D:\LocalAI\work\qwen21-first-test-prompt.json`、`qwen21-run-12346.json`、`qwen21-run-12347.json`。

### 7.3 Qwen-Image 2.1 参考图编辑首测（2026-10-29 22:10）

- 模板：`image_qwen_image_2_1_image_edit`；按其子图构造 API 工作流，单图走 `images.image_1`，latent 取 `TextEncodeQwenImage21` 的 latent 输出（跟随参考图尺寸），其余参数同 9.2：25 步、cfg 1.0、euler/simple、denoise 1.0、resolution 1024。
- 输入图：把 7.2 生成的 `Qwen21_first_test_00001_.png` 复制为 `ComfyUI\input\qwen21_poster_ref.png`。
- 指令：`把背景从白色换成深蓝色到黑色的渐变，保留“本地出图”和“RTX 3080 10GB”两段文字、字体与排版完全不变，文字保持清晰，整体仍为极简海报`。
- 结果：成功，27.1 s；显存峰值 9,186 / 10,240 MiB；输出 `ComfyUI\output\Qwen21_edit_test_00001_.png`（1024×1024）。
- 观察：背景替换与文字保真都符合指令；因为提示词要求“文字不变”，文字仍是黑色，在深色背景上对比度偏低——这是指令约束的结果，不是模型缺陷。若要海报可读，需明确写“文字改为白色”。
- 白色文字复跑（22:16）：同一输入图与参数，指令改为“文字改成白色，字体与排版完全不变，文字保持清晰锐利”，成功，25.2 s，输出 `ComfyUI\output\Qwen21_edit_white_test_00001_.png`；文字变为白色、清晰可读，字形与排版保持。复现文件 `D:\LocalAI\work\qwen21-edit-white-test.json`。
- 复现文件：`D:\LocalAI\work\qwen21-edit-first-test.json`。

### 7.4 MiniMax H3 模型下载与校验（2026-10-29 22:50）

- 总计 21,590,132,744 字节（20.11 GiB），4/4 下载完成，SHA-256 4/4 一致。
- 魔搭优先：Kijai 仓库在魔搭有镜像，两个大文件走魔搭 `Kijai/MiniMax-H3-experimental`（22:13–22:24，主模型约 26 MB/s、VAE 约 18 MB/s）。
- 另两个仓库魔搭无镜像（Stick9190、NicoLab28 均 404）：走 `deploy/minimax-h3/download-minimax-h3.ps1 -HfMirror -VerifyHash`（22:26–22:45，hf-mirror 约 5 MB/s，并顺带校验全部四个文件）。

| 文件 | 字节 | 来源 | SHA-256（已核对） |
|---|---|---|---|
| `models/diffusion_models/minimax_h3_fl2va_pruned_w4a8_mixed.safetensors` | 12,540,858,008 | 魔搭 | `01aa7b92c007c599890461c325f9b7e3c96fb06c36f242f95b62f7f20e538dec` |
| `models/text_encoders/qwen3vl_4b_int8_convrot.safetensors` | 5,374,169,456 | hf-mirror | `ebbb3efdf4a6e1b766e32f6dc4fa92af9530edede0968c070b3e604aeca413aa` |
| `models/clip_projections/mmh3-4b-ClipProj-v3-mlp.safetensors` | 503,434,368 | hf-mirror | `feef06ef3b9aede3b1f3331b71eebbc873e21a867d73bcf40ea2c0b007270693` |
| `models/vae/minimax_h3_video_vae_int8_convrot.safetensors` | 3,171,670,912 | 魔搭 | `9bb2d96f218c76babd85e0611b85ca8fb330a90546c01a0005e8a58a59593410` |

- ComfyUI 识别：`UNETLoader` 列出 H3 主模型，`CLIPLoader` 列出 `qwen3vl_4b_int8_convrot.safetensors` 且 type 含 `krea2`，`VAELoader` 列出 H3 VAE。
- `clip_projections/mmh3-4b-ClipProj-v3-mlp.safetensors` 需要 `ComfyUI-ClipProj` 插件提供 `ClipProjApply` 节点，装插件前不显示在选择器里，属预期。
- 日志：`D:\LocalAI\downloads\minimax-h3-modelscope.log`、`D:\LocalAI\downloads\minimax-h3-hfmirror.log`。
- 视频已跑通并完成多规格验收：见 7.6–7.9。

### 7.5 H3 插件安装与 ComfyUI 重启（2026-10-29 23:00）

- 安装位置：`D:\LocalAI\ComfyUI_windows_portable\ComfyUI\custom_nodes\`
  - `ComfyUI-ClipProj`：`pyproject.toml` version **0.1.13**（仓库 tag 只到 v0.1.4，不以 tag 判断版本）
  - `ComfyUI-Spectrum-MiniMax-H3`：`pyproject.toml` version **0.2.29**
- 来源：GitHub 直连不可用，两个仓库均通过 `gh-proxy.com` 代理 `git clone --depth 1` 获取。
- 依赖：两个插件的 `dependencies` 均为空，没有执行 pip 安装。
- 重启：结束原进程 PID 23824，重新运行 `python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build`；日志显示两个自定义节点分别以 0.0 s / 0.3 s 导入，无报错；`[ClipProj] graph watch installed` 与 `unload hook installed` 正常。
- 节点验证：`/object_info/ClipProjApply` 存在，`projection` 选项含 `mmh3-4b-ClipProj-v3-mlp.safetensors`；`/object_info/SpectrumApplyMiniMaxH3` 存在。`/system_stats` 返回 200。
- 备注：日志里 `comfy_kitchen backend triton` 不可用与插件无关（未安装 triton 模块），不影响 H3。

### 7.6 H3 视频首测与三条连跑验收（2026-10-29 23:08–23:17）

- 工作流：以社区 `MiniMax_H3_FL2V_8GB_VRAM.json`（18 节点）为参照改写为 API 格式，`D:\LocalAI\work\minimax-h3-first-test.json`。链路：`UNETLoader → ModelAttentionBackend(comfy kitchen attention) → MiniMaxH3SigmaShift(12.0/3.0) → SpectrumApplyMiniMaxH3(默认参数) → BasicGuider`；`CLIPLoader(krea2) → ClipProjApply(v3-mlp) → MiniMaxH3ImageToVideo`；`euler + simple, 20 步, denoise 1.0`；`VAEDecode → CreateVideo(24fps) → SaveVideo(prefix video/MiniMax_H3_FL2V_608x352_test)`。
- 输入图：沿用 Qwen 白字海报（7.3 产物）作首帧、深色白字编辑图作尾帧，居中裁剪为 608×352，复制到 `ComfyUI\input\h3_first_frame.png` / `h3_last_frame.png`。
- 提示词：`Locked-off camera on a minimalist poster. The white background smoothly deepens into a dark blue-to-black gradient while the black Chinese title and the subtitle turn into crisp white text; the layout stays perfectly still, subtle light sweep across the paper texture, smooth temporal continuity, no camera shake, high detail.`
- 参数：608×352、124 帧、24fps、20 步、euler/simple、denoise 1.0、Sigma Shift 12.0/3.0、seed 42（fixed）、batch 1，Spectrum 开启（默认参数）。
- 与社区工作流的差异：`BasicScheduler` 在社区 JSON 里 `model` 未连线但节点必填，这里接 Spectrum 节点输出，其余保持默认。
- 结果：成功，总耗时 **55.2 s**（含首次加载；采样 20 步约 32 s，1.63 s/it）；显存峰值 **9,201 MiB / 10,240 MiB**，MiniMaxH3 主模型驻留 11,956 MB、VAE 2,677 MB，无 OOM、无共享内存溢出。
- 产物：`D:\LocalAI\ComfyUI_windows_portable\ComfyUI\output\video\MiniMax_H3_FL2V_608x352_test_00001_.mp4`，608×352、124 帧、24fps、5.1667 s、325,210 字节。
- 画面验证：用 `python_embeded` 的 PyAV 解码出 124 帧，查看首/中/尾三帧——首帧为白底黑字海报，中段背景过渡为深蓝黑渐变、文字变白，尾帧为深色底白字“本地出图 / RTX 3080 10GB”；无全黑、无噪点、无撕裂。
- 说明：README 8.4 的三条连跑已完成（种子 42/43/44，见下表）；三条之间未重启 ComfyUI、未清缓存，日志均为 `0 models unloaded`，模型保持驻留。
- 三条连跑记录（参数完全一致，仅换种子）：

| 序号 | 种子 | 耗时（ComfyUI 记录） | 采样速度 | 峰值显存 | 输出文件 | 大小 | 可播放 |
|---|---|---|---|---|---|---|---|
| 1 | 42 | 55.17 s | 1.63 s/it | 9,201 MiB（3 s 采样） | `..._00001_.mp4` | 325,210 B | 是 |
| 2 | 43 | 50.67 s | 1.65 s/it | 9,583 MiB（2 s 采样） | `..._00002_.mp4` | 333,074 B | 是 |
| 3 | 44 | 48.44 s | 1.69 s/it | 9,622 MiB（2 s 采样） | `..._00003_.mp4` | 257,748 B | 是 |

- 三条均 608×352、124 帧、5.1667 s；解码逐帧复核，无 OOM、无崩溃、无全黑/噪点。第 3 条比第 1 条快 6.7 s，无性能恶化。
- 显存峰值第 2、3 条偏高（9,583/9,622 MiB）：第 1 条采样间隔 3 s 可能漏采峰值，且后续两条文本编码器与 VAE 常驻；余量仍有约 618 MiB，未触发共享内存。
- 画面差异（不同种子的正常随机性）：种子 42 中段为深蓝黑渐变白字；种子 43 中段仍在灰蓝过渡、黑字对比度偏低，尾帧才完全变白；种子 44 过渡更快，中段已是深底白字。三条尾帧均与目标图一致。
- 结论：README 8.4 验收通过（3/3 完成、可播放、无恶化），608×352 规格可稳定连续出片。复现文件 `D:\LocalAI\work\minimax-h3-seed43.json`、`minimax-h3-seed44.json`；显存采样 `D:\LocalAI\work\h3-vram.log`、`h3-vram-2.log`。

### 7.7 H3 480×864 分辨率测试（2026-10-29 23:28–23:34）

按 README 8.6 提分辨率：宽高改为 480×864（像素约 1.94×），帧数保持 124，其余参数与 7.6 完全一致；连跑种子 42/43/44，不重启、不清缓存。

| 序号 | 种子 | 耗时（ComfyUI 记录） | 采样速度 | 峰值显存 | 输出文件 | 大小 |
|---|---|---|---|---|---|---|
| 1 | 42 | 115.17 s | 3.71 s/it | 9,735 MiB | `MiniMax_H3_FL2V_480x864_test_00001_.mp4` | 454,944 B |
| 2 | 43 | 108.36 s | 3.75 s/it | 9,731 MiB | `MiniMax_H3_FL2V_480x864_test_00002_.mp4` | 1,263,595 B |
| 3 | 44 | 108.43 s | 3.76 s/it | 9,725 MiB | `MiniMax_H3_FL2V_480x864_test_00003_.mp4` | 595,104 B |

- 三条均成功：480×864、124 帧、5.1667 s，逐帧解码可播、无全黑/噪点，无 OOM、无共享内存溢出，日志无 error。
- 耗时约为 608×352 的 2.2 倍（采样 3.7 s/it vs 1.6 s/it），三条之间稳定、无恶化。
- 显存峰值 9,725–9,735 MiB，距上限仅约 505 MiB，比 608×352（9,622）更贴顶；长时间使用或并行其他 GPU 任务时需留意。
- 构图注意：输入首尾帧是 608×352 横图，竖幅画布下首帧被适配缩放到画面内、尾帧按比例居中裁剪（与 README 8.3 描述一致），因此尾段文字被裁掉两侧。这是横图喂竖幅的输入适配问题，不是模型缺陷；做正式竖屏视频需先准备 480×864 竖版首尾帧。
- 结论：480×864 通过三条连跑（稳定、无恶化），但速度约翻倍、显存余量约 0.5 GiB，属于 10GB 卡的可用上限区。复现文件 `D:\LocalAI\work\minimax-h3-480x864-seed42.json`、`-seed43.json`、`-seed44.json`；显存采样 `D:\LocalAI\work\h3-vram-480.log`。

### 7.8 竖版输入帧与 480×864 竖屏验收（2026-10-29 23:41–23:47）

- 背景：7.7 用横版输入喂竖幅画布导致尾帧文字被裁；本次先用 Qwen 生成竖版首尾帧，消除输入适配问题。
- 首尾帧：Qwen-Image 2.1 文生图 768×1344（seed 2026，19.7 s）→ `Qwen21_portrait_white_00001_.png`；image_edit 改深色渐变白字（27.2 s）→ `Qwen21_portrait_dark_00001_.png`；居中裁剪 746×1344 后缩放到 480×864，存为 `ComfyUI\input\h3_480x864_first.png` / `h3_480x864_last.png`。复现文件 `D:\LocalAI\work\qwen21-portrait-white.json`、`qwen21-portrait-dark.json`。
- H3 参数与 7.6 完全一致，仅分辨率 480×864、换竖版输入、换输出前缀：

| 序号 | 种子 | 耗时（ComfyUI 记录） | 采样速度 | 峰值显存 | 输出文件 | 大小 |
|---|---|---|---|---|---|---|
| 1 | 42 | 126.33 s | — | 9,052 MiB | `MiniMax_H3_FL2V_480x864_portrait_test_00001_.mp4` | 422,383 B |
| 2 | 43 | 103.93 s | — | 9,564 MiB | `..._00002_.mp4` | 574,661 B |
| 3 | 44 | 103.30 s | — | 9,628 MiB | `..._00003_.mp4` | 432,163 B |

- 三条均 480×864、124 帧、5.1667 s，可播放、无 OOM；构图正确，竖版文字完整，尾帧与目标图一致。
- 画质观察：种子 43 在第 70–90 帧附近出现密集白色噪斑（类似粒子风暴），第 110 帧后恢复干净；种子 42/44 无此现象。属于种子/轨迹差异（Spectrum 会放大此类差异），遇到时换种子重跑即可。
- 复现文件 `D:\LocalAI\work\minimax-h3-480x864-portrait-seed42/43/44.json`；显存采样 `D:\LocalAI\work\h3-vram-480-portrait.log`。

### 7.9 608×352 / 158 帧长时长测试（2026-10-29 23:47–23:51）

- 在 7.6 基础上仅把帧数 124 → 158（158 = 17×9+5，6.58 s @24fps），分辨率、步数、种子、输入图均不变；连跑种子 42/43/44。

| 序号 | 种子 | 耗时（ComfyUI 记录） | 采样速度 | 峰值显存 | 输出文件 | 大小 |
|---|---|---|---|---|---|---|
| 1 | 42 | 73.31 s | 2.23 s/it | 9,430 MiB | `MiniMax_H3_FL2V_608x352_158f_test_00001_.mp4` | 357,198 B |
| 2 | 43 | 66.39 s | 2.23 s/it | 9,603 MiB | `..._00002_.mp4` | 288,484 B |
| 3 | 44 | 66.27 s | 2.24 s/it | 9,577 MiB | `..._00003_.mp4` | 346,713 B |

- 三条均成功：608×352、158 帧、6.5833 s，逐帧解码可播、无全黑/噪点，无 OOM、无共享内存溢出；尾帧画面正确。
- 相比 124 帧：多 34 帧（+27% 时长）只多约 13–18 s，显存峰值持平（≤9,603 MiB），性价比高。
- 结论：608×352 下 158 帧稳定可用，可作为默认时长档；继续加帧（176/193，仍在 17k+5 网格内）需再逐档实测。复现文件 `D:\LocalAI\work\minimax-h3-608x352-158f-seed42/43/44.json`；显存采样 `D:\LocalAI\work\h3-vram-158f.log`。

新一轮任务（例如“H3 实际安装与端到端验收”）开始前，先归档整个 `.work-together/`，再创建新的 `plan.json`；不要直接在现有运行记录上重跑。

## 8. 已知风险与限制

- **Qwen 与 H3 均已实测**：Qwen-Image 2.1 t2i / image_edit / 竖版 768×1344 均成功；H3 608×352（124 与 158 帧）、480×864（横版与竖版输入）三条连跑验收均通过；176+ 帧与更高分辨率仍未实测。
- **H3 种子差异明显**：同一提示词下不同种子可能产生中段噪斑等瞬时伪影（7.8 种子 43 在 70–90 帧出现粒子噪点），属轨迹差异，Spectrum 可能放大；正式出片前应预览中段，必要时换种子。
- **ComfyUI 是“魔搭旧版 + git 升级”组合**：基础包为 0.33.1，当前工作树已切到 v0.43.0，依赖已升级并通过启动验证；它不等同于官方 0.43.0 便携包的原生构建。若后续出现版本相关异常，优先用官方 v0.43.0 便携包替换。
- **H3 驱动前置已满足**：560.94 已升级到 621.01（WHQL，2026-10-21 发布），`nvidia-smi` 显示 CUDA 13.5；2026-10-29 19:54 重启后，NVIDIA HDAUDIO 与 AudioEndpoint 均正常，安装收尾完成。详见 `.work-together/driver-upgrade-621.01.md`。
- **Qwen 2.1 是非商业许可**（Qwen Research License），商用需单独授权；20B 路线才是 Apache-2.0。
- **Qwen 包脚本只校验大小**：下载脚本不内置 SHA-256；三份文件的官方哈希已在 `.work-together/qwen-image.verification.md` 记录，2026-10-29 已本地计算并逐项核对一致。
- **H3 全是社区量化/插件**：Kijai 与 starsfriday 的同名文件大小相同但哈希不同，换源必须整文件重下，不能跨源续传。
- **10GB 显存结论**：Qwen 1024×1024 峰值 9,529 MiB，竖版 768×1344 约 9.5 GiB 级；H3 608×352/124 帧峰值 9,622 MiB，608×352/158 帧 9,603 MiB，480×864 峰值 9,735 MiB（横版输入）/9,628 MiB（竖版输入），余量最小约 0.5 GiB。再提高分辨率前必须先实测，不要并行其他 GPU 任务；2048×2048 图片仍未实测。
- 桌面执行器重启会关闭应用窗口（聊天记录保留）；再次启动前记得清理 `ELECTRON_RUN_AS_NODE` 与 `QODER_*` 环境变量。
- 2026-10-29 19:54 重启后桌面桥已断开：Qoder CN 未启动，WorkBuddy AI 已随系统启动但未开调试端口；下一轮派发前需重新启动并确认 19334/19335 监听。

## 9. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-10-29 17:06 | 从 Codex 接管；创建 HANDOFF/SPEC/PLAN/plan.json；系统 Node 升级到 24.22.2 |
| 2026-10-29 17:13 | Qoder CN、WorkBuddy AI 调试桥就绪；两包并行派发 |
| 2026-10-29 17:32 | 两包 `exec_done`；Runner 因主持方编辑 HANDOFF/PLAN 报边界阻断 |
| 2026-10-29 17:39 | 完成独立验收；修正 SPEC 的 Qwen-2.1 过时前提；更新基线；两包转 `verified` |
| 2026-10-29 17:40 | 更新 HANDOFF 与 PLAN，记录最终结果、限制与下一步 |
| 2026-10-29 18:05 | NVIDIA 驱动从 560.94 升级到 621.01（CUDA 13.5）；GPU 已生效，重启完成 HDAUDIO 收尾 |
| 2026-10-29 19:57 | 重启后复验：621.01 / CUDA 13.5，显示与音频设备全部正常；驱动升级完成 |
| 2026-10-29 20:55 | 从魔搭下载并解压 ComfyUI（基础 0.33.1），升级至 v0.43.0；依赖升级；服务、UI 与 Qwen/H3 节点验证通过 |
| 2026-10-29 21:50 | 魔搭下载 Qwen-Image 2.1 三件套（16.10 GiB）并核对 SHA-256；1024×1024 首测 3/3 成功，峰值显存 9,529 MiB |
| 2026-10-29 22:10 | image_edit 模板参考图编辑首测成功：27.1 s，峰值 9,186 MiB，背景替换与文字保留均符合指令 |
| 2026-10-29 22:16 | image_edit 白色文字复跑成功：25.2 s，文字改为白色、清晰可读 |
| 2026-10-29 22:50 | H3 四个权重下载完成（魔搭 2 个 + hf-mirror 2 个，20.11 GiB），SHA-256 4/4 一致；ComfyUI 原生加载器识别通过 |
| 2026-10-29 23:00 | 安装 ComfyUI-ClipProj 0.1.13 与 ComfyUI-Spectrum-MiniMax-H3 0.2.29（gh-proxy），重启 ComfyUI，ClipProjApply 与 SpectrumApplyMiniMaxH3 节点验证通过 |
| 2026-10-29 23:08 | H3 视频首测成功：608×352/124 帧/24fps/20 步，55.2 s，峰值显存 9,201 MiB，输出 5.17 s mp4；解码验证首/中/尾帧画面正确 |
| 2026-10-29 23:17 | H3 三条连跑验收完成（种子 42/43/44）：55.17/50.67/48.44 s，峰值显存 9,201/9,583/9,622 MiB，3/3 可播放、无 OOM、无恶化 |
| 2026-10-29 23:34 | H3 480×864 三条连跑完成：115.17/108.36/108.43 s，峰值显存 9,735/9,731/9,725 MiB，3/3 可播放、无 OOM；速度约为 608×352 的 2.2 倍 |
| 2026-10-29 23:47 | 用户决定敏感数据分析线不做；项目范围收缩为图像/视频生成 |
| 2026-10-29 23:47 | 生成 480×864 竖版首尾帧（Qwen 768×1344 出图与改色）并完成 H3 竖屏三条连跑：126.33/103.93/103.30 s，峰值 9,052/9,564/9,628 MiB，构图与文字完整 |
| 2026-10-29 23:51 | H3 608×352/158 帧三条连跑完成：73.31/66.39/66.27 s，2.23 s/it，峰值 9,430/9,603/9,577 MiB，输出 6.58 s，无 OOM |
| 2026-10-30 03:32 | 汇总 Qoder 部署会话与 ZCode Krea2 会话（不含代码提交部分），新增 `docs/本地AI图像视频工作流-实操手册.md` 与 `docs/公众号推文-10GB显卡本地出图与视频实录.md` |
| 2026-10-30 03:38 | 新增 `docs/本地AI环境部署文档.md`：从零部署 ComfyUI / Qwen-Image 2.1 / Krea2 / H3，含校验、验收、回滚与故障排查 |
| 2026-10-30 03:45 | 三份文档补过程图：新增 `docs/assets/` 9 张对比图（Qwen 首测/改字色/竖版、Krea2 LoRA 对比、H3 首测/长时长/输入裁切/竖屏/种子噪斑），手册引 9 张、推文 8 张、部署文档 4 张 |
| 2026-10-30 03:47 | 补入 2 张 ComfyUI 工作流界面截图（Krea2 固定人设、H3 首尾帧），文档现共引 11 张：手册 11、推文 10、部署文档 6 |
| 2026-10-30 04:05 | 文档站点已发布：`docs-site/`（`node .build/build.mjs` 生成 `dist/`）含首页与三个文档页，Qoder Site `local-ai-workflow-docs` 上线，默认私有；源文档更新后重新构建并以新动作发布 |
| 2026-10-30 04:12 | 表述调整：手册复盘标题与推文开头由“两天”改为“一个晚上”；站点已重新构建并更新上线 |
| 2026-10-30 09:51 | 用 `one-line-wechat-article` 重写公众号推文，标题改为《10GB 显卡，一晚上跑通出图与视频》；Qwen-Image 2.1 本地生成封面 900×383 与分享图 1200×960；逐图素材门禁 10/10 通过；公众号草稿已创建（仅草稿箱，未群发） |
| 2026-10-30 09:52 | 本地推文与文档站文章页同步改写稿并补入封面/分享图（文章页 12 图）；`docs-site` 重建后以新动作发布，站点 `published: true` |
| 2026-10-30 13:10 | 安装 `handraw-style` 技能到 Qoder（`C:\Users\pc\.qoder\skills\handraw-style`，54MB，365 画风/170 图型/36 主题色）；按 FA-012 极简视觉双关社论风 + 普鲁士蓝，用 Qwen-Image 2.1（带风格参考图）生成 4 张手绘插画 |
| 2026-10-30 13:14 | 新增手绘版封面 `pic/20261030/封面-handraw-900x383.png`（153KB）与分享图 `pic/20261030/分享图-handraw-1200x960.png`（1018KB）；原扁平矢量封面/分享图、公众号草稿、文档站均未替换 |
| 2026-10-30 13:26 | 按用户参考图新增冰银蓝宝石三维版：Qwen-Image 2.1 以参考图作纯风格条件（不带 VAE，不复制构图）生成 4 张插画；新增本地模板 `tpl-style2/` 与 `build_style2.py`（冰银/蓝宝石配色），产出封面 `pic/20261030/封面-handraw2-900x383.png`（306KB）与分享图 `pic/20261030/分享图-handraw2-1200x960.png`（1085KB）；原 FA-012 版、扁平版、公众号草稿、文档站均未替换 |
| 2026-10-30 13:41 | 封面改版：用 Qwen-Image 2.1 参考潜变量编辑（带 VAE，种子 20261222）把左侧机械器物替换为参考图中的银白发机械女王，人物居左、右侧留白；新增科技感文字模板 `tpl-style2/cover-tech-900x383.html`（HUD 网格/角标、Bahnschrift 标签、渐变标题），“一晚上”独立成行不与正文重叠；产出 `pic/20261030/封面-女王科技-900x383.png`（402KB）；分享图与其余版本未改 |
| 2026-10-30 13:52 | 分享图女王版：用同一参考图生成 3 张竖版人物卡（捧发光照片 / 牵银色胶片 / 夜窗旁白色显卡，种子 20261231–33），套用冰银蓝宝石 `share-poster` 模板，产出 `pic/20261030/分享图-女王版-1200x960.png`（1124KB）；与女王科技封面成对，其余版本、公众号草稿、文档站均未替换 |
| 2026-10-30 14:02 | 分享图文字改为封面同款 HUD 科技风：新增 `tpl-style2/share-poster-tech-1200x960.html`（HUD 角标/网格、Bahnschrift 标签、渐变标题、VRAM 读数、切角徽章、竖排标签），沿用女王三卡，产出 `pic/20261030/分享图-女王科技-1200x960.png`（1197KB）；柔和文字版与其余版本未改 |
| 2026-10-30 15:45 | 女王科技封面/分享图替换进文档站与公众号：`docs/assets/12-wechat-cover-900x383.png`、`13-wechat-share-1200x960.png` 已换新，`docs-site` 重建后以新动作 `9704d925-5ff8-4909-8641-97d5bb325b48` 发布，`published: true`；公众号新建草稿《10GB 显卡，一晚上跑通出图与视频》（`media_id L2Z3TqUJmME0q5PlEllwARaeBQbVv6Lgy10c5D8Unn-Mzc2VojfMgnIOTH-ANemW`，封面 thumb `...dr5zVXpdL2gXN4qKEfj5nGel5qbJcp2WyYVny3iQnPR`），归档在 `articles/published/queen-20261030/`；旧草稿已不在草稿箱、已发布文章封面无法经 API 修改（`freepublish` 48001），旧文未删除 |
| 2026-10-30 18:24 | 新增公众号文中贴图：以女王参考图生成 3 张横版候选（1344×896，种子 20261241–43），选牵银色胶片版，套用新模板 `tpl-style2/inline-card-1080x720.html`（HUD 网格/角标、渐变标题“出图 → 视频”、STACK/OUTPUT 读数、竖排标签），产出 `pic/20261030/贴图-出图到视频-1080x720.png`（1080×720，807KB）；`build_style2.py` 新增 `inline-card` 子命令；未插入公众号草稿或文档站，待用户决定 |
| 2026-10-30 22:20 | 新增竖版公众号贴图：以女王参考图生成 3 张 896×1344 竖版候选（种子 20261251–53），选牵胶片版，新增模板 `tpl-style2/inline-card-portrait-1080x1440.html`（顶部 HUD 标题“出图 / → 视频”、右下 VRAM 10.0 GB 读数、底部 STACK/OUTPUT/MODE 信息板），产出 `pic/20261030/贴图-竖版-出图到视频-1080x1440.png`（1080×1440，1212KB）及同尺寸 JPG（295KB，可直接上传公众号）；`build_style2.py` 新增 `inline-card-portrait` 子命令；未插入草稿或文档站 |
