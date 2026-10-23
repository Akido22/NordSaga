"""Собирает data/json/*.json из data/*.toml — Godot читает JSON, а править удобнее TOML.

    python tools/toml_to_json.py

Запускать после каждой правки TOML (нужен Python 3.11+).
"""

import json
import os
import sys
import tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data")
DST = os.path.join(SRC, "json")


def main():
    os.makedirs(DST, exist_ok=True)
    failed = False
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith(".toml"):
            continue
        try:
            with open(os.path.join(SRC, fn), "rb") as f:
                data = tomllib.load(f)
        except tomllib.TOMLDecodeError as e:
            print(f"data/{fn}: ошибка в записи — {e}", file=sys.stderr)
            failed = True
            continue
        out = os.path.join(DST, fn[:-5] + ".json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        print(f"data/{fn} -> data/json/{fn[:-5]}.json")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
