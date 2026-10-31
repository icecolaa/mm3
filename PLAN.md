# PLAN — 本轮协作计划

日期：2026-10-29
主持：Qoder 会话（工具内 `coordinator=codex`，原因见 HANDOFF.md）
执行器：Qoder CN（图像包）、WorkBuddy AI（视频包）
并发：2
模式：work-together workflow 模式（本地，无 Gitee）

## 任务表

| 包 ID | 任务 | 执行器 | 归属文件 | 依赖 | 状态 |
|---|---|---|---|---|---|
| `qwen-image` | Qwen-Image / Qwen-Image-Edit 部署包 | Qoder CN | `deploy/qwen-image/**` | 无 | `verified` |
| `minimax-h3` | MiniMax H3 视频部署包 | WorkBuddy AI | `deploy/minimax-h3/**` | 无 | `verified` |

## 文件归属

- 主持方（Qoder）独占：`HANDOFF.md`、`SPEC.md`、`PLAN.md`、`plan.json`、`README.md`、`outputs/**`、`.work-together/**`。
- Qoder CN 独占：`deploy/qwen-image/**`。
- WorkBuddy AI 独占：`deploy/minimax-h3/**`。
- 两边都不得修改对方目录和主持方文件；本轮不涉及构建输出与依赖安装。

## 执行命令

技能目录：`C:\Users\pc\.codex\skills\work-together`
Runner：`C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs`
Node：系统默认已升级到 v24.22.2（满足技能要求）。

```powershell
# 桌面预检（单项）
node "C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs" doctor qoder-cn
node "C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs" doctor workbuddy-cn

# 后台调度（在 E:\mm3 运行）
New-Item -ItemType Directory -Force .work-together | Out-Null
Start-Process node -ArgumentList @("C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs","run","plan.json") -WorkingDirectory "E:\mm3" -WindowStyle Hidden -RedirectStandardOutput ".work-together\runner.out.log" -RedirectStandardError ".work-together\runner.err.log"

# 状态
node "C:\Users\pc\.codex\skills\work-together\scripts\workflow.mjs" status
```

## 检查点

- [x] Qoder CN 桌面桥就绪，且有明确免费的 DeepSeek 模型（DeepSeek-Flash）
- [x] WorkBuddy AI 桌面桥就绪，且有明确免费的支持工具调用模型（deepseek-v4.1-flash）
- [x] `qwen-image` 派发成功，桌面会话可见，正文出现任务包标记
- [x] `minimax-h3` 派发成功，桌面会话可见，正文出现任务包标记
- [x] 两包均进入 `exec_done`
- [x] 逐项核对 SPEC 验收条件，链接抽查通过
- [x] 文件指纹检测无越界（主持方对 HANDOFF/PLAN/SPEC 的编辑已登记并更新基线）
- [x] `verify` 登记证据，状态转 `verified`
- [x] 更新 HANDOFF.md（本轮无根目录 README，未新建）

## 注意

- 不启动、不重启 Qoder 国际版（当前主持会话所在应用）。
- 若某包失败或 `unknown`，先查原会话，不自动重派。
- 本轮不实际下载模型、不安装软件；脚本只做语法检查和 `-DryRun`。
