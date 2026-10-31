// Krea2 Turbo 本地出图脚本（ComfyUI API 版）
// 用法: node krea2-generate.mjs <nolora|lora> [seed] [输出文件名]
// 参数来自 ComfyUI 官方 image_krea2_turbo_t2i 模板: 8步 / cfg1 / euler / simple
import { writeFileSync, mkdirSync } from "node:fs";

const BASE = "http://127.0.0.1:8188";
const OUT_DIR = "E:/mm3/krea2-out";
const PROMPT_A = "【画面风格】全画幅写实摄影，50mm定焦，f/2.8，光圈优先，精准单点对焦锁定面部，科幻冷调柔光，极致锐利清晰，体积光，柔焦虚化，环境光遮蔽。【核心元素】固定人物模板：东亚女性鹅蛋脸白皙，银白色短发，蓝眼睛，红润嘴唇，精致妆容，机械姬；白色机械装甲，金属质感，镶嵌蓝宝石，颈部与手臂露出机械结构，白色薄纱披肩，银色华丽头冠镶蓝宝石齿轮，服装与配饰物理空间绑定不可分离；本段白色科幻空间柔和侧光。【具体内容】人物身体微侧，双手交叠胸前，低头看胸前蓝宝石，视线向下，表情沉静；前景虚化机械零件，中景白色空间，背景柔光光斑；顶侧柔光，环境光遮蔽，阴影过渡柔和，50mm透视自然，人物与空间关系真实。【构图方式】半身（medium shot），微俯正面偏侧，对角线构图，人物居中偏左，右侧留白。";

const mode = process.argv[2] ?? "nolora";
const seed = Number(process.argv[3] ?? 42);
const outFile = process.argv[4] ?? `krea2_${mode}_${seed}`;

function graph(useLora) {
  const g = {
    "1": { class_type: "UNETLoader", inputs: { unet_name: "krea2_turbo_fp8_scaled.safetensors", weight_dtype: "default" } },
    "2": { class_type: "CLIPLoader", inputs: { clip_name: "qwen3vl_4b_fp8_scaled.safetensors", type: "krea2", device: "default" } },
    "3": { class_type: "VAELoader", inputs: { vae_name: "qwen_image_vae.safetensors" } },
    "4": { class_type: "CLIPTextEncode", inputs: { text: PROMPT_A, clip: ["2", 0] } },
    "5": { class_type: "ConditioningZeroOut", inputs: { conditioning: ["4", 0] } },
    "6": { class_type: "EmptyLatentImage", inputs: { width: 832, height: 1216, batch_size: 1 } },
    "7": { class_type: "KSampler", inputs: {
      seed, steps: 8, cfg: 1, sampler_name: "euler", scheduler: "simple", denoise: 1,
      model: useLora ? ["20", 0] : ["1", 0], positive: ["4", 0], negative: ["5", 0], latent_image: ["6", 0] } },
    "8": { class_type: "VAEDecode", inputs: { samples: ["7", 0], vae: ["3", 0] } },
    "9": { class_type: "SaveImage", inputs: { images: ["8", 0], filename_prefix: outFile } },
  };
  if (useLora) g["20"] = { class_type: "LoraLoaderModelOnly", inputs: {
    lora_name: "krea2-Cc-Ins风-人像.safetensors", strength_model: 0.8, model: ["1", 0] } };
  return g;
}

const t0 = Date.now();
const res = await fetch(`${BASE}/prompt`, {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ prompt: graph(mode === "lora"), client_id: "zcode" }),
});
const sub = await res.json();
if (sub.error || Object.keys(sub.node_errors ?? {}).length) { console.log("提交失败:", JSON.stringify(sub)); process.exit(1); }
const id = sub.prompt_id;
console.log(`已提交 ${id}，模式=${mode} seed=${seed}，等待生成...`);

let out = null;
for (let i = 0; i < 200; i++) {
  await new Promise(r => setTimeout(r, 3000));
  const h = await (await fetch(`${BASE}/history/${id}`)).json();
  const e = h[id];
  if (!e) { if (i % 10 === 0) console.log(`  ${(Date.now()-t0)/1000|0}s 执行中...`); continue; }
  if (e.status?.status_str === "error") {
    console.log("执行出错:", JSON.stringify(e.status?.messages ?? e.status).slice(0, 800));
    process.exit(1);
  }
  out = e.outputs; break;
}
if (!out) { console.log("超时未完成"); process.exit(1); }

const img = Object.values(out).flatMap(o => o.images ?? [])[0];
if (!img) { console.log("无图片输出:", JSON.stringify(out).slice(0, 400)); process.exit(1); }
const buf = Buffer.from(await (await fetch(
  `${BASE}/view?filename=${encodeURIComponent(img.filename)}&subfolder=${encodeURIComponent(img.subfolder ?? "")}&type=${img.type}`
)).arrayBuffer());
mkdirSync(OUT_DIR, { recursive: true });
const dest = `${OUT_DIR}/${outFile}.png`;
writeFileSync(dest, buf);
console.log(`完成，用时 ${((Date.now()-t0)/1000)|0}s → ${dest}`);
