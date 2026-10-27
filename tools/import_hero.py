"""Герой из Aseprite в игру: art/hero/hero.aseprite -> assets/sprites/hero.

    python tools/import_hero.py [путь/к/hero.aseprite]

Каждый слой из hero_rig.SHEETS становится листом PNG (кадры по 8 в ряд), метки —
анимациями, слой anchors — точками кисти, спины и головы (по пикселю цвета из
hero_rig.MARKERS), текст ячейки anchors «weapon=30» или «weapon=-» — углом оружия.
Лист может быть и группой слоёв с таким именем: тогда склеиваются её видимые
слои (кроме «_»-слоёв). Слои, чьи имена начинаются с «_», и неизвестные слои
пропускаются.
Если чего-то не хватает, импорт останавливается и объясняет, что исправить.
"""

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aseprite_io as ase  # noqa: E402
from hero_rig import ANCHORS_LAYER, ANIMS, ART, MARKERS, OUT, REQUIRED, SHEETS  # noqa: E402

COLS = 8


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    path = sys.argv[1] if len(sys.argv) > 1 else ART
    spr = ase.read(path)
    errors, notes = [], []
    fw, fh = spr.width, spr.height
    n = len(spr.frames)

    # Слои: по имени (группы не мешают — ищется и «группа/слой», и просто «слой»).
    known = {name for name, _, _ in SHEETS}
    layers = {}  # лист -> номера слоёв, которые в него склеиваются (снизу вверх)
    inside = set()  # слои внутри групп-листов
    for i, layer in enumerate(spr.layers):
        if layer.group and layer.name in known:
            kids = []
            for j in range(i + 1, len(spr.layers)):
                if spr.layers[j].level <= layer.level:
                    break
                inside.add(j)
                child = spr.layers[j]
                if not child.group and child.visible and not child.name.startswith("_"):
                    kids.append(j)
            layers[layer.name] = kids
    for i, layer in enumerate(spr.layers):
        if layer.group or layer.name.startswith("_") or i in inside:
            continue
        if layer.name in known:
            if layer.name in layers:
                errors.append(f"лист «{layer.name}» встречается дважды")
            layers[layer.name] = [i]
        elif layer.name != ANCHORS_LAYER:
            notes.append(f"слой «{layer.path}» не нужен игре — пропущен")
        if layer.opacity < 255 and layer.name in known:
            notes.append(f"у слоя «{layer.name}» прозрачность {layer.opacity} — в игре будет непрозрачным")
    for name in REQUIRED:
        if name not in layers:
            errors.append(f"нет слоя «{name}»")
    anchors = spr.layer_index(ANCHORS_LAYER)
    if anchors < 0:
        errors.append(f"нет слоя «{ANCHORS_LAYER}» с точками привязки")

    # Метки -> анимации.
    anims = {}
    for t in spr.tags:
        if t.name in anims:
            errors.append(f"метка «{t.name}» встречается дважды")
        anims[t.name] = list(range(t.start, t.end + 1))
    for name in ANIMS:
        if name not in anims:
            errors.append(f"нет метки (тега) «{name}»")
    for name in anims:
        if name not in ANIMS:
            notes.append(f"метка «{name}» игре не нужна — кадры попадут в лист, но не используются")

    # Точки привязки и угол оружия по кадрам.
    frames = []
    if anchors >= 0:
        for f in range(n):
            img = spr.image(f, anchors)
            info = {}
            for key, col in MARKERS.items():
                found = [(x, y) for y in range(fh) for x in range(fw)
                         if img.getpixel((x, y))[3] > 0 and img.getpixel((x, y))[:3] == col]
                if not found:
                    errors.append(f"кадр {f + 1}: нет точки «{key}» (пиксель {col})")
                    continue
                if len(found) > 1:
                    notes.append(f"кадр {f + 1}: точек «{key}» {len(found)} — взята первая")
                info[key] = [found[0][0] + 0.5, found[0][1] + 0.5]
            text = spr.frames[f]["data"].get(anchors, "")
            weapon = None
            for part in text.replace(";", " ").split():
                if part.startswith("weapon="):
                    v = part.split("=", 1)[1]
                    if v not in ("-", ""):
                        try:
                            weapon = int(float(v))
                        except ValueError:
                            errors.append(f"кадр {f + 1}: непонятный угол «{part}»")
            info["weapon"] = weapon
            frames.append(info)

    if errors:
        print("Импорт остановлен:")
        for e in errors[:30]:
            print("  -", e)
        if len(errors) > 30:
            print(f"  ... и ещё {len(errors) - 30}")
        sys.exit(1)

    os.makedirs(OUT, exist_ok=True)
    rows = (n + COLS - 1) // COLS
    for name, ids in layers.items():
        sheet = Image.new("RGBA", (COLS * fw, rows * fh))
        for f in range(n):
            img = Image.new("RGBA", (fw, fh))
            for li in ids:
                img = Image.alpha_composite(img, spr.image(f, li))
            sheet.paste(img, ((f % COLS) * fw, (f // COLS) * fh))
        sheet.save(os.path.join(OUT, name + ".png"))
    rig = {"frame_w": fw, "frame_h": fh, "cols": COLS, "anims": anims, "frames": frames,
           "sheets": sorted(layers)}
    with open(os.path.join(OUT, "hero.json"), "w", encoding="utf-8") as f:
        json.dump(rig, f, ensure_ascii=False, indent=1)
    for note in notes:
        print("  заметка:", note)
    print(f"герой: {n} кадров {fw}x{fh}, листы: {', '.join(sorted(layers))} -> {OUT}")


if __name__ == "__main__":
    main()
