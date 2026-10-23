"""Эталон боя героя из Pyxel-версии для tests/combat_test.

    python tests/reference/make_combat_reference.py D:/путь/к/NordSagePixel

Прогоняет сценарий на «Ристалище» (data/levels/arena.txt) целым миром Pyxel —
со стоп-кадрами при попаданиях — и записывает каждый кадр героя.
"""

import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ARENA = os.path.join(HERE, "..", "..", "data", "levels", "arena.txt")


def _taps(action, n, gap):
    out = []
    for _ in range(n):
        out += [(1, [action]), (gap, [])]
    return out


# (кадров, удерживаемые действия). Нажатие — первый кадр удержания.
SCENARIO = [
    (20, []),
    (34, ["move_right"]),
    # серия из трёх ударов, потом из двух
    (1, ["attack"]), (5, []), (1, ["attack"]), (5, []), (1, ["attack"]), (40, []),
    (1, ["attack"]), (3, []), (1, ["attack"]), (40, []),
    # тяжёлый удар (удержание) и недодержанный
    (45, ["attack"]), (50, []),
    (24, ["attack"]), (40, []),
    # перекаты и блок
    (1, ["roll"]), (30, []), (1, ["move_left", "roll"]), (30, []),
    (40, ["block"]), (20, []),
    (20, ["block"]), (1, ["block", "roll"]), (30, []),
    # к чучелу, удар в прыжке и в падении
    (30, ["move_right"]), (12, ["jump"]), (1, ["attack"]), (40, []),
    (14, ["jump"]), (1, ["move_down", "attack"]), (60, []),
    (16, ["jump"]), (6, []), (1, ["move_down", "attack"]), (60, []),
    # на доску и удар в падении с неё
    (20, ["move_left"]), (16, ["move_left", "jump"]), (10, ["move_left"]), (20, []),
    (6, ["move_right"]), (1, ["move_down", "jump"]), (4, []), (1, ["move_down", "attack"]), (60, []),
    # силы кончаются: перекаты подряд, потом удары без сил
] + _taps("roll", 8, 20) + _taps("attack", 4, 6) + [
    (120, []),
    (1, ["roll"]), (2, []), (1, ["attack"]), (40, []),
    (60, ["move_left"]),
]

PYXEL_NAMES = {"move_left": "left", "move_right": "right", "move_up": "up", "move_down": "down",
               "jump": "jump", "attack": "attack", "roll": "roll", "block": "block"}


def main():
    pyxel_root = os.path.abspath(sys.argv[1])
    sys.path.insert(0, pyxel_root)
    import pyxel
    from game import audio, config, controls, font, gfx, sprites, world
    from game.state import GameState

    levels = tempfile.mkdtemp()
    shutil.copy(ARENA, os.path.join(levels, "arena.txt"))
    world.LEVELS_DIR = levels

    pyxel.init(config.SCREEN_W, config.SCREEN_H, fps=config.FPS)
    pyxel.colors[:] = config.PALETTE
    font.init()
    gfx.init()
    sprites.init()
    audio.init()
    audio.sfx = lambda *a: None
    audio.music_start = lambda *a: None

    held, pressed = set(), set()
    controls.held = lambda a: a in held
    controls.pressed = lambda a, repeat=False: a in pressed
    st = GameState()
    st.spawn = None
    w = world.World(st, "arena")
    p = w.player

    trace = []
    prev = set()
    for frames, actions in SCENARIO:
        for _ in range(frames):
            now = {PYXEL_NAMES[a] for a in actions}
            held.clear()
            held.update(now)
            pressed.clear()
            pressed.update(now - prev)
            prev = now
            w.update()
            trace.append([p.x, p.y, p.vx, p.vy, p.state, round(p.stamina, 6), p.frame(), p.combo, w.hitstop, p.hp])
    shutil.rmtree(levels)
    out = os.path.join(HERE, "combat.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"scenario": SCENARIO, "trace": trace}, f)
    states = sorted({t[4] for t in trace})
    print(f"{len(trace)} кадров, состояния: {', '.join(states)} -> {out}")


if __name__ == "__main__":
    main()
