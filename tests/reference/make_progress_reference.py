"""Эталоны шага 7 из Pyxel-версии для tests/progress_test.

    python tests/reference/make_progress_reference.py D:/путь/к/NordSagePixel

inventory.json — случайные операции с сумой, лавками, кузней и очками (как TradeScene
и RestScene): после каждой — сума целиком и показатели героя.
magic.json — бой с драугром чарами и припасами: каждый кадр герой (с маной и щитом),
враги и снаряды (огненные шары).
"""

import json
import os
from types import SimpleNamespace
import random
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
PYXEL_NAMES = {"move_left": "left", "move_right": "right", "move_up": "up", "move_down": "down",
               "jump": "jump", "attack": "attack", "roll": "roll", "block": "block",
               "cast": "cast", "next_rune": "next_rune", "heal": "heal"}


def inventory_ops(items, shops, n, seed):
    rnd = random.Random(seed)
    ids = sorted(items)
    ops = []
    for _ in range(n):
        k = rnd.random()
        if k < 0.22:
            ops.append(["add", rnd.choice(ids), rnd.randint(1, 3)])
        elif k < 0.32:
            ops.append(["equip", rnd.randrange(24)])
        elif k < 0.36:
            ops.append(["unequip", rnd.choice(["weapon", "shield", "helmet", "armor", "amulet"])])
        elif k < 0.40:
            ops.append(["take", rnd.choice(["ore", "honey", "bread"]), rnd.randint(1, 3)])
        elif k < 0.48:
            ops.append(["xp", rnd.randint(5, 60)])
        elif k < 0.55:
            ops.append(["spend", rnd.choice(["str", "sta", "vit", "spi", "luck"])])
        elif k < 0.62:
            ops.append(["silver", rnd.randint(5, 60)])
        elif k < 0.95:
            shop = rnd.choice(sorted(shops))
            ops.append(["trade", shop, rnd.randrange(len(shops[shop].tabs)), rnd.randrange(30)])
        else:
            ops.append(["next_spell"])
    return ops


def run_inventory():
    from game import items, menus
    from game.inventory import Inventory
    from game.shops import SHOPS

    inv = Inventory.starting()

    class Play:
        world = SimpleNamespace(player=SimpleNamespace(inv=inv, cx=0, y=0), sparks=lambda *a: None)

    ops = inventory_ops(items.ITEMS, SHOPS, 600, 7)
    snaps = []
    for op in ops:
        kind = op[0]
        if kind == "add":
            inv.add(op[1], op[2])
        elif kind == "equip":
            inv.equip_from_bag(op[1])
        elif kind == "unequip":
            inv.unequip(op[1])
        elif kind == "take":
            inv.take(op[1], op[2])
        elif kind == "xp":
            inv.add_xp(op[1])
        elif kind == "spend":
            inv.spend_point(op[1])
        elif kind == "silver":
            inv.silver += op[1]
        elif kind == "next_spell":
            inv.next_spell()
        else:
            scene = menus.TradeScene.__new__(menus.TradeScene)
            menus.Overlay.__init__(scene, None, Play)
            scene.shop = SHOPS[op[1]]
            scene.tab = op[2]
            scene.index = 0
            scene.scroll = 0
            rows = scene.entries()
            if rows:
                scene._act(rows[op[3] % len(rows)])
        snaps.append([json.loads(json.dumps(inv.to_dict())),
                      [inv.max_hp, inv.attack, inv.defense, inv.max_stamina, inv.max_mana,
                       inv.spell or "", -1 if inv.first_consumable() is None else inv.first_consumable()]])
    return {"ops": ops, "snaps": snaps}


MAGIC = [
    (20, []),
    (1, ["cast"]), (40, []), (1, ["cast"]), (30, []), (1, ["cast"]), (30, []),
    (1, ["next_rune"]), (2, []), (1, ["cast"]), (30, []),
    (60, ["move_right"]), (20, ["block"]), (10, []),
    (1, ["attack"]), (5, []), (1, ["attack"]), (30, []),
    (1, ["heal"]), (10, []), (1, ["next_rune"]), (2, []), (1, ["cast"]), (50, []),
    (1, ["heal"]), (10, []), (1, ["heal"]), (10, []),
    (1, ["next_rune"]), (2, []), (1, ["cast"]), (5, []), (1, ["cast"]), (30, []),
    (12, ["jump"]), (1, ["cast"]), (30, []),
    (1, ["next_rune"]), (2, []), (1, ["cast"]), (40, []),
    (40, ["move_left"]), (1, ["move_right"]), (1, ["cast"]), (40, []),
    (30, ["attack"]), (30, []), (1, ["cast"]), (80, []),
    (1, ["roll"]), (20, []), (1, ["cast"]), (60, []),
]


def run_magic():
    from game import controls, world
    from game.state import GameState

    held, pressed = set(), set()
    controls.held = lambda a: a in held
    controls.pressed = lambda a, repeat=False: a in pressed
    st = GameState()
    st.spawn = None
    inv = st.inventory
    inv.spells = ["rune_fire", "rune_shield", "rune_heal"]
    inv.stats["spi"] = 6
    inv.stats["vit"] = 3
    inv.add("honey", 2)
    st.hp = inv.max_hp
    w = world.World(st, "duel_draugr")
    p = w.player
    p.hp = 9  # чтобы было что лечить
    trace = []
    prev = set()
    for n, actions in MAGIC:
        for _ in range(n):
            now = {PYXEL_NAMES[a] for a in actions}
            held.clear()
            held.update(now)
            pressed.clear()
            pressed.update(now - prev)
            prev = now
            w.update()
            foes = [[e.x, e.y, e.vx, e.vy, e.hp, e.stun_t, getattr(e, "state", "")] for e in w.enemies]
            shots = [[type(s).__name__, s.x, s.y, s.vx] for s in w.projectiles]
            trace.append([[p.x, p.y, p.vx, p.vy, p.state, round(p.stamina, 6), p.hp, round(p.mana, 6),
                           p.shield_t, w.hitstop, inv.active_spell], foes, shots])
    return {"scenario": MAGIC, "spirit": 6, "vit": 3, "hp": 9, "trace": trace}


def main():
    pyxel_root = os.path.abspath(sys.argv[1])
    sys.path.insert(0, pyxel_root)
    import pyxel
    from game import audio, config, font, gfx, sprites, world

    levels = tempfile.mkdtemp()
    shutil.copy(os.path.join(ROOT, "tests/levels/duel_draugr.txt"), levels)
    world.LEVELS_DIR = levels
    pyxel.init(config.SCREEN_W, config.SCREEN_H, fps=config.FPS)
    pyxel.colors[:] = config.PALETTE
    font.init()
    gfx.init()
    sprites.init()
    audio.init()
    audio.sfx = lambda *a: None
    audio.music_start = lambda *a: None

    inv_ref = run_inventory()
    with open(os.path.join(HERE, "inventory.json"), "w", encoding="utf-8") as f:
        json.dump(inv_ref, f, ensure_ascii=False)
    last = inv_ref["snaps"][-1]
    print(f"сума: {len(inv_ref['ops'])} операций, в конце уровень {last[0]['level']}, серебро {last[0]['silver']}, "
          f"заточки {last[0]['upgrades']}, руны {last[0]['spells']}")

    magic = run_magic()
    shutil.rmtree(levels)
    with open(os.path.join(HERE, "magic.json"), "w", encoding="utf-8") as f:
        json.dump(magic, f, ensure_ascii=False)
    t = magic["trace"]
    fireballs = sum(1 for i, r in enumerate(t) if any(s[0] == "Fireball" for s in r[2])
                    and not (i and any(s[0] == "Fireball" for s in t[i - 1][2])))
    print(f"чары: {len(t)} кадров, огненных шаров {fireballs}, щит {max(r[0][8] for r in t)}, "
          f"жизнь героя {t[0][0][6]} -> {max(r[0][6] for r in t)}, драугр {t[-1][1]}")


if __name__ == "__main__":
    main()
