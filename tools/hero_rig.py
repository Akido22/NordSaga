"""Общее для шаблона героя (hero_template.py) и импорта (import_hero.py).

Герой рисуется в art/hero/hero.aseprite: один кадр Aseprite — один кадр игры,
метки (теги) — анимации, слои — листы, из которых игра собирает облик.
"""

import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ART = os.path.join(ROOT, "art", "hero", "hero.aseprite")
OUT = os.path.join(ROOT, "assets", "sprites", "hero")
OLD = os.path.join(ROOT, "assets", "sprites", "characters")  # общие листы Pyxel-версии

# Слои-листы снизу вверх: имя слоя (= имя PNG в assets/sprites/hero), лист Pyxel-версии
# для первого шаблона, виден ли слой в шаблоне сразу.
SHEETS = [
    ("legs", "hero_legs", True),
    ("torso_plain", "hero_torso_plain", False),
    ("torso_shirt", "hero_torso_shirt", True),
    ("torso_leather", "hero_torso_leather", False),
    ("torso_mail", "hero_torso_mail", False),
    ("head", "hero_head_male", True),
    ("helmet_cap", "hero_helmet_cap", False),
    ("helmet_shishak", "hero_helmet_shishak", False),
]
REQUIRED = ["legs", "torso_plain", "head"]  # без них героя не собрать

# Анимации, которые ждёт код героя (scenes/player/player.gd), и длительность кадра
# в Aseprite (мс) — только для просмотра: в игре темп задаёт код.
ANIMS = {
    "idle": 250, "run": 83, "jump": 100, "fall": 100, "roll": 67, "block": 100,
    "attack": 67, "attack2": 67, "heavy": 100, "plunge": 100, "cast": 100,
    "hurt": 100, "death": 167,
}

# Слой точек привязки: по одному пикселю этих цветов в каждом кадре.
ANCHORS_LAYER = "anchors"
MARKERS = {"hand": (255, 0, 0), "back": (0, 0, 255), "head": (0, 255, 0)}

# Хитбокс героя (для опорного слоя): 20x44, по центру низа кадра.
HITBOX = (20, 44)

# Палитра Pyxel-версии — для удобства в шаблоне; рисовать можно любыми цветами.
PALETTE = [
    0x0B0B12, 0x1A1C2C, 0x4A2F23, 0x25402A, 0x8A5432, 0x4E5A6A, 0x9AA6B2, 0xECE3C9,
    0xA8322D, 0xD97A2B, 0xE8C254, 0x5F8F3E, 0x3D6E9E, 0x6B5679, 0xE0A87A, 0xF4F4F4,
]
