"""Эталон врагов и ярла из Pyxel-версии для tests/enemies_test.

    python tests/reference/make_enemies_reference.py D:/путь/к/NordSagePixel

Дуэли на площадках tests/levels/duel_*.txt и бой с ярлом в кургане. Нажатия героя —
псевдослучайный, но заранее записанный сценарий; случайные решения ярла — общий
детерминированный генератор (в Godot — World.scripted_rng). Каждый кадр пишется
герой, все враги и снаряды.
"""

import json
import os
import random
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")

# имя, файл карты, точка появления, кадров, сид, перевес шагов вправо, очки Живучести, напор
CASES = [
    ("wolf", "tests/levels/duel_wolf.txt", None, 1500, 11, 0.6, 10, 0.0),
    ("draugr", "tests/levels/duel_draugr.txt", None, 1500, 12, 0.6, 10, 0.0),
    ("shield", "tests/levels/duel_shield.txt", None, 1800, 13, 0.6, 10, 0.0),
    ("archer", "tests/levels/duel_archer.txt", None, 1800, 14, 0.65, 10, 0.0),
    ("pack", "tests/levels/duel_pack.txt", None, 2500, 15, 0.6, 10, 0.0),
    ("jarl", "data/levels/barrow.txt", "entry", 7000, 21, 0.62, 80, 0.35),
]
# Снаряжение и запас жизни, чтобы бой длился, а не кончался на первой минуте.
EQUIP = {"weapon": "axe", "shield": "shield_round", "armor": "mail", "helmet": "shishak"}
PYXEL_NAMES = {"move_left": "left", "move_right": "right", "move_up": "up", "move_down": "down",
               "jump": "jump", "attack": "attack", "roll": "roll", "block": "block"}


def scenario(frames, seed, right, aggro):
    """aggro — доля дополнительных серий ударов (для долгого боя с ярлом)."""
    rnd = random.Random(seed)
    out, total = [], 0

    def add(n, acts):
        nonlocal total
        out.append([n, acts])
        total += n

    while total < frames:
        side = "move_right" if rnd.random() < right else "move_left"
        if rnd.random() < aggro:
            add(rnd.randint(4, 12), [side])
            for _ in range(rnd.randint(2, 3)):
                add(1, ["attack"])
                add(rnd.randint(3, 6), [])
            add(rnd.randint(6, 14), [])
            continue
        k = rnd.random()
        if k < 0.18:
            add(rnd.randint(5, 40), [])
        elif k < 0.40:
            add(rnd.randint(10, 50), [side])
        elif k < 0.58:
            for _ in range(rnd.randint(1, 3)):
                add(1, ["attack"])
                add(rnd.randint(3, 8), [])
            add(rnd.randint(8, 25), [])
        elif k < 0.66:
            add(rnd.randint(28, 40), ["attack"])
            add(rnd.randint(10, 25), [])
        elif k < 0.80:
            add(rnd.randint(10, 50), ["block"])
            add(rnd.randint(2, 10), [])
        elif k < 0.88:
            add(1, [side, "roll"])
            add(rnd.randint(10, 25), [])
        elif k < 0.95:
            add(rnd.randint(8, 16), ["jump", side])
            if rnd.random() < 0.5:
                add(1, ["move_down", "attack"])
            else:
                add(1, ["attack"])
            add(rnd.randint(20, 40), [])
        else:
            add(rnd.randint(30, 80), [side])
    return out


class Lcg:
    """Тот же генератор, что World.rand() в Godot."""

    def __init__(self, seed):
        self.s = seed

    def random(self):
        self.s = (self.s * 1103515245 + 12345) % 2147483648
        return self.s / 2147483648

    @staticmethod
    def uniform(a, b):
        return random.uniform(a, b)  # только дым — на логику не влияет


def enemy_state(e):
    name = type(e).__name__
    if name == "Wolf":
        return "wolf", f"c{e.crouch_t}l{int(e.lunging)}t{e.lunge_cd}"
    if name == "ShieldDraugr":
        return "shield_draugr", f"{e.state}{e.state_t}g{e.guard}"
    if name == "Draugr":
        return "draugr", f"{e.state}{e.state_t}"
    if name == "Archer":
        return "archer", f"{e.state}{e.state_t}c{e.cooldown}"
    if name == "JarlBoss":
        return "jarl", f"{e.state}{e.state_t}p{e.phase}"
    return "dummy", ""


def main():
    pyxel_root = os.path.abspath(sys.argv[1])
    sys.path.insert(0, pyxel_root)
    import pyxel
    from game import audio, bosses, config, controls, font, gfx, sprites, world
    from game.state import GameState

    levels = tempfile.mkdtemp()
    for _, path, *_ in CASES:
        shutil.copy(os.path.join(ROOT, path), levels)
    world.LEVELS_DIR = levels

    pyxel.init(config.SCREEN_W, config.SCREEN_H, fps=config.FPS)
    pyxel.colors[:] = config.PALETTE
    font.init()
    gfx.init()
    sprites.init()
    audio.init()
    audio.sfx = lambda *a: None
    audio.music_start = lambda *a: None
    world.save.write = lambda data: True  # победа над ярлом сохраняет игру — не трогаем файлы

    held, pressed = set(), set()
    controls.held = lambda a: a in held
    controls.pressed = lambda a, repeat=False: a in pressed

    result = []
    for name, path, spawn, frames, seed, right, vit, aggro in CASES:
        bosses.random = Lcg(seed)
        st = GameState()
        st.spawn = None
        st.inventory.equipment.update(EQUIP)
        st.inventory.stats["vit"] = vit
        st.hp = st.inventory.max_hp
        level_name = os.path.basename(path)[:-4]
        w = world.World(st, level_name, spawn)
        steps = scenario(frames, seed, right, aggro)
        trace = []
        prev = set()
        for n, actions in steps:
            for _ in range(n):
                now = {PYXEL_NAMES[a] for a in actions}
                held.clear()
                held.update(now)
                pressed.clear()
                pressed.update(now - prev)
                prev = now
                w.update()
                p = w.player
                foes = []
                for e in w.enemies:
                    kind, s = enemy_state(e)
                    foes.append([kind, e.x, e.y, e.vx, e.vy, e.hp, e.facing, e.stun_t, s])
                shots = [[pr.x, pr.y, pr.vx] for pr in w.projectiles]
                trace.append([[p.x, p.y, p.vx, p.vy, p.state, round(p.stamina, 6), p.hp, w.hitstop], foes, shots])
        boss = [f for f in trace[-1][1] if f[0] == "jarl"]
        print(f"{name}: {len(trace)} кадров, врагов в начале {len(trace[0][1])}, в конце {len(trace[-1][1])}, "
              f"жизнь героя {trace[-1][0][6]}" + (f", ярл {boss[0][5]} hp {boss[0][8]}" if boss else "")
              + (f", ярость с кадра {next((i for i, t in enumerate(trace) if any(f[0] == 'jarl' and f[8].endswith('p2') for f in t[1])), '-')}"
                 if name == "jarl" else ""))
        result.append({"name": name, "level": path, "spawn": spawn or "", "seed": seed,
                       "equip": EQUIP, "vit": vit, "scenario": steps, "trace": trace})
    shutil.rmtree(levels)
    out = os.path.join(HERE, "enemies.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f)
    print("->", out, f"{os.path.getsize(out) // 1024} КБ")


if __name__ == "__main__":
    main()
