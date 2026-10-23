# Северная Сага (Godot)

Славяно-скандинавский пиксельный экшен-платформер в духе Mortal Crusade.
Перенос с Pyxel-версии: https://github.com/Akido22/NordSagePixel — она остаётся
образцом: поведение, числа баланса и уровни сверяются с ней.

## Решения (шаг 0)

| | |
|---|---|
| Движок | Godot 4.7, рендер Compatibility |
| Язык | GDScript |
| Платформы | ПК (Windows), Android — экранные кнопки закладываются сразу |
| Экран | 480x270 (16:9), целочисленное масштабирование, без сглаживания |
| Тайл | 16 px |
| Герой | ~48x64, слои: ноги, тело, голова, шлем + перекраска шейдером |
| Баланс | `data/*.toml` (основной файл) → JSON для игры |
| Графика | сначала перенесённая из Pyxel как заглушки, потом перерисовка без правок кода |

## План перехода

0. Решения и репозиторий ✔
1. Каркас: настройки экрана, Input Map, папки, autoload (`Data`, `GameState`, `SaveSystem`, `Audio`) ✔
2. Перенос ресурсов из Pyxel: тайлы, постройки, иконки, шрифт, звуки, TOML → JSON ✔
3. Герой и движение — ощущение как в Pyxel ✔
4. Уровни: импорт `levels/*.txt` в сцены; Велеград, Лесная тропа, курган ✔
5. Бой: выносливость, комбо, тяжёлый удар, кувырок, блок и парирование, стоп-кадр ✔
6. Враги и ярл Хрёрек
7. Прокачка, руны, жители, лавки, кузница
8. Интерфейс и сохранение — полное прохождение
9. Android: экранное управление, экспорт APK
10. Новая графика

## Структура

```
scenes/    game.tscn (корень: смена локаций), world, levels (town, test_level, barrow, arena),
           player, enemies, bosses, ui, debug
scripts/   autoload; physics (TileBody — тайловая физика); world (World, Level, Effects);
           objects (объекты уровня); enemies (Enemy, Dummy — чучело);
           characters (HumanoidLook — гуманоид из слоёв);
           ui (UiKit — панели и текст, hud); shaders (перекраска по палитре);
           palette.gd (Pal), strips.gd (Strips — анимации из лент), icons.gd (Icons)
data/      баланс (TOML и собранный JSON в data/json), levels/*.txt — карты из Pyxel-версии
assets/    tiles, sprites (characters, objects, props, icons), backgrounds, fonts, audio/sfx, audio/music
tests/     автопроверки
tools/     конвертеры
```

Глобальные скрипты (autoload):

| | |
|---|---|
| `Controls` | действия ввода: клавиатура (физические клавиши — WASD работает и на русской раскладке) и геймпад |
| `Data` | таблицы баланса из `data/json` |
| `GameState` | состояние похода: сума, здоровье, сундуки, флаги |
| `SaveSystem` | сохранение `user://save.json`, формат v2 как в Pyxel-версии |
| `Audio` | звуки и музыка, M — вкл/выкл музыку |

## Данные (баланс)

Правится `data/*.toml` (описание полей — в комментариях внутри файлов), затем:
```
python tools/toml_to_json.py
```
Игра читает собранные `data/json/*.json`.
Единицы — пиксели нового масштаба (тайл 16 px): скорости и расстояния вдвое
больше, чем в Pyxel-версии, время в кадрах (60 = 1 секунда) — то же. При экспорте игры добавить `*.json`
в фильтр ресурсов, иначе таблицы не попадут в сборку.

## Ресурсы

Сейчас вся графика и звук — временные, выгруженные из Pyxel-версии в масштабе ×2
(тайл 16 px, герой 48x64). Повторная выгрузка — из репозитория NordSagePixel:
```
python tools/export_for_godot.py D:/ProgramFiles/ProjectDir/godot/NordSaga/nord-saga
```

| Что | Где | Описание |
|---|---|---|
| Тайлы | `assets/tiles/tiles.png` | 16x16 в ряд; `tiles.json` — порядок, твёрдые, платформы, колья |
| Персонажи | `assets/sprites/characters` | слои героя, волк, оружие; `humanoid.json` — кадры, анимации, точки кисти/спины/головы |
| Объекты | `assets/sprites/objects` | сундуки, камни, врата, стела, указатели, декор |
| Постройки | `assets/sprites/props` | изба, длинный дом, кузня, лавки…; имя — `вид_ширина` в тайлах |
| Иконки | `assets/sprites/icons.png` | 16x16 в ряд; порядок — `icons.json` |
| Фоны | `assets/backgrounds/<лес/город/курган>` | слои параллакса; `backgrounds.json` — скорость и ширина повтора |
| Шрифт | `assets/fonts/nord_font.fnt` | пиксельный 5x7 с кириллицей, размер 9 (кратные — 18, 27) |
| Звук | `assets/audio` | эффекты `sfx/*.wav`, зацикленная музыка `music/*.wav` |

Анимации объектов и построек — ленты кадров слева направо; в JSON рядом:
`frame_w`, `frame_h`, `frames`, `fps` и `anchor` — точка, которая встаёт на
низ-левый угол тайла в уровне. Новый рисунок с тем же именем и описанием
подменяет старый без правки кода.

## Локации

Сцены `scenes/levels/*.tscn` правятся прямо в редакторе Godot:

| Узел | Что внутри |
|---|---|
| `Tiles`, `Decor` | слои тайлов (набор `assets/tiles/tiles.tres`; тип тайла — данные «kind»: solid, platform, spikes) |
| `Props` | постройки `Prop`: вид и ширина в тайлах |
| `Objects` | `Chest` (добыча), `SavePoint` (камень/стела), `Sign` (текст), `Gate` (куда и в какую точку), `EdgeExit`, `Pickup` (монета/вещь), `Decor` |
| `Npcs` | жители `Npc` (id из `data/npcs.toml`) |
| `Enemies` | метки врагов (сами враги — шаг 6) |
| `Spawns` | точки появления; `Start` — старт героя |

У корня — название, подзаголовок, фон, музыка, размер в тайлах и описание арены
босса. Объект ставится на левый нижний угол своего тайла (сетка 16 px).

Сцены были собраны из карт Pyxel-версии (`data/levels/*.txt`) импортёром
`godot --headless --path . res://tools/import_levels.tscn` — **повторный импорт
затирает правки, сделанные в редакторе.**

## Управление

| Действие | Клавиатура | Геймпад |
|---|---|---|
| Движение | стрелки / WASD | крестовина / левый стик |
| Прыжок | Пробел / Z / K | A |
| Удар | X / J | X |
| Блок | C / L | RB |
| Кувырок | V / Shift / ; | B |
| Лечение | Q / H | LB |
| Чары / смена руны | F / U, E / O | Y, левый стик (нажатие) |
| Сума / пауза | I / Tab, Esc / P | Back, Start |
| Открыть, говорить, войти | ↑ / W | крестовина вверх |

## Проверка

```
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --path . res://tests/movement_test.tscn
godot --headless --path . res://tests/levels_test.tscn
godot --headless --path . res://tests/combat_test.tscn
```
- `smoke_test` — настройки, ввод, сохранение, ресурсы (`SMOKE OK`).
- `movement_test` — движение героя кадр в кадр против Pyxel-версии
  (`MOVEMENT OK`). Эталон `tests/reference/movement.json` пересобирается так:
  `python tests/reference/make_movement_reference.py D:/путь/к/NordSagePixel`.
- `combat_test` — бой героя кадр в кадр против Pyxel-версии на «Ристалище»
  (`data/levels/arena.txt`): серии ударов, тяжёлый удар, удар в падении,
  перекаты, блок, выносливость до нуля, стоп-кадры (`COMBAT OK`). Эталон:
  `python tests/reference/make_combat_reference.py D:/путь/к/NordSagePixel`.
- `levels_test` — тайлы сцен совпадают с картами, сундук, стела, табличка,
  разговор, монета, переходы город → тропа → курган → тропа → город (`LEVELS OK`).

Снимок любой сцены (без `--headless`), можно с удержанием действий:
```
godot --path . res://tests/smoke_test.tscn -- --shot=C:/tmp/shot.png --scene=res://scenes/world/world.tscn --level=arena --equip=weapon:sword,shield:shield_red --hold=block --frames=30
```

Главная сцена (F5) — `scenes/game.tscn`: новая игра в Велеграде. Работают сундуки,
стела и рунные камни (сохранение), таблички, разговоры, монеты, переходы между
локациями и весь бой героя; бить пока можно только чучела (у тренера в Велеграде и
на «Ристалище» — `scenes/levels/arena.tscn`, F6). Враги — шаг 6; погибший
встаёт на старте.
`scenes/debug/input_test.tscn` — проверка ввода.
`scenes/debug/asset_gallery.tscn` (F6 в редакторе) — все перенесённые ресурсы:
фон с параллаксом, постройки и объекты с анимацией, тайлы, иконки, шрифт.
