"""Эталон движения героя из Pyxel-версии для tests/movement_test.

    python tests/reference/make_movement_reference.py D:/путь/к/NordSagePixel

Прогоняет сценарий нажатий в Pyxel-версии на «Лесной тропе» и записывает
каждый кадр: положение, скорость, опору, взгляд, кадр анимации, жизнь.
Godot-версия должна совпасть с точностью до масштаба (x2).
"""

import json
import os
import sys

# Сценарий: (кадров, удерживаемые действия). Нажатие — первый кадр удержания.
SCENARIO = [
    (30, []),
    (70, ["move_right"]),
    (25, ["move_right", "jump"]),
    (40, ["move_right"]),
    (4, ["jump"]),
    (40, []),
    (50, ["move_left"]),
    (30, ["move_left", "jump"]),
    (20, []),
    (12, ["jump"]),
    (30, []),
    (120, ["move_right"]),
    (20, ["move_right", "jump"]),
    (200, ["move_right"]),
    (20, ["move_right", "jump"]),
    (150, ["move_right"]),
    (8, ["move_down", "jump"]),
    (60, []),
]

PYXEL_NAMES = {"move_left": "left", "move_right": "right", "move_up": "up", "move_down": "down", "jump": "jump"}


def main():
    pyxel_root = os.path.abspath(sys.argv[1])
    sys.path.insert(0, pyxel_root)
    import pyxel
    from game import audio, config, controls, font, gfx, sprites, world
    from game.state import GameState

    pyxel.init(config.SCREEN_W, config.SCREEN_H, fps=config.FPS)
    pyxel.colors[:] = config.PALETTE
    font.init()
    gfx.init()
    sprites.init()
    audio.init()
    audio.sfx = lambda *a: None

    held, pressed = set(), set()
    controls.held = lambda a: a in held
    controls.pressed = lambda a, repeat=False: a in pressed
    st = GameState()
    st.spawn = None
    w = world.World(st, "test_level")
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
            p.poll_input()
            p.update(w)
            trace.append([p.x, p.y, p.vx, p.vy, p.on_ground, p.facing, p.frame(), p.hp])
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "movement.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"scenario": SCENARIO, "trace": trace}, f)
    print(f"{len(trace)} кадров -> {out}")


if __name__ == "__main__":
    main()
