"""Шаблон героя для Aseprite: art/hero/hero.aseprite.

    python tools/hero_template.py [--force]

Берёт текущие листы героя (assets/sprites/hero, а если их ещё нет — общие листы
Pyxel-версии) и раскладывает по слоям и меткам: рисуй поверх или с нуля.
Слои «_guide» (хитбокс и земля) и «_weapon» (где окажется оружие) — опорные,
в игру не попадают. Готовый файл не перезаписывается без --force.
"""

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aseprite_io as ase  # noqa: E402
from hero_rig import ANCHORS_LAYER, ANIMS, ART, HITBOX, MARKERS, OLD, OUT, PALETTE, SHEETS  # noqa: E402


def load_rig():
    """(json, {слой: Image}) — из assets/sprites/hero или из листов Pyxel-версии."""
    if os.path.exists(os.path.join(OUT, "hero.json")):
        with open(os.path.join(OUT, "hero.json"), encoding="utf-8") as f:
            rig = json.load(f)
        sheets = {name: Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
                  for name, _, _ in SHEETS if os.path.exists(os.path.join(OUT, name + ".png"))}
        return rig, sheets
    with open(os.path.join(OLD, "humanoid.json"), encoding="utf-8") as f:
        rig = json.load(f)
    sheets = {name: Image.open(os.path.join(OLD, old + ".png")).convert("RGBA") for name, old, _ in SHEETS}
    return rig, sheets


def frame_of(sheet, rig, i):
    fw, fh, cols = rig["frame_w"], rig["frame_h"], rig["cols"]
    x, y = (i % cols) * fw, (i // cols) * fh
    return sheet.crop((x, y, x + fw, y + fh))


def weapon_ref(rig, info):
    """Меч в руке под углом кадра — подсказка художнику."""
    fw, fh = rig["frame_w"], rig["frame_h"]
    out = Image.new("RGBA", (fw, fh))
    if info.get("weapon") is None:
        return out
    with open(os.path.join(OLD, "weapons.json"), encoding="utf-8") as f:
        wj = json.load(f)
    cw, ch = wj["cell"]
    idx = wj["order"].index("sword")
    cell = Image.open(os.path.join(OLD, "weapons.png")).convert("RGBA").crop((idx * cw, 0, (idx + 1) * cw, ch))
    gx, gy = wj["grip"]
    big = Image.new("RGBA", (ch * 2, ch * 2))
    big.paste(cell, (ch - gx, ch - gy))  # хват — в центре
    # Godot поворачивает по часовой при положительном угле; PIL — против.
    big = big.rotate(-info["weapon"], resample=Image.NEAREST, center=(ch, ch))
    hx, hy = info["hand"]
    out.paste(big, (int(hx) - ch, int(hy) - ch), big)
    a = out.getchannel("A").point(lambda v: v * 6 // 10)  # полупрозрачно
    out.putalpha(a)
    return out


def guide(rig):
    fw, fh = rig["frame_w"], rig["frame_h"]
    img = Image.new("RGBA", (fw, fh))
    w, h = HITBOX
    x0, y0 = (fw - w) // 2, fh - h
    px = img.load()
    for x in range(x0, x0 + w):
        px[x, y0] = (95, 143, 62, 160)
    for y in range(y0, fh):
        px[x0, y] = (95, 143, 62, 160)
        px[x0 + w - 1, y] = (95, 143, 62, 160)
    for x in range(fw):
        px[x, fh - 1] = (217, 122, 43, 200)  # земля — нижний ряд кадра
    return img


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    force = "--force" in sys.argv
    if os.path.exists(ART) and not force:
        sys.exit(f"{ART} уже есть — там может быть ваша работа. Перезаписать: --force")
    rig, sheets = load_rig()
    fw, fh = rig["frame_w"], rig["frame_h"]
    frames_info = rig["frames"]
    spr = ase.Sprite(fw, fh)
    spr.palette = [((c >> 16) & 255, (c >> 8) & 255, c & 255, 255) for c in PALETTE]
    ref = ase.LAYER_VISIBLE | ase.LAYER_REFERENCE
    spr.layers.append(ase.Layer("_guide", ref))
    for name, _, visible in SHEETS:
        spr.layers.append(ase.Layer(name, (ase.LAYER_VISIBLE if visible else 0) | ase.LAYER_EDITABLE))
    spr.layers.append(ase.Layer("_weapon", ref))
    spr.layers.append(ase.Layer(ANCHORS_LAYER))
    li_guide = spr.layer_index("_guide")
    li_weapon = spr.layer_index("_weapon")
    li_anchor = spr.layer_index(ANCHORS_LAYER)
    guide_img = guide(rig)

    # Кадры по порядку меток.
    for anim in rig["anims"]:
        ids = rig["anims"][anim]
        start = len(spr.frames)
        for i in ids:
            info = frames_info[i]
            cels = {li_guide: (0, 0, guide_img)}
            for name, _, _ in SHEETS:
                if name in sheets:
                    img = frame_of(sheets[name], rig, i)
                    box = img.getbbox()
                    if box:
                        cels[spr.layer_index(name)] = (box[0], box[1], img.crop(box))
            wref = weapon_ref(rig, info)
            box = wref.getbbox()
            if box:
                cels[li_weapon] = (box[0], box[1], wref.crop(box))
            marks = Image.new("RGBA", (fw, fh))
            for key, col in MARKERS.items():
                x, y = info[key]
                marks.putpixel((min(fw - 1, int(x)), min(fh - 1, int(y))), col + (255,))
            box = marks.getbbox()
            cels[li_anchor] = (box[0], box[1], marks.crop(box))
            weapon = info.get("weapon")
            text = "weapon=%s" % ("-" if weapon is None else int(weapon))
            spr.frames.append({"duration": ANIMS.get(anim, 100), "cels": cels, "data": {li_anchor: text}})
        spr.tags.append(ase.Tag(anim, start, len(spr.frames) - 1))
    os.makedirs(os.path.dirname(ART), exist_ok=True)
    ase.write(spr, ART)
    print(f"шаблон: {ART} — {len(spr.frames)} кадров {fw}x{fh}, {len(spr.tags)} меток, "
          f"{len(spr.layers)} слоёв")


if __name__ == "__main__":
    main()
