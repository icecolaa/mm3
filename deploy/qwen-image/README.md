# Qwen 图像生成 ComfyUI 部署包

> 交付日期：2026-10-29  
> 目标机器：Windows 11 x64 / NVIDIA RTX 3080 10GB / 32GB RAM / 驱动 560.94  
> 交付目录：`deploy/qwen-image/`  
> 交付物：本 README、`manifest.json`、`download-qwen-image.ps1`

---

## 0. 先看结论

**首装推荐：Qwen-Image-2.1 基础版（int8_convrot）。**

- 下载 3 个文件，合计 **16.10 GiB**（17,283,091,112 字节）：7B DiT 6.76 GiB + Qwen3-VL 8B 编码器 8.71 GiB + tiny VAE 0.63 GiB。
- 一个模型同时覆盖**文生图**和**参考图编辑**，不用先二选一。
- ComfyUI 原生支持（最低 v0.38.0），int8 路线**不需要任何自定义节点**。
- 10GB 显存下先跑 **1024×1024**，**不要**直接跑官方 2048；峰值显存估算 9–10GB，属于“能跑但紧”的档位。
- 许可证是 **Qwen Research License（仅非商业）**；商用请看第 4.2 节的 20B Apache-2.0 路线。

**如果必须商用或必须 Apache-2.0：先装 Qwen-Image（20B 文生图）GGUF Q2_K，再装 Qwen-Image-Edit-2509 GGUF Q2_K。**
两者共用同一个 Qwen2.5-VL 编码器和 VAE，先装文生图能把链路跑通，改图只是多换一个 6.66 GiB 的主干文件。

**不要首装**：20B fp8（19.03 GiB）、20B bf16（38.06 GiB）、2.1 bf16（13.25 GiB）、Edit-2509 fp8（19.03 GiB）。这些在 10GB 上只能靠重度卸载，速度慢且容易失败。

---

## 1. 型号澄清：“qwen2.1 image”到底指什么

### 1.1 先纠正写法

“qwen2.1 image”不是官方型号字符串。官方没有叫“Qwen2.1 Image”的独立 SKU；与它对应的是：

**Qwen-Image-2.1**，2026-09-20 发布的开放权重图像生成/编辑模型。[S3][S5]

需要注意：2025 年的旧资料里只有 Qwen-Image（20B），所以早期文档会说“没有 2.1”。**截至 2026-10-29，官方确实已经有 Qwen-Image-2.1**；但它不是“Qwen 2.1 语言模型”的图像插件，而是一个独立的 7B 视觉生成模型，配 Qwen3-VL 8B 文本编码器。[S3][S12]

### 1.2 映射表

| 用户可能说的 | 官方型号 | 发布 | 本地权重 | 本包处理 |
|---|---|---|---|---|
| qwen2.1 image / Qwen2.1 Image | **Qwen-Image-2.1** | 2026-09-20 | 有，7B | 首装推荐，见第 4.1 节 |
| qwen image / 通义千问生图 | **Qwen-Image** | 2025-08-04 | 有，20B | 备选，Apache-2.0，见第 4.2 节 |
| qwen image edit | **Qwen-Image-Edit** | 2025-08-19 | 有，20B | 被 2509 取代；仅作兼容说明 |
| qwen image edit 2509 | **Qwen-Image-Edit-2509** | 2025-09-22 | 有，20B | 备选改图，Apache-2.0 |
| qwen image 3.0 | **Qwen-Image-3.0 / 3.0 Pro** | 2026-07/08 | 仅托管 API | 不适用于本地部署 |
| qwen image 2512 / edit 2511 | **Qwen-Image-2512 / Edit-2511** | 未核实 | 有，20B | 本包未展开，见第 2.3 节 |

“qwen2.1 image”这个写法既可能指 2026 年的 2.1，也可能只是把“Qwen 图像模型”加了个版本号。**本包以官方 2.1 为主推荐，同时完整覆盖 2025 年的 20B 文生图与 Edit-2509**，两种需求都能落地。

---

## 2. 2026-10-29 的系列现状

### 2.1 官方开放权重时间线

| 模型 | 参数 | 许可 | 本地权重 | 关键能力 | 来源 |
|---|---:|---|---|---|---|
| Qwen-Image | 20B | Apache-2.0 | 是 | 文生图，强中文文字渲染 | [S1][S7] |
| Qwen-Image-Edit | 20B | Apache-2.0 | 是 | 参考图编辑，语义+外观 | [S8] |
| Qwen-Image-Edit-2509 | 20B | Apache-2.0 | 是 | 多图编辑（1–3 张最佳）、ControlNet、文字编辑一致性 | [S2] |
| Qwen-Image-2512 | 20B | Apache-2.0 | 是 | 2025-12 迭代；本包未展开 | [S26] |
| Qwen-Image-Edit-2511 | 20B | Apache-2.0 | 是 | 2025-11 迭代；本包未展开 | [S26] |
| **Qwen-Image-2.1** | **7B 视觉主干** | **Qwen Research License（非商业）** | **是** | **文生图+编辑统一、原生 2K、RGBA、最多 10 张参考图** | **[S3][S4][S5]** |
| Qwen-Image-3.0 / 3.0 Pro | 未披露 | API 条款 | 否 | 仅托管 API，不公开权重 | [S13][S9] |

日期说明：Qwen-Image 2025-08-04、Edit 2025-08-19、Edit-2509 2025-09-22、2.1 2026-09-20。[S1][S2][S3][S7][S8]  
2512/2511 的确切发布日期本包未核实；它们存在于 Comfy-Org 仓库并有对应模板。[S26][S22]  
3.0 的“仅 API、不公开权重”来自官方 changelog 与二手资料，**商用/定价请以官方渠道为准**。[S13][S9]

### 2.2 为什么 2.1 是当前最值得先装的开放权重

- 从 20B 降到 **7B 视觉主干**，体积约三分之一，10GB 显卡第一次有了“不用极限量化”的可能。[S3]
- 一个 checkpoint 同时做文生图和编辑，官方模板直接给出 T2I、Edit、背景移除、Turbo 两套工作流。[S12][S22]
- ComfyUI **Day-0 原生支持**；`int8_convrot` 是 Comfy-Org 官方转换格式，不需要 GGUF 节点。[S17][S27]
- 原生 2K、RGBA 透明图、最多 10 张参考图；10GB 上虽然不能跑 2K，但 1024 级别可用。[S3][S12]

### 2.3 本包没有展开的版本

- **Qwen-Image-2512**：Comfy-Org 仓库有 `qwen_image_2512_bf16.safetensors`（38.06 GiB）和 `qwen_image_2512_fp8_e4m3fn.safetensors`（19.03 GiB），ComfyUI 也有模板；本包没有核实其 GGUF 量化与 10GB 表现。[S25][S22]
- **Qwen-Image-Edit-2511**：Comfy-Org 仓库有 bf16（38.06 GiB）、fp8mixed（19.12 GiB）、int8_convrot（19.09 GiB）；同样超出 10GB 舒适区。[S26]
- **Qwen-Image-Edit（原始版）**：已被 2509 取代。若必须复现旧版，原始 fp8 文件是 `qwen_image_edit_fp8_e4m3fn.safetensors`，19.03 GiB，10GB 不可行；本包不提供它的下载项。[S26][S8]
- **Qwen-Image-3.0**：托管 API，不是本地权重，**不要**按本地模型去找下载。[S13][S9]

---

## 3. 10GB / 32GB 的现实评估

### 3.1 本机事实

| 项目 | 事实 |
|---|---|
| GPU | RTX 3080，10240 MiB 专用显存 |
| 内存 | 32GB DDR4-3600（系统识别约 31.9GiB） |
| 系统盘 | C: 剩余约 35.8GiB，**不要**放模型 |
| 数据盘 | D: 剩余约 672GiB，模型放这里 |
| 驱动 | 560.94 |
| ComfyUI | 本包不安装；版本要求见第 7 节 |

以上来自 `SPEC.md` 的本机核查，不是推算。

### 3.2 路线可行性总表

“估算峰值”指 1024×1024、batch 1、单次采样时的专用显存占用，**不是保证值**；实际取决于 attention 实现、驱动、桌面占用和是否启用卸载。

| 路线 | 下载量 | 主干 | 编码器 | 1024 文生图 | 1024 改图 | 结论 |
|---|---:|---:|---:|---|---|---|
| **2.1 int8（推荐）** | 16.10 GiB | 6.76 GiB | 8.71 GiB，顺序加载 | 可跑，峰值约 9–10GB | 可跑，单图先测 | 10GB 最现实 |
| 2.1 Turbo int8 | 16.10 GiB | 6.76 GiB | 同上 | 可跑，8 步更快 | 可跑 | 速度优先 |
| 20B Qwen-Image GGUF Q2_K | 15.55 GiB | 6.58 GiB | 8.74 GiB | 可跑但慢，质量有损 | — | 商用备选 |
| 20B Qwen-Image GGUF Q3_K_M | 18.00 GiB | 9.02 GiB | 8.74 GiB | 很紧，需卸载 | — | 不推荐 |
| 20B Edit-2509 GGUF Q2_K | 15.63 GiB | 6.66 GiB | 8.74 GiB | — | 单图可试，多图易 OOM | 商用备选 |
| 20B Edit-2509 GGUF Q3_K_M | 18.08 GiB | 9.09 GiB | 8.74 GiB | — | 很紧 | 不推荐 |
| 20B fp8 | 19.03 GiB 主干 | 19.03 GiB | 8.74 GiB | 不可行 | 不可行 | 只能重度卸载 |
| 20B bf16 | 38.06 GiB 主干 | 38.06 GiB | 8.74 GiB | 不可行 | 不可行 | 不适用 |
| 2.1 bf16 | 13.25 GiB 主干 | 13.25 GiB | 8.71 GiB | 不可行 | 不可行 | 不适用 |

### 3.3 2.1 在 10GB 上到底怎么跑

- **主干 6.76 GiB** 可以在采样阶段驻留 GPU，剩余约 3GB 给 latents、attention 和 VAE 解码。1024×1024 有希望；2048×2048 的注意力与 latents 开销远超余量，**不要直接试**。
- **编码器 8.71 GiB** 不需要和主干同时常驻。ComfyUI 的顺序加载/动态显存会先编码提示词，再卸载编码器、加载主干；峰值出现在“编码器 + 少量激活”或“主干 + 采样激活”，估算 9–10GB。若你的 ComfyUI 把两者都留在显存里，会 OOM，改用 `--cache-none` 或 `--reserve-vram`（见第 8 节）。
- **32GB 内存**：编码器 8.71 + 主干 6.76 ≈ 15.5GiB 同时在 RAM 里，加上 Python/ComfyUI 2–3GiB、Windows 4–6GiB，约 22–25GiB，能装下但余量不大。开浏览器、IDE、视频会议会明显挤压；建议跑图时关闭大内存应用，并确保 D: 上有系统管理的页面文件。
- **速度**：没有本机实测。25 步 1024×1024 在 3080 上预计“数十秒到数分钟/张”，Turbo 8 步明显更快；**这是估算，不是承诺**。首次运行还要加模型从 D: 加载的时间。
- **VAE**：0.63 GiB，解码 1024 图压力不大；如果 VAE 解码阶段 OOM，换 `VAE Decode (Tiled)`。

### 3.4 20B 系列在 10GB 上的限制

- Q2_K 主干 6.58GiB（文生图）/ 6.66GiB（Edit-2509），能完整驻留，但 Q2 是“能跑”档，文字渲染和纹理细节退化风险最高；**没有实测量化差异**。
- Q3_K_M 主干 9.02/9.09GiB，只剩约 1GB 余量，采样激活一上来就会触发逐层卸载，速度显著下降；不推荐作为日常主力。
- Q4_K_M 12.17GiB，超过 10GB，必然卸载；也不推荐。
- Edit-2509 比文生图多一份输入图 latent，且 2509 的多图能力会放大显存占用；10GB 上先跑**单图 1024**，不要一上来就 3 张参考图。
- 20B 的编码器仍是 8.74GiB，顺序加载逻辑与 2.1 类似；RAM 压力相近。

### 3.5 block swap 与“低显存”是什么关系

ComfyUI 核心在 2026-10-29 的 `cli_args.py` 里**没有**独立的 `--block-swap` 参数；显存不足主要靠 DynamicVRAM、async offload 和 `--lowvram`/`--novram` 处理。[S20]

所谓 block swap（按 transformer block 在 CPU/GPU 之间换入换出）在核心中由动态显存/异步卸载近似实现；第三方节点包也能提供显式 block swap，但本包**不依赖**，也没有在本机核实其对 Qwen 的兼容性。对 2.1 来说，主干 6.76GiB 本来就能进 10GB，**不需要 block swap**；对 20B Q3 来说，block swap 也救不了“9GiB 主干 + 激活”的根本矛盾，直接换 Q2 或 2.1 更实际。

---

## 4. 首装推荐与理由

### 4.1 首选：Qwen-Image-2.1 基础版（int8_convrot）

**装它，不要先装 20B。**

理由：

1. **显存最现实**：7B 主干 6.76GiB，10GB 能容纳主干 + 采样激活；20B 最低也要 Q2 才进得去，Q3 已经要卸载。[S27][S28][S29]
2. **一套覆盖两种需求**：2.1 同时做文生图和参考图编辑，官方模板齐全；20B 需要分别下 Qwen-Image 和 Edit-2509 两个主干。[S3][S12]
3. **零自定义节点**：Comfy-Org 的 `int8_convrot` 是 ComfyUI 原生格式，不需要 GGUF 节点，少一层兼容性风险。[S17][S27]
4. **当前最新开放权重**：3.0 是 API-only；2.1 是 2026-09 最新开放权重。[S13][S3]
5. **后续可扩展**：需要更快时加 Turbo 主干（8 步）；需要换背景/透明图时用官方模板；需要 ControlNet 时有 union 补丁。[S12]

代价与限制：

- **非商业许可**：Qwen Research License，商用必须单独授权。[S4]
- 编码器 8.71GiB，顺序加载虽然能跑，但 32GB 内存余量不大；不要同时开大应用。
- 2K 是模型能力，不是 10GB 的能力；本机先 1024。
- 2.1 的 LoRA/ControlNet 生态比 20B 新，现成资源少一些；本包不包含这些扩展。

### 4.2 商用/必须 Apache-2.0：先 Qwen-Image 文生图，再 Edit-2509

如果你要把产出用于商业项目，或者公司政策不接受研究许可：

1. **先装 Qwen-Image（20B 文生图）GGUF Q2_K**：`-Bundle classic`，15.55 GiB。
2. 跑通文生图后，再装 **Qwen-Image-Edit-2509 Q2_K**：`-Bundle edit2509`，15.63 GiB（编码器/VAE 会跳过，实际只多 6.66GiB）。
3. 两者都是 Apache-2.0，商用许可清晰。[S1][S2]

**为什么先文生图、后改图？**

- 两者共用 Qwen2.5-VL 编码器和 VAE；先跑文生图等于把“编码器 + VAE + 采样器”整条链路验证一遍。
- 文生图只有文本输入；改图还要加载输入图、缩放、额外的 image latent，10GB 下更容易 OOM。
- 先文生图成功，再换一个 6.66GiB 的主干就能改图，排障范围小。

**这条路的代价**：Q2 量化质量有损、20B 比 7B 慢、10GB 下改图只能单图 1024 起步。能接受再选；否则用 2.1 做非商业用途。

### 4.3 如果只能在 20B 里二选一

**先 Qwen-Image（文生图），不要先 Edit-2509。** 理由同上：共用组件、输入更简单、显存压力更小。改图是“文生图链路 + 图像条件”的扩展，不是独立链路。

### 4.4 明确不推荐的首装项

| 项目 | 原因 |
|---|---|
| Qwen-Image fp8 / bf16 | 19.03 / 38.06 GiB 主干，10GB 必须重度卸载 |
| Qwen-Image-Edit-2509 fp8 / bf16 | 19.03 / 38.06 GiB 主干，改图更吃显存 |
| Qwen-Image-2.1 bf16 | 13.25 GiB 主干，超过 10GB |
| Qwen-Image-2.1 PE 提示词增强模型 | 每个 8.82 GiB，默认 `refine_prompt=off`，不是首装必需 |
| Qwen-Image-3.0 | 仅 API，无本地权重 |

---

## 5. 精确文件清单

所有大小以字节为准；GiB = 1024³ 字节。下载 URL 以 `manifest.json` 为准，下面的 URL 与之逐项一致。主下载源是 ModelScope 镜像（本机 2026-10-29 可访问），官方 HF URL 见 `manifest.json` 的 `official_url` 字段。

### 5.1 manifest 内的 8 个文件

| ID | 文件 | 大小 | 目标目录 | 来源 | Bundle |
|---|---|---:|---|---|---|
| qwen21-dit-int8 | `qwen_image_2.1_int8_convrot.safetensors` | 6.76 GiB / 7,256,783,064 B | `models/diffusion_models/` | Comfy-Org（官方转换） | recommended, all |
| qwen21-dit-turbo-int8 | `qwen_image_2.1_turbo_int8_convrot.safetensors` | 6.76 GiB / 7,256,787,829 B | `models/diffusion_models/` | Comfy-Org（官方转换） | turbo, all |
| qwen21-text-encoder-int8 | `qwen3vl_8b_int8_convrot.safetensors` | 8.71 GiB / 9,350,798,360 B | `models/text_encoders/` | Comfy-Org（官方转换） | recommended, turbo, all |
| qwen21-vae | `qwen_image_2.1_vae_bf16.safetensors` | 0.63 GiB / 675,509,688 B | `models/vae/` | Comfy-Org（官方转换） | recommended, turbo, all |
| qwen-image-gguf-q2k | `qwen-image-Q2_K.gguf` | 6.58 GiB / 7,062,518,304 B | `models/diffusion_models/` | city96（社区 GGUF） | classic, all |
| qwen-image-edit-2509-gguf-q2k | `Qwen-Image-Edit-2509-Q2_K.gguf` | 6.66 GiB / 7,147,452,960 B | `models/diffusion_models/` | QuantStack（社区 GGUF） | edit2509, all |
| qwen25vl-text-encoder-fp8 | `qwen_2.5_vl_7b_fp8_scaled.safetensors` | 8.74 GiB / 9,384,670,680 B | `models/text_encoders/` | Comfy-Org（官方转换） | classic, edit2509, all |
| qwen-image-vae | `qwen_image_vae.safetensors` | 0.24 GiB / 253,806,246 B | `models/vae/` | Comfy-Org（官方转换） | classic, edit2509, all |

Bundle 合计：

| Bundle | 文件数 | 下载量 | 需要自定义节点 | 最低 ComfyUI |
|---|---:|---:|---|---|
| recommended | 3 | 16.10 GiB | 否 | 0.38.0 |
| turbo | 3 | 16.10 GiB | 否 | 0.40.0（Turbo 模板） |
| classic | 3 | 15.55 GiB | 是，city96/ComfyUI-GGUF | 0.3.49 |
| edit2509 | 3 | 15.63 GiB | 是，city96/ComfyUI-GGUF | 0.3.60 |
| all | 8 | 45.07 GiB | 是 | 0.40.0 |

### 5.2 下载 URL（与 manifest 一致）

```text
qwen21-dit-int8
https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/diffusion_models/qwen_image_2.1_int8_convrot.safetensors

qwen21-dit-turbo-int8
https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/diffusion_models/qwen_image_2.1_turbo_int8_convrot.safetensors

qwen21-text-encoder-int8
https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/text_encoders/qwen3vl_8b_int8_convrot.safetensors

qwen21-vae
https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/vae/qwen_image_2.1_vae_bf16.safetensors

qwen-image-gguf-q2k
https://modelscope.cn/models/city96/Qwen-Image-gguf/resolve/master/qwen-image-Q2_K.gguf

qwen-image-edit-2509-gguf-q2k
https://modelscope.cn/models/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/master/Qwen-Image-Edit-2509-Q2_K.gguf

qwen25vl-text-encoder-fp8
https://modelscope.cn/models/Comfy-Org/Qwen-Image/resolve/master/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors

qwen-image-vae
https://modelscope.cn/models/Comfy-Org/Qwen-Image/resolve/master/split_files/vae/qwen_image_vae.safetensors
```

官方 HF 对应 URL（仅作来源核对；本机直连 HF 失败，见第 13 节）：

```text
https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors
https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_turbo_int8_convrot.safetensors
https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors
https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors
https://huggingface.co/city96/Qwen-Image-gguf/resolve/main/qwen-image-Q2_K.gguf
https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/main/Qwen-Image-Edit-2509-Q2_K.gguf
https://huggingface.co/Comfy-Org/Qwen-Image/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
https://huggingface.co/Comfy-Org/Qwen-Image/resolve/main/split_files/vae/qwen_image_vae.safetensors
```

### 5.3 不在 manifest 内的可选/替代文件

这些文件**不会被脚本默认下载**；需要时手动下载或自行加入 manifest。

| 文件 | 大小 | 用途 | URL / 仓库 |
|---|---:|---|---|
| `qwen-image-Q3_K_M.gguf` | 9.02 GiB / 9,679,567,392 B | 20B 文生图更高质量档；10GB 需卸载 | https://modelscope.cn/models/city96/Qwen-Image-gguf/resolve/master/qwen-image-Q3_K_M.gguf |
| `qwen-image-Q4_K_M.gguf` | 12.17 GiB / 13,065,746,976 B | 20B 质量档；10GB 不合适 | https://modelscope.cn/models/city96/Qwen-Image-gguf/resolve/master/qwen-image-Q4_K_M.gguf |
| `Qwen-Image-Edit-2509-Q3_K_M.gguf` | 9.09 GiB / 9,764,502,048 B | Edit-2509 更高质量档；10GB 很紧 | https://modelscope.cn/models/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/master/Qwen-Image-Edit-2509-Q3_K_M.gguf |
| `Qwen-Image-Edit-2509-Q4_K_M.gguf` | 12.17 GiB / 13,065,746,976 B | Edit-2509 质量档；10GB 不合适 | https://modelscope.cn/models/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/master/Qwen-Image-Edit-2509-Q4_K_M.gguf |
| `qwen3vl_8b_w4a8.safetensors` | 5.88 GiB / 6,312,105,364 B | 2.1 编码器低内存替代；质量略降 | https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/text_encoders/qwen3vl_8b_w4a8.safetensors |
| `qwen_image_2.1_Q5_K_M.gguf` | 4.56 GiB / 4,892,053,728 B | 2.1 GGUF 低显存替代；需 leejet/ComfyUI-GGUF | https://huggingface.co/AlperKTS/Qwen-Image-2.1-GGUF |
| `qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors` | 8.82 GiB / 9,471,072,252 B | 2.1 提示词增强（文生图），默认关闭 | https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors |
| `qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors` | 8.82 GiB / 9,471,072,252 B | 2.1 提示词增强（编辑），默认关闭 | https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors |
| `qwen_image_2.1_bf16.safetensors` | 13.25 GiB / 14,230,280,616 B | 2.1 全精度；10GB 不可行 | https://modelscope.cn/models/Comfy-Org/Qwen-Image-2.1/resolve/master/diffusion_models/qwen_image_2.1_bf16.safetensors |
| `qwen_image_fp8_e4m3fn.safetensors` | 19.03 GiB / 20,430,635,136 B | 20B 文生图 fp8；10GB 不可行 | https://modelscope.cn/models/Comfy-Org/Qwen-Image/resolve/master/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors |
| `qwen_image_edit_2509_fp8_e4m3fn.safetensors` | 19.03 GiB / 20,430,698,424 B | Edit-2509 fp8；10GB 不可行 | https://modelscope.cn/models/Comfy-Org/Qwen-Image-Edit/resolve/master/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors |
| `qwen_image_edit_fp8_e4m3fn.safetensors` | 19.03 GiB / 20,430,635,136 B | 原始 Edit fp8；被 2509 取代 | https://modelscope.cn/models/Comfy-Org/Qwen-Image-Edit/resolve/master/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors |

说明：

- 20B 的 fp8/bf16 文件来自 Comfy-Org 官方转换仓库，不是 Qwen 官方仓库；许可证仍是 Apache-2.0。[S25][S26]
- GGUF 文件是社区量化，模型许可仍是 Apache-2.0；量化文件本身的完整性由社区仓库负责，本包未提供哈希。[S28][S29]
- 2.1 的 PE 模型是**提示词增强器**，不是图像主干；官方模板默认 `refine_prompt=off`，不下也能跑基础工作流。[S12][S22]
- 2.1 GGUF 需要 leejet 的 ComfyUI-GGUF 分支（其架构表含 `qwen_image21`），不是 city96 主仓库；本包未实测这条路线。[S31][S32]

---

## 6. 目录布局与 ComfyUI 接入

### 6.1 下载后的布局

`-TargetRoot` 默认 `D:\LocalAI\image`，脚本会在其下创建：

```text
D:\LocalAI\image\
├── models\
│   ├── diffusion_models\
│   │   ├── qwen_image_2.1_int8_convrot.safetensors      (recommended)
│   │   ├── qwen_image_2.1_turbo_int8_convrot.safetensors(turbo)
│   │   ├── qwen-image-Q2_K.gguf                          (classic)
│   │   └── Qwen-Image-Edit-2509-Q2_K.gguf                (edit2509)
│   ├── text_encoders\
│   │   ├── qwen3vl_8b_int8_convrot.safetensors           (2.1)
│   │   └── qwen_2.5_vl_7b_fp8_scaled.safetensors         (20B)
│   └── vae\
│       ├── qwen_image_2.1_vae_bf16.safetensors           (2.1)
│       └── qwen_image_vae.safetensors                    (20B)
├── download-qwen-image.ps1
├── manifest.json
└── README.md
```

不要把模型放进 `custom_nodes`；ComfyUI 只从 `models/` 或 `extra_model_paths.yaml` 指向的目录读取。

### 6.2 方式 A：extra_model_paths.yaml（推荐，不复制大文件）

在 ComfyUI Portable 根目录的 `ComfyUI\extra_model_paths.yaml` 中加入（路径按你的实际位置改）：

```yaml
qwen_image:
  base_path: D:/LocalAI/image/
  diffusion_models: models/diffusion_models
  text_encoders: models/text_encoders
  vae: models/vae
```

保存后**完全重启** ComfyUI。重启后在 `Load Diffusion Model`、`Load CLIP`、`Load VAE` 的下拉框里应能看到上述文件名；看不到就是路径或缩进错了。

注意：

- YAML 用空格缩进，不要用 Tab。
- `base_path` 末尾要有 `/`。
- 如果你的 ComfyUI 版本较旧，可能只认 `clip:` 而不是 `text_encoders:`；可同时写 `clip: models/text_encoders`（本机未核实旧版行为）。
- ComfyUI Desktop 的配置入口与 Portable 不同；本包未核实 Desktop 的具体路径，最稳妥是把 `models\*` 复制到 Desktop 的 models 目录。

### 6.3 方式 B：直接复制

把 `D:\LocalAI\image\models\diffusion_models\*`、`text_encoders\*`、`vae\*` 分别复制到 ComfyUI 的对应目录。会多占一份磁盘（16–45GiB），但兼容性最好。

### 6.4 磁盘与路径检查

```powershell
Get-PSDrive D | Select-Object Name,Used,Free
Get-ChildItem -Recurse D:\LocalAI\image\models | Select-Object FullName,Length
```

C: 只剩约 35.8GiB，**不要**把 16GiB 以上的模型放到 C:。

---

## 7. 安装步骤（人工执行，脚本不做）

> 本节是操作说明。`download-qwen-image.ps1` **只下载**，不会安装 ComfyUI、不会 git clone、不会 pip install、不会改驱动。

### 7.1 ComfyUI 最低版本

| 用途 | 最低版本 | 依据 |
|---|---|---|
| Qwen-Image（20B 文生图） | v0.3.49 | v0.3.49 首次加入 Qwen Image 支持 [S14] |
| Qwen-Image-Edit（原始） | v0.3.51 | v0.3.51 加入 Qwen Edit 支持 [S15] |
| Qwen-Image-Edit-2509 | v0.3.60 | v0.3.60 加入 Edit Plus/2509 支持 [S16][S21] |
| Qwen-Image-2.1 基础版 | **v0.38.0** | v0.37.0 初次支持；v0.38.0 加入 tiny VAE 与 RGBA 修复 [S17][S18] |
| Qwen-Image-2.1 Turbo 模板 | **v0.40.0** | Turbo 模板在 v0.40.0 加入 [S19][S13] |

截至 2026-10-29，GitHub Releases 最新为 **v0.43.0**（2026-10-27）。[S24]  
**建议直接更新到最新稳定版**；只要不低于上表要求即可。更新方式按你的 ComfyUI 安装方式操作（Portable 管理器/Desktop 更新），本包不提供更新脚本。

> 版本说明：v0.37.0 是 2.1 的初次支持，但本包用的是 tiny VAE，并要求 RGBA 输入修复，所以**最低写 v0.38.0**，不要用 v0.37.0 省事。

### 7.2 自定义节点

- **2.1 int8 路线：不需要任何自定义节点。** ComfyUI 原生加载 `int8_convrot`。[S17][S27]
- **20B GGUF 路线：需要 city96/ComfyUI-GGUF。**[S30]
- **2.1 GGUF（可选，不在 manifest）：需要 leejet/ComfyUI-GGUF 分支。**[S31]

city96/ComfyUI-GGUF 的人工安装示例（Portable，路径按实际改；脚本不会执行这些命令）：

```powershell
cd D:\LocalAI\ComfyUI_windows_portable\ComfyUI\custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF
cd ..
..\python_embeded\python.exe -s -m pip install -r custom_nodes\ComfyUI-GGUF\requirements.txt
```

安装后重启 ComfyUI，节点菜单里应出现 `Unet Loader (GGUF)`。  
**不要同时保留两个同名的 ComfyUI-GGUF 目录**（例如 city96 和 leejet 各一份），容易节点冲突；选一个。

### 7.3 下载模型

在 `deploy/qwen-image/` 下打开 PowerShell：

```powershell
# 1) 先看计划，不发网络请求
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-qwen-image.ps1 -DryRun

# 2) 首装：2.1 基础版（16.10 GiB）
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-qwen-image.ps1

# 3) 可选：2.1 Turbo（已有编码器/VAE 会跳过）
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-qwen-image.ps1 -Bundle turbo

# 4) 可选：20B 文生图 / Edit-2509
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-qwen-image.ps1 -Bundle classic
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-qwen-image.ps1 -Bundle edit2509

# 5) 换目标盘
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-qwen-image.ps1 -TargetRoot "E:\LocalAI\image"
```

行为：

- 已存在且大小一致的文件：打印 `SKIP`，不重复下载。
- 已存在但大小不一致：打印 `SKIP` 并提示你自己删除；不会覆盖你的文件。
- 下载中断：保留 `.part`，重跑同一命令自动 `curl -C -` 续传。
- 失败：任一文件失败，最终退出码 **1**；全部成功/跳过，退出码 **0**。
- `-DryRun`：只打印计划，**零网络请求**，不创建目录。

### 7.4 校验文件大小

```powershell
$m = Get-Content .\manifest.json -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($f in $m.files) {
  $p = Join-Path "D:\LocalAI\image" $f.target
  if (Test-Path -LiteralPath $p) {
    $len = (Get-Item -LiteralPath $p).Length
    [pscustomobject]@{ File=$f.filename; Expected=$f.size_bytes; Actual=$len; OK=($len -eq [long]$f.size_bytes) }
  } else {
    [pscustomobject]@{ File=$f.filename; Expected=$f.size_bytes; Actual=$null; OK=$false }
  }
}
```

只下载了 recommended 时，classic/edit2509 的文件显示 `OK=False` 是正常的。**`OK=True` 的行必须字节数完全一致。**

---

## 8. 低显存启动参数

### 8.1 先理解 2026 版 ComfyUI 的变化

2026 年的 ComfyUI 默认启用 **DynamicVRAM**。`--lowvram` 的帮助文本明确写着：**如果 DynamicVRAM 开启，`--lowvram` 不做任何事；只有在 DynamicVRAM 关闭时，它才让文本编码器跑在 CPU。**[S20]

所以不要无脑抄 2023–2024 年的 `--lowvram` 教程。对 10GB + 2.1，正确的顺序是：

1. 先用默认 DynamicVRAM + `--reserve-vram`。
2. 如果仍 OOM，再关掉 DynamicVRAM 用传统 `--lowvram`。
3. 最后才是 `--novram`。

### 8.2 推荐命令（Portable）

**基线（先试这个）：**

```powershell
cd D:\LocalAI\ComfyUI_windows_portable
.\python_embeded\python.exe -s ComfyUI\main.py --reserve-vram 1.0
```

说明：`--reserve-vram 1.0` 给 Windows 桌面/浏览器留 1GB 显存，避免 System 抢显存导致 OOM。[S20]

**如果 1024 仍 OOM：**

```powershell
.\python_embeded\python.exe -s ComfyUI\main.py --disable-dynamic-vram --lowvram --reserve-vram 1.0
```

说明：关闭 DynamicVRAM 后，`--lowvram` 才会生效，并把文本编码器放到 CPU；速度会变慢，但显存压力下降。[S20]

**如果还 OOM（最后手段）：**

```powershell
.\python_embeded\python.exe -s ComfyUI\main.py --novram --cache-none
```

说明：`--novram` 是“低显存还不够”时用的；`--cache-none` 降低 RAM/VRAM 缓存，代价是每次执行所有节点、速度更慢。[S20]

**如果 RAM 被吃满/系统卡死：**

```powershell
.\python_embeded\python.exe -s ComfyUI\main.py --cache-none --reserve-vram 1.0
```

并在跑图时关闭浏览器、IDE、视频会议；把页面文件放到 D:（系统属性 → 高级 → 性能 → 虚拟内存），不要让 32GB 内存硬扛。

### 8.3 参数速查

| 参数 | 作用 | 10GB 建议 |
|---|---|---|
| `--reserve-vram N` | 预留 N GB 给系统/其他程序 | 先 1.0；桌面占用高时 1.5 |
| `--vram-headroom N` | DynamicVRAM 额外保持 N GB 空闲 | 与 reserve 二选一，先 reserve |
| `--lowvram` | 关闭 DynamicVRAM 时让文本编码器跑 CPU | 仅配合 `--disable-dynamic-vram` |
| `--novram` | 更激进的低显存模式 | 最后手段 |
| `--cache-none` | 不缓存节点结果，省 RAM/VRAM | RAM 吃紧时用 |
| `--disable-dynamic-vram` | 回到传统估算式加载 | 需要用 `--lowvram` 时加 |
| `--async-offload` | 异步权重卸载，NVIDIA 默认开启 | 不要关 |
| `--highvram` / `--gpu-only` | 尽量把模型留在 GPU | **10GB 不要用** |

### 8.4 驱动与 CUDA

- 本机驱动 560.94。**图像包本身不需要 CUDA 13，也不需要 580 驱动。** 只要你现在能正常启动 ComfyUI，就先别动驱动。
- 如果你把 ComfyUI 更新到使用 CUDA 12.8/13 运行时的构建，560.94 可能报 `CUDA driver version is insufficient for CUDA runtime version`。这时二选一：换回 cu126 构建，或更新到 580 系列驱动。**本机未实测最新构建与 560.94 的组合。**
- 视频包（MiniMax H3）另有 580 驱动要求；那是另一个包的事，不要为了图像包提前升驱动。

### 8.5 关于 block swap

见 3.5 节：核心没有 `--block-swap` 参数；2.1 主干 6.76GiB 能进 10GB，不需要显式 block swap。20B Q3 的瓶颈是主干本身接近 9GiB，换 Q2 或换 2.1 比折腾 block swap 更有效。

---

## 9. 首次测试参数

> 所有参数以 ComfyUI 模板为准；下面是“首发最小风险”配置，不是最高画质配置。采样步数/CFG 来自官方模板与模型卡，见 [S22][S12][S1][S2]。

### 9.1 首选：Qwen-Image-2.1 文生图（第一张图）

| 项目 | 值 |
|---|---|
| 模板 | Workflow → Browse Templates → 搜索 `Qwen-Image 2.1` → `image_qwen_image_2_1_t2i` |
| 分辨率 | **1024 × 1024**（不要 2048） |
| 步数 | 25 |
| CFG | 1.0 |
| Sampler / Scheduler | euler / simple |
| Denoise | 1.0 |
| Batch | 1 |
| Seed | 固定，例如 12345 |
| 提示词增强 | `refine_prompt = off`（默认；PE 模型不下也能跑） |

提示词示例（测中文文字渲染）：

```text
一张极简海报，白色背景，中央黑色中文大字“本地出图”，下方小字“RTX 3080 10GB”，平面设计，高清，边缘干净
```

操作：

1. 加载模板，确认 `Load Diffusion Model` 选 `qwen_image_2.1_int8_convrot.safetensors`。
2. `Load CLIP` 选 `qwen3vl_8b_int8_convrot.safetensors`，type = `qwen_image`。
3. `Load VAE` 选 `qwen_image_2.1_vae_bf16.safetensors`。
4. 点击 Run，记录耗时和显存峰值（见 9.4）。
5. 连续跑 3 次，3/3 成功才算通过。

### 9.2 首选：Qwen-Image-2.1 参考图编辑

| 项目 | 值 |
|---|---|
| 模板 | `image_qwen_image_2_1_image_edit` |
| 输入图 | 1024×1024 左右，先只用 **1 张** |
| 总像素 | 约 1MP（1024×1024） |
| 步数 | 25 |
| CFG | 1.0 |
| Sampler / Scheduler | euler / simple |
| Batch | 1 |
| 提示词增强 | off |

提示词示例：

```text
把背景换成傍晚的城市街道，保留人物姿势和服装不变，光线自然，照片质感
```

先单图跑通，再试 2–3 张参考图。2509 的多图最佳是 1–3 张；2.1 支持最多 10 张，但 10GB 上不要一上来就多图 + 大分辨率。[S2][S3]

### 9.3 可选：2.1 Turbo（8 步）

| 项目 | 值 |
|---|---|
| 模板 | `image_qwen_image_2_1_turbo_t2i` 或 `..._turbo_image_edit` |
| 主干 | `qwen_image_2.1_turbo_int8_convrot.safetensors` |
| 步数 | 8 |
| CFG | 1.0 |
| 分辨率 | 1024 × 1024 |

Turbo 模板需要 ComfyUI v0.40.0+。[S19]

### 9.4 可选：20B Qwen-Image 文生图（GGUF Q2_K）

| 项目 | 值 |
|---|---|
| 模板 | `image_qwen_image` |
| 主干 | 把 `Load Diffusion Model` 换成 `Unet Loader (GGUF)`，选 `qwen-image-Q2_K.gguf` |
| LoRA | 模板自带 8 步 Lightning LoRA；本包没下，**删除/绕过 `LoraLoaderModelOnly` 节点** |
| 步数 | 20–30（无 LoRA）；官方 Diffusers 参考 50 步 [S1] |
| CFG | 2.5–4.0（官方 true_cfg=4.0）[S1] |
| Sampler / Scheduler | euler / simple |
| 分辨率 | 1024 × 1024（模板默认 1328，10GB 先降） |
| CLIP | `qwen_2.5_vl_7b_fp8_scaled.safetensors`，type = `qwen_image` |
| VAE | `qwen_image_vae.safetensors` |

如果你另外下载了 Lightning LoRA，才可以用模板默认的 8 步 / cfg 1.0；否则不要照抄模板的 8 步，会欠采样。

### 9.5 可选：20B Qwen-Image-Edit-2509（GGUF Q2_K）

| 项目 | 值 |
|---|---|
| 模板 | `image_qwen_image_edit_2509` |
| 主干 | `Unet Loader (GGUF)` 选 `Qwen-Image-Edit-2509-Q2_K.gguf` |
| LoRA | 模板自带 4 步 Lightning LoRA；本包没下，删除/绕过 |
| 步数 | 20–40（无 LoRA）；官方参考 40 步 [S2] |
| CFG | 2.5–4.0（官方 true_cfg=4.0）[S2] |
| 输入图 | 1 张，缩放到约 1MP（模板有 Scale Image to Total Pixels） |
| 分辨率 | 1024 × 1024 级别 |

模板默认的 4 步是给 Lightning LoRA 的，删了 LoRA 还用 4 步会明显欠采样。

### 9.6 记录耗时与显存

另开一个 PowerShell 窗口：

```powershell
nvidia-smi --query-gpu=memory.used,memory.total --format=csv -l 2
```

或者跑完后看：

```powershell
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

记录“专用显存峰值”。如果任务管理器显示“共享 GPU 内存”大幅上涨，说明已经溢出到系统内存，速度会骤降；这不算“10GB 跑通”。

---

## 10. 验收清单

### 10.1 文件与版本

- [ ] `manifest.json` 可被 JSON 解析，8 个文件项字段齐全。
- [ ] 首装 3 个文件存在，字节数与 manifest 完全一致（用 7.4 的脚本）。
- [ ] ComfyUI 版本 ≥ 0.38.0；如果用 Turbo 模板，≥ 0.40.0。
- [ ] 2.1 int8 路线没有安装任何额外自定义节点。
- [ ] 如果走 GGUF，`Unet Loader (GGUF)` 节点存在，且只有一个 ComfyUI-GGUF 目录。

### 10.2 2.1 文生图

- [ ] 模板 `image_qwen_image_2_1_t2i` 能加载，无“节点缺失”弹窗。
- [ ] 1024×1024、25 步、cfg 1、euler/simple 连续跑 **3 次**，3/3 成功。
- [ ] 每次输出图片能正常打开，不是黑图/纯噪声。
- [ ] 专用显存峰值 < 10240 MiB；没有明显共享内存溢出。
- [ ] 记录 3 次的耗时（秒/张）。
- [ ] 系统没有卡死/强制重启；ComfyUI 控制台无红色报错。

### 10.3 2.1 改图

- [ ] 模板 `image_qwen_image_2_1_image_edit` 能加载。
- [ ] 单张 1024 输入图能完成编辑，输出保留主体、按提示修改。
- [ ] 再试 2 张参考图；如果 OOM，记录为“10GB 限制”，不算失败。
- [ ] 记录显存峰值与耗时。

### 10.4 可选：20B 路线

- [ ] Qwen-Image Q2_K 文生图 1024 成功至少 1 次。
- [ ] Edit-2509 Q2_K 单图编辑成功至少 1 次。
- [ ] 记录质量是否符合预期（Q2 的文字/纹理退化是否可接受）。
- [ ] 如果 Q3_K_M 要试，先确认能在 10GB 下稳定；否则不要作为日常配置。

### 10.5 记录表

| 日期 | 模型 | 任务 | 分辨率 | 步数 | 耗时 | 专用显存峰值 | 结果 | 备注 |
|---|---|---|---|---:|---:|---:|---|---|
|  | 2.1 int8 | T2I #1 | 1024² | 25 |  |  |  |  |
|  | 2.1 int8 | T2I #2 | 1024² | 25 |  |  |  |  |
|  | 2.1 int8 | T2I #3 | 1024² | 25 |  |  |  |  |
|  | 2.1 int8 | Edit 1 图 | 1024² | 25 |  |  |  |  |
|  | 2.1 Turbo | T2I | 1024² | 8 |  |  |  |  |
|  | Qwen-Image Q2_K | T2I | 1024² | 20–30 |  |  |  |  |
|  | Edit-2509 Q2_K | Edit 1 图 | 1024² | 20–40 |  |  |  |  |

**通过标准**：首装 3 个文件大小正确；2.1 T2I 连续 3/3；2.1 Edit 单图 1/1；显存不溢出共享内存；无未解决的红字报错。达不到就按第 11 节排查，不要用“能出一张图”代替验收。

---

## 11. 常见错误与排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `Unet Loader (GGUF)` 节点找不到 | 没装 city96/ComfyUI-GGUF，或节点加载失败 | 按 7.2 安装并重启；看启动日志红字 |
| `Unknown model architecture!` | GGUF 节点太旧，不认识 Qwen 架构 | 20B：更新 city96 节点；2.1 GGUF：换 leejet 分支（架构表含 `qwen_image21`）[S31]；最稳是改用 2.1 int8 |
| `Value not in list: clip_name ... pe_t2i...` | 模板引用了 PE 提示词增强模型，但你没下 | 把 `refine_prompt` 设为 off，或右键 PE 的 `Load CLIP`/`TextGenerate` 设为 Bypass；要增强就下 8.82GiB 的 PE 文件 |
| 加载 CLIP 报类型/维度错误 | `CLIPLoader` 的 type 选错 | Qwen-Image/Edit-2509/2.1 主编码器都选 `qwen_image`；PE 按模板（t2i 为 `stable_diffusion`，i2i 为 `qwen_image`） |
| 出图是黑图/纯噪声 | 编码器、VAE、主干代际混用 | 2.1 用 `qwen3vl_8b_int8_convrot` + `qwen_image_2.1_vae_bf16`；20B 用 `qwen_2.5_vl_7b_fp8_scaled` + `qwen_image_vae`；不要交叉 |
| `mat1 and mat2 shapes cannot be multiplied` / `size mismatch` | 文件下错、残缺，或 2.1/20B 组件混用 | 用 7.4 校验字节数；清理错误文件重下；核对代际 |
| `CUDA out of memory`（1024 T2I） | 显存被桌面/缓存占用，或编码器与主干同时驻留 | 关浏览器/游戏；加 `--reserve-vram 1.0`；再不行 `--disable-dynamic-vram --lowvram`；最后 `--novram` |
| `CUDA out of memory`（VAE 解码） | 解码阶段峰值高 | 降分辨率；用 `VAE Decode (Tiled)`；关其他 GPU 程序 |
| 2048×2048 直接 OOM | 10GB 不适合 2K | 2.1 原生 2K 是能力上限，不是 10GB 的可用档位；先 1024 |
| 系统卡死/内存耗尽 | 32GB 被编码器+主干+浏览器吃满 | `--cache-none`；关大应用；页面文件放 D:；不要同时开 PE 和主模型 |
| 很慢，像在磨 | 首次从 D: 加载；或显存溢出到共享内存 | 第二次会快；检查 `nvidia-smi` 专用显存是否接近 10GB；把 D:\LocalAI 加入杀毒白名单 |
| `CUDA driver version is insufficient...` | ComfyUI 构建的 CUDA 运行时高于 560.94 支持 | 换 cu126 构建，或升级 580+ 驱动；图像包本身不要求 CUDA 13 |
| `No module named 'gguf'` | 装了 GGUF 节点但没装依赖 | 在 ComfyUI 的 python 环境执行该节点的 `requirements.txt`（人工，脚本不做） |
| 更新后 `Cannot import name ...` | 自定义节点与 ComfyUI 版本不匹配 | 更新/暂时移除该节点；确认只有一个 ComfyUI-GGUF |
| 模板里没有 Qwen-Image 2.1 | ComfyUI 太旧 | 升到 v0.38.0+；Turbo 模板要 v0.40.0+ |
| Turbo 模板找不到 | 同上 | 升到 v0.40.0+ |
| 2.1 输入 RGBA 图崩溃 | v0.38.0 修复了 Qwen VL 四通道预处理 | 升到 v0.38.0+ |
| `--lowvram` 看起来没效果 | 2026 版默认 DynamicVRAM 开启，`--lowvram` 被忽略 | 加 `--disable-dynamic-vram` 再用 `--lowvram`，或改用 `--reserve-vram` |
| 下载 404 | URL/仓库路径错，或镜像未同步 | 用 manifest 的 URL；换 `alt_urls` 的 hf-mirror；核对仓库名（`Comfy-Org/Qwen-Image` 不是 `..._ComfyUI`） |
| `curl: (33) ... byte ranges` | 服务器不支持断点续传，或 `.part` 损坏 | 删除 `.part` 重跑；或删目标文件重下 |
| 下载完成但大小不对 | 镜像返回了错误页/截断 | 脚本会报 `Size mismatch` 并保留 `.part`；删除后换镜像重下 |
| 文件存在但脚本跳过，ComfyUI 仍报错 | 旧文件/错文件同名 | 对比字节数；删除错误文件后重跑；脚本不会覆盖已有文件 |
| ComfyUI 下拉框看不到模型 | `extra_model_paths.yaml` 路径/缩进错，或没重启 | 检查 `base_path` 末尾 `/`、空格缩进；完全重启；或直接复制到 models |
| 20B Q2 出图文字糊/细节差 | Q2 量化的预期损失 | 换 2.1（非商业）或 Q3_K_M（需卸载、更慢）；不要期待 Q2 有 fp8 质量 |

---

## 12. 未核实项与已知风险

### 12.1 未核实项

1. **没有在本机实际下载、安装或运行**（任务约束）。所有耗时、显存峰值、速度都是估算，不是实测。
2. **Hugging Face 直连不可达**：本机 `curl` 连接 huggingface.co 返回 28（超时）。官方 HF URL 未直接 HEAD 核验；文件路径与大小通过 hf-mirror API 与 ModelScope API 交叉核对。
3. **ComfyUI v0.43.0 未实测**；最低版本来自 GitHub release notes 与文档，不代表每个小版本都无回归。
4. **驱动 560.94 与最新 ComfyUI 构建的组合未实测**；可能遇到 CUDA 运行时版本不匹配。
5. **2.1 GGUF（AlperKTS + leejet 分支）未实测**；只核对了仓库文件与代码架构表。
6. **Qwen-Image-2512 / Edit-2511 未展开**；其 GGUF 可用性、10GB 表现未核实。
7. **Qwen-Image-3.0 的 API-only 结论**来自官方 changelog 与二手资料；本包不涉及，商用/定价以官方为准。
8. **许可证摘要不是法律意见**；商用前请阅读完整 LICENSE 并咨询法务。
9. **ModelScope 的 HEAD 不返回 Content-Length**；大小来自 ModelScope API / HF API，不是 HEAD。
10. **未提供文件哈希**；如需完整性校验，请从仓库页面获取 SHA256 自行比对。
11. **多图编辑在 10GB 上的表现未实测**；可能 OOM 或极慢。
12. **ComfyUI Desktop 的 extra_model_paths 配置路径未核实**；本包以 Portable 为例。

### 12.2 已知风险

- **2.1 是非商业许可**：Qwen Research License，商用必须单独授权。[S4]
- **20B Q2 质量有损**：文字渲染是 Qwen-Image 的强项，Q2 会削弱它；这是 10GB 的硬约束。
- **10GB 是临界值**：专用显存一旦溢出到共享内存，速度会断崖式下降；不要用“能出图”判断成功。
- **32GB 内存不宽裕**：2.1 编码器 + 主干同时在 RAM 约 15.5GiB，开大应用会挤压；PE 模型再加 8.82GiB 很可能触发页面文件。
- **镜像可用性**：ModelScope/hf-mirror 是第三方/镜像服务，URL 可能变化；manifest 保留官方 HF URL 作对照。
- **自定义节点供应链**：GGUF 节点需要 git clone + pip；请自行审查仓库，本包脚本不执行这些操作。
- **量化文件完整性**：社区 GGUF 由第三方转换，本包只核对大小，不证明内容无误。

---

## 13. 链接核验记录（2026-10-29）

### 13.1 主下载链接

对 manifest 中 8 个 ModelScope URL 执行 `curl.exe -I -L`（只发 HEAD，不下载正文）：

| 文件 | HTTP 状态 |
|---|---|
| qwen_image_2.1_int8_convrot.safetensors | 200 |
| qwen_image_2.1_turbo_int8_convrot.safetensors | 200 |
| qwen3vl_8b_int8_convrot.safetensors | 200 |
| qwen_image_2.1_vae_bf16.safetensors | 200 |
| qwen-image-Q2_K.gguf | 200 |
| Qwen-Image-Edit-2509-Q2_K.gguf | 200 |
| qwen_2.5_vl_7b_fp8_scaled.safetensors | 200 |
| qwen_image_vae.safetensors | 200 |

ModelScope 的 HEAD 响应不带 `Content-Length`，因此大小以 ModelScope 文件 API 的 `Size` 字段为准；8 个文件的大小与 hf-mirror/HF API 的 `siblings.size` 一致。

### 13.2 官方 HF 链接

- 本机直连 `huggingface.co` 失败：`curl: (28) Failed to connect ... port 443`（2026-10-29）。
- 通过 `hf-mirror.com` 读取同路径元数据成功；对 `qwen_image_fp8_e4m3fn.safetensors` 做 HEAD，返回 `200` 且 `Content-Length: 20430635136`，与 API 的 20,430,635,136 字节一致。
- 因此：**官方 HF URL 的“仓库路径 + 文件大小”已交叉核验；“官方 CDN 当前可下载性”未直接核验。**

### 13.3 版本与文档

- ComfyUI release notes：v0.3.49（2025-08-05）、v0.3.51（2025-08-20）、v0.3.60（2025-09-23）、v0.37.0（2026-09-21）、v0.38.0（2026-09-29）、v0.40.0（2026-10-13）均通过 GitHub API 读取。[S14]–[S19]
- 最新 release：v0.43.0（2026-10-27），GitHub API 读取。[S24]
- ComfyUI 文档模板设置：直接读取 `Comfy-Org/workflow_templates` 的 JSON（`image_qwen_image.json`、`image_qwen_image_edit_2509.json`、`image_qwen_image_2_1_t2i.json`、`image_qwen_image_2_1_image_edit.json`），确认 CLIP type、步数、CFG、分辨率。[S22]
- 模型卡规格与许可证：Qwen-Image、Edit-2509、2.1 的 HF README 与 LICENSE 通过 hf-mirror 读取。[S1][S2][S3][S4]

---

## 14. 来源与访问日期

访问日期均为 **2026-10-29**。官方/社区分开标注。

### 14.1 官方来源（Qwen / ComfyUI / Comfy-Org）

| ID | 来源 | URL |
|---|---|---|
| S1 | Qwen-Image 模型卡（Apache-2.0，20B） | https://huggingface.co/Qwen/Qwen-Image |
| S2 | Qwen-Image-Edit-2509 模型卡（Apache-2.0，多图/ControlNet） | https://huggingface.co/Qwen/Qwen-Image-Edit-2509 |
| S3 | Qwen-Image-2.1 模型卡（7B，RGBA，2K，10 参考图） | https://huggingface.co/Qwen/Qwen-Image-2.1 |
| S4 | Qwen-Image-2.1 LICENSE（Qwen Research License，非商业） | https://huggingface.co/Qwen/Qwen-Image-2.1/blob/main/LICENSE |
| S5 | QwenLM/Qwen-Image-2.1 GitHub | https://github.com/QwenLM/Qwen-Image-2.1 |
| S6 | QwenLM/Qwen-Image GitHub | https://github.com/QwenLM/Qwen-Image |
| S7 | Qwen 官方博客：Qwen-Image（2025-08-04） | https://qwenlm.github.io/blog/qwen-image/ |
| S8 | Qwen 官方博客：Qwen-Image-Edit（2025-08-19） | https://qwenlm.github.io/blog/qwen-image-edit/ |
| S9 | Qwen-Image-2.1 vs 3.0 二手对比（3.0 为 API-only，标注为二手） | https://apifox.com/apiskills/qwen-image-2-1/ |
| S10 | ComfyUI 文档：Qwen-Image 原生工作流 | https://docs.comfy.org/zh/tutorials/image/qwen/qwen-image |
| S11 | ComfyUI 文档：Qwen-Image-Edit 原生工作流 | https://docs.comfy.org/zh/tutorials/image/qwen/qwen-image-edit |
| S12 | ComfyUI 文档：Qwen-Image-2.1 原生工作流 | https://docs.comfy.org/zh/tutorials/image/qwen/qwen-image-2-1 |
| S13 | ComfyUI Changelog（含 Qwen 2.1 / 3.0 条目） | https://docs.comfy.org/changelog |
| S14 | ComfyUI v0.3.49 release（Qwen Image 初次支持） | https://github.com/comfyanonymous/ComfyUI/releases/tag/v0.3.49 |
| S15 | ComfyUI v0.3.51 release（Qwen Edit 支持） | https://github.com/comfyanonymous/ComfyUI/releases/tag/v0.3.51 |
| S16 | ComfyUI v0.3.60 release（Edit-2509 / Edit Plus） | https://github.com/comfyanonymous/ComfyUI/releases/tag/v0.3.60 |
| S17 | ComfyUI v0.37.0 release（Qwen-Image 2.1 支持） | https://github.com/comfyanonymous/ComfyUI/releases/tag/v0.37.0 |
| S18 | ComfyUI v0.38.0 release（tiny VAE / RGBA 修复） | https://github.com/comfyanonymous/ComfyUI/releases/tag/v0.38.0 |
| S19 | ComfyUI v0.40.0 release（2.1 Turbo 模板） | https://github.com/comfyanonymous/ComfyUI/releases/tag/v0.40.0 |
| S20 | ComfyUI CLI 参数源码（lowvram / reserve-vram / dynamic vram） | https://github.com/comfyanonymous/ComfyUI/blob/master/comfy/cli_args.py |
| S21 | ComfyUI 博客：WAN2.2 Animate & Edit-2509 原生支持（v0.3.60） | https://blog.comfy.org/p/wan22-animate-and-qwen-image-edit-2509 |
| S22 | ComfyUI 官方工作流模板仓库 | https://github.com/Comfy-Org/workflow_templates/tree/main/templates |
| S23 | ComfyUI_examples：Qwen Image | https://comfyanonymous.github.io/ComfyUI_examples/qwen_image/ |
| S24 | ComfyUI Releases（最新 v0.43.0，2026-10-27） | https://github.com/comfyanonymous/ComfyUI/releases/latest |
| S25 | Comfy-Org/Qwen-Image 转换仓库（20B fp8/bf16、编码器、VAE） | https://huggingface.co/Comfy-Org/Qwen-Image |
| S26 | Comfy-Org/Qwen-Image-Edit 转换仓库（Edit / 2509 / 2511） | https://huggingface.co/Comfy-Org/Qwen-Image-Edit |
| S27 | Comfy-Org/Qwen-Image-2.1 转换仓库（int8/turbo/VAE/PE） | https://huggingface.co/Comfy-Org/Qwen-Image-2.1 |

### 14.2 社区来源

| ID | 来源 | URL |
|---|---|---|
| S28 | city96/Qwen-Image-gguf（20B 文生图 GGUF，含 Q2/Q3/Q4） | https://huggingface.co/city96/Qwen-Image-gguf |
| S29 | QuantStack/Qwen-Image-Edit-2509-GGUF（Edit-2509 GGUF） | https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF |
| S30 | city96/ComfyUI-GGUF（GGUF 节点，支持 qwen_image 架构） | https://github.com/city96/ComfyUI-GGUF |
| S31 | leejet/ComfyUI-GGUF（分支，架构表含 qwen_image21） | https://github.com/leejet/ComfyUI-GGUF |
| S32 | AlperKTS/Qwen-Image-2.1-GGUF（2.1 GGUF Q5/Q6/Q8） | https://huggingface.co/AlperKTS/Qwen-Image-2.1-GGUF |
| S33 | Nunchaku ComfyUI（可选 4-bit 路线，本包未采用） | https://github.com/nunchaku-ai/ComfyUI-nunchaku |
| S34 | ModelScope（本包主下载镜像） | https://modelscope.cn |
| S35 | hf-mirror（社区 HF 镜像，用于交叉核验） | https://hf-mirror.com |

### 14.3 引用说明

- 官方结论优先引用 Qwen 模型卡/官方仓库/ComfyUI 文档与 release notes。
- 社区仓库只用于“量化文件作者、文件名、大小、节点兼容性”这类事实；量化质量与速度属于社区经验，本包不把它们写成本机保证。
- 二手来源 [S9] 只用于说明 3.0 为 API-only，且已在正文标注“以官方渠道为准”。
- 所有“估算”“未核实”“不保证”均已在对应段落显式标注。

---

## 附录 A：manifest.json 字段

| 字段 | 含义 |
|---|---|
| `schema_version` | 清单结构版本，当前为 1 |
| `package` | 包 ID，`qwen-image` |
| `target_root_default` | 默认下载根目录 `D:\LocalAI\image` |
| `default_bundle` | 默认 bundle，`recommended` |
| `bundles` | bundle 元数据：文件数、下载字节、是否需自定义节点、最低 ComfyUI |
| `files[].id` | 稳定 ID，便于脚本/人工引用 |
| `files[].filename` | 精确文件名 |
| `files[].role` | `diffusion_model` / `text_encoder` / `vae` |
| `files[].architecture` | 所属代际 |
| `files[].source_type` | `official-comfyorg` 或 `community-quant` |
| `files[].repository` | 来源仓库 |
| `files[].quantization` | 量化格式 |
| `files[].license` | 许可证摘要 |
| `files[].url` | 主下载 URL（ModelScope） |
| `files[].official_url` | 官方 HF URL（来源核对） |
| `files[].alt_urls` | 备用镜像 URL |
| `files[].target` | 相对 `TargetRoot` 的目标路径 |
| `files[].size_bytes` | 精确字节数（脚本用它校验） |
| `files[].size_gib` | 便于阅读的 GiB |
| `files[].bundles` | 该文件属于哪些 bundle |
| `files[].required_for` | 该文件的用途 |
| `files[].notes` | 使用注意 |

## 附录 B：下载脚本行为与退出码

| 场景 | 行为 | 退出码 |
|---|---|---|
| `-DryRun` | 打印 bundle、文件、目标路径、URL、总大小；不发网络请求、不建目录 | 0 |
| 文件已存在且大小一致 | 打印 `SKIP`，不下载 | 0（全部如此时） |
| 文件已存在但大小不一致 | 打印 `SKIP` + 提示手动删除；不覆盖 | 0（全部如此时） |
| `.part` 大小已等于目标 | 直接改名恢复，不重新下载 | 0 |
| `.part` 未完成 | `curl -C -` 续传 | 成功 0 |
| 任一文件下载失败 | 保留 `.part`，继续处理其他文件，最终报错 | 1 |
| 下载后大小不符 | 保留 `.part`，报错 | 1 |
| 找不到 `manifest.json` | 报错 | 1 |
| 找不到 `curl.exe` | 报错 | 1 |
| `-Bundle` 值非法 | PowerShell 参数校验报错 | 1 |

脚本只做下载：不安装、不解压、不更新驱动、不执行 `pip`/`git`、不运行 ComfyUI。

---

*本包为“可执行部署文档 + 只下载脚本”，没有在本机实际下载或运行模型。首次实测后，请把第 10.5 节的记录补上，再决定是否把 2.1 作为日常主力、是否需要 Turbo 或 20B 备选。*
