#!/usr/bin/env node
// Эффекты из pixelfx (https://github.com/patch-gg/pixelfx, MIT) -> assets/fx: листы PNG и fx.json.
//
//   node tools/export_fx.mjs <папка pixelfx> [эффект ...]
//
// pixelfx в проект не входит: клонируйте его куда угодно и передайте путь. Каждый эффект
// перекрашивается под палитру игры (Pal) и выгружается в двух масштабах: x2 — пиксели
// эффекта вдвое крупнее (как графика Pyxel-версии), x1 — пиксель в пиксель с холстом героя.
// Свечение (слой light) смешивается с цветом, его силу задаёт light.

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "assets", "fx");

// Палитра игры (scripts/palette.gd)
const PAL = {
  BLACK: "#0b0b12", NIGHT: "#1a1c2c", DARK_WOOD: "#4a2f23", PINE: "#25402a", WOOD: "#8a5432",
  STONE: "#4e5a6a", STEEL: "#9aa6b2", LINEN: "#ece3c9", RED: "#a8322d", FIRE: "#d97a2b",
  GOLD: "#e8c254", MOSS: "#5f8f3e", FJORD: "#3d6e9e", DUSK: "#6b5679", SKIN: "#e0a87a", SNOW: "#f4f4f4",
};
const P = PAL;

// Что выгружать. opts — параметры эффекта (палитры от тёмного к светлому), x1 — что поменять
// для масштаба x1, patch — правки исходника эффекта [было, стало], speed — во сколько раз
// быстрее играть в игре, anchor: "head" — точка привязки над головой, а не у ног.
const FX = {
  slash: {
    id: "melee/sword-slash", speed: 1.5, light: 0.6,
    opts: { palette: [P.NIGHT, P.FJORD, P.STONE, P.STEEL, P.LINEN, P.SNOW, P.SNOW], sparks: [P.SNOW, P.GOLD, P.FIRE, P.RED] },
    x1: { radius: 72, margin: 30 },
  },
  hit: {
    id: "impacts/hit-spark", light: 0.7,
    opts: { palette: [P.DARK_WOOD, P.RED, P.FIRE, P.FIRE, P.GOLD, P.LINEN, P.SNOW], height: 16 },
    x1: { height: 32 },
  },
  stunned: {
    id: "status/stunned", light: 0.6, anchor: "head",
    // без птичек: только три звезды
    patch: [["bird: i % 2 === 1", "bird: false"], ["TURNS = 2, N = 5", "TURNS = 2, N = 3"]],
    opts: { palette: [P.DARK_WOOD, P.WOOD, P.FIRE, P.GOLD, P.GOLD, P.LINEN, P.SNOW] },
    x1: { actor: { w: 40, y: -64 }, margin: 24 },
  },
};
const COLS = 8;

const [pfxArg, ...names] = process.argv.slice(2);
if (!pfxArg || !existsSync(join(pfxArg, "src", "core", "index.js"))) {
  console.error("Нужен путь к клону pixelfx: node tools/export_fx.mjs <папка pixelfx> [эффект ...]");
  process.exit(1);
}
const PFX = resolve(pfxArg);
const lib = await import(pathToFileURL(join(PFX, "tools", "lib", "fxlib.mjs")).href);
const core = await import(pathToFileURL(join(PFX, "src", "core", "index.js")).href);
const { encodePNG } = await import(pathToFileURL(join(PFX, "tools", "lib", "png.mjs")).href);

const PAL_RGB = Object.values(PAL).map((h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)));
// Ближайший цвет палитры (непрозрачность не трогаем).
function quantize(buf) {
  const out = new Uint32Array(buf.length);
  for (let i = 0; i < buf.length; i++) {
    const c = buf[i], a = c >>> 24;
    if (!a) continue;
    const r = c & 255, g = (c >>> 8) & 255, b = (c >>> 16) & 255;
    let best = 0, bd = Infinity;
    PAL_RGB.forEach(([R, G, B], j) => {
      const d = (r - R) ** 2 + (g - G) ** 2 + (b - B) ** 2;
      if (d < bd) (bd = d), (best = j);
    });
    const [R, G, B] = PAL_RGB[best];
    out[i] = ((a << 24) | (B << 16) | (G << 8) | R) >>> 0;
  }
  return out;
}

async function load(name, cfg) {
  if (!cfg.patch) return lib.loadEffect(cfg.id);
  // правленая копия рядом с оригиналом, чтобы работали его относительные import
  const [cat, base] = cfg.id.split("/"), src = join(PFX, "src", "fx", cat, base + ".js");
  let text = readFileSync(src, "utf8");
  for (const [from, to] of cfg.patch) {
    if (!text.includes(from)) throw new Error(`${cfg.id}: не нашёл «${from}» — pixelfx обновился?`);
    text = text.replace(from, to);
  }
  const id = `${cat}/nord-${base}`, file = join(PFX, "src", "fx", id + ".js");
  writeFileSync(file, text);
  try {
    return await lib.loadEffect(id);
  } finally {
    rmSync(file);
  }
}

function sheet(r, k, pivot) {
  const w = r.w * k, h = r.h * k, n = r.n, cols = Math.min(COLS, n), rows = Math.ceil(n / cols);
  const data = new Uint8ClampedArray(cols * w * rows * h * 4);
  r.frames.forEach((f, i) => {
    const frame = { w: r.w, h: r.h, color: quantize(f.raw), light: f.light };
    const img = lib.upscale(core.composite(frame, new Uint8ClampedArray(r.w * r.h * 4), null), r.w, r.h, k);
    const ox = (i % cols) * w, oy = Math.floor(i / cols) * h;
    for (let y = 0; y < h; y++) data.set(img.subarray(y * w * 4, (y + 1) * w * 4), ((oy + y) * cols * w + ox) * 4);
  });
  return { png: encodePNG(cols * w, rows * h, data), info: { w, h, frames: n, cols, pivot: pivot.map((v) => v * k) } };
}

mkdirSync(join(OUT, "x1"), { recursive: true });
mkdirSync(join(OUT, "x2"), { recursive: true });
const indexFile = join(OUT, "fx.json");
const index = existsSync(indexFile) ? JSON.parse(readFileSync(indexFile, "utf8")) : {};
for (const name of names.length ? names : Object.keys(FX)) {
  const cfg = FX[name];
  if (!cfg) throw new Error(`нет эффекта «${name}», есть: ${Object.keys(FX).join(", ")}`);
  const fx = await load(name, cfg);
  const entry = { source: cfg.id, fps: fx.meta.fps, loop: fx.meta.loop, speed: cfg.speed ?? 1 };
  for (const k of [1, 2]) {
    const { margin = 0, actor, ...extra } = k === 1 ? cfg.x1 ?? {} : {};
    const options = { ...cfg.opts, ...extra, light: cfg.light ?? 1 };
    if (fx.meta.actor) options.actor = { ...core.stockActor(2), ...actor };
    const r = lib.renderFrames(fx, { bg: "none", margin, options, actor: false });
    let [px, py] = fx.meta.origin;
    px += margin;
    py += margin + (cfg.anchor === "head" ? options.actor.y : 0);
    const s = sheet(r, k, [px, py]);
    writeFileSync(join(OUT, `x${k}`, name + ".png"), s.png);
    entry["x" + k] = s.info;
  }
  index[name] = entry;
  console.log(`${name}: ${cfg.id}, ${entry.x1.frames} кадров, x1 ${entry.x1.w}x${entry.x1.h}, x2 ${entry.x2.w}x${entry.x2.h}`);
}
writeFileSync(indexFile, JSON.stringify(index, null, 1));
