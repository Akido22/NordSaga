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
6. Враги и ярл Хрёрек ✔
7. Прокачка, руны, жители, лавки, кузница ✔
8. Интерфейс и сохранение: главное меню, пауза, сума, смерть, победа, затемнения ✔
9. Android: экранное управление, экспорт APK — 9а (управление, пресет экспорта) ✔, сборка и проверка на телефоне
10. Новая графика

## Структура

```
scenes/    game.tscn (корень: меню, смена локаций, окна), world, levels (town, test_level, barrow, arena),
           player, enemies, bosses, ui, debug
scripts/   autoload; physics (TileBody — тайловая физика); world (World, Level, Effects);
           objects (объекты уровня, LostSilver — серебро на месте гибели); enemies (Enemy; Wolf, Draugr, ShieldDraugr, Archer + Arrow,
           JarlBoss + Shockwave, Dummy; Looks — облики врагов);
           characters (HumanoidLook — гуманоид из слоёв);
           magic (Spells — действие рун, Fireball); ui (UiKit, HudLayer, MenuList, окна Overlay:
           TitleMenu, PauseMenu, InventoryMenu, ControlsMenu, DeathMenu, VictoryMenu;
           TouchControls — экранный стик и кнопки;
           NpcMenu, TradeMenu, RestMenu); shaders (перекраска по палитре);
           inventory.gd (Inventory — сума, снаряжение, уровень, заточка, руны), items.gd (Items),
           palette.gd (Pal), strips.gd (Strips — анимации из лент), icons.gd (Icons)
data/      баланс (TOML и собранный JSON в data/json), levels/*.txt — карты из Pyxel-версии
assets/    tiles, sprites (characters, objects, props, icons), backgrounds, fonts, audio/sfx, audio/music
tests/     автопроверки; levels — площадки для сверки врагов (duel_*)
tools/     конвертеры
```

Глобальные скрипты (autoload):

| | |
|---|---|
| `Controls` | действия ввода: клавиатура (физические клавиши — WASD работает и на русской раскладке) и геймпад; F11 — во весь экран |
| `Data` | таблицы баланса из `data/json` |
| `GameState` | состояние похода: сума (`inv`), здоровье, сундуки, флаги |
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
| `Enemies` | метки врагов `EnemyMarker`: wolf, draugr, shield_draugr, archer, dummy, jarl |
| `Spawns` | точки появления; `Start` — старт героя |

У корня — название, подзаголовок, фон, музыка, размер в тайлах и описание арены
босса (`boss`: id, столбец, за которым босс просыпается, решётка, сундук-награда). Объект ставится на левый нижний угол своего тайла (сетка 16 px).

Сцены были собраны из карт Pyxel-версии (`data/levels/*.txt`) импортёром
`godot --headless --path . res://tools/import_levels.tscn` — **повторный импорт
затирает правки, сделанные в редакторе.** Он же собирает площадки тестов
`tests/levels/*.txt` -> `tests/levels/*.tscn`.

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
| В окнах: выбор / назад | Enter / Пробел / Z, Esc / Backspace / X | A, B |
| В суме: выбросить | R / Delete | Y |
| Во весь экран | F11 | |

## Android

На телефоне (и на ПК с ключом `-- --touch`, мышь вместо пальца) поверх игры —
плавающий стик слева и кнопки справа: прыжок, удар, кувырок, блок, чары, смена
руны, лечение, сума, пауза. Кнопки двойные, как на геймпаде: прыжок — «выбор» в
окнах, кувырок — «назад», чары — «выбросить». Стик вверх — говорить и открывать,
вниз + прыжок — спрыгнуть с доски. Свернули приложение — пауза; системная
«Назад» — как Esc.

Сборка APK (пресет «Android» в `export_presets.cfg`, файл — `build/android/NordSaga.apk`):
1. Шаблоны экспорта: Godot → Editor → Manage Export Templates → Download and Install.
2. Android SDK (Android Studio или command-line tools) с platform-tools,
   build-tools и платформой; JDK 17 уже стоит.
3. Godot → Editor Settings → Export → Android: пути к SDK и JDK, debug keystore
   (уже прописан).
4. Project → Export → Android → Export Project (debug), или:
   `godot --headless --path . --export-debug "Android" build/android/NordSaga.apk`.
5. Скопировать APK на телефон и установить (разрешить установку из неизвестных
   источников).

Код проекта — только GDScript, поэтому для сборки можно взять и обычный
(не .NET) Godot 4.7.2 с обычными шаблонами — APK выйдет меньше.

## Проверка

```
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --path . res://tests/movement_test.tscn
godot --headless --path . res://tests/levels_test.tscn
godot --headless --path . res://tests/combat_test.tscn
godot --headless --path . res://tests/enemies_test.tscn
godot --headless --path . res://tests/progress_test.tscn
godot --headless --path . res://tests/ui_test.tscn
godot --headless --path . res://tests/touch_test.tscn
```
- `smoke_test` — настройки, ввод, сохранение, ресурсы (`SMOKE OK`).
- `movement_test` — движение героя кадр в кадр против Pyxel-версии
  (`MOVEMENT OK`). Эталон `tests/reference/movement.json` пересобирается так:
  `python tests/reference/make_movement_reference.py D:/путь/к/NordSagePixel`.
- `combat_test` — бой героя кадр в кадр против Pyxel-версии на «Ристалище»
  (`data/levels/arena.txt`): серии ударов, тяжёлый удар, удар в падении,
  перекаты, блок, выносливость до нуля, стоп-кадры (`COMBAT OK`). Эталон:
  `python tests/reference/make_combat_reference.py D:/путь/к/NordSagePixel`.
- `enemies_test` — враги кадр в кадр против Pyxel-версии: дуэли с волком,
  драугром, драугром со щитом, лучником, стаей и бой с ярлом до победы (обе
  фазы, волки, ударные волны) — герой, каждый враг и снаряды (`ENEMIES OK`).
  Эталон: `python tests/reference/make_enemies_reference.py D:/путь/к/NordSagePixel`.
- `progress_test` — 600 случайных операций с сумой, лавками, кузней, опытом и
  очками, и бой чарами и припасами кадр в кадр против Pyxel-версии (`PROGRESS OK`).
  Эталоны: `python tests/reference/make_progress_reference.py D:/путь/к/NordSagePixel`.
- `levels_test` — тайлы сцен совпадают с картами, сундук, стела, табличка,
  разговор, монета, переходы город → тропа → курган → тропа → город (`LEVELS OK`).
- `ui_test` — настоящими кадрами и нажатиями: главное меню → новая игра → сума
  (надеть меч) → пауза (сохранить) → гибель (серебро остаётся на месте) → к месту
  сохранения → подобрать серебро → конец пути → Велеград → переход с затемнением →
  пауза → главное меню (`UI OK`).
- `touch_test` — экранное управление: стик, кнопки, мультитач, касание в пикселях
  окна, прыжок = «выбор» в меню, кувырок = «назад» (`TOUCH OK`).

Снимок любой сцены (без `--headless`), можно с удержанием действий:
```
godot --path . res://tests/smoke_test.tscn -- --shot=C:/tmp/shot.png --scene=res://scenes/world/world.tscn --level=arena --equip=weapon:sword,shield:shield_red --hold=block --frames=30
godot --path . res://tests/smoke_test.tscn -- --shot=C:/tmp/shop.png --scene=res://scenes/game.tscn --silver=120 --give=ore:3 --overlay=trade:smith:2
godot --path . res://tests/smoke_test.tscn -- --shot=C:/tmp/inv.png --scene=res://scenes/game.tscn --overlay=inventory --equip=helmet:shishak
godot --path . res://tests/smoke_test.tscn -- --shot=C:/tmp/title.png --scene=res://scenes/game.tscn --title
```
Окна для `--overlay`: `rest`, `npc:<id>`, `trade:<лавка>:<вкладка>`, `pause`, `inventory`,
`controls`, `death`, `victory`.

Главная сцена (F5) — `scenes/game.tscn`: главное меню (продолжить, новая игра,
управление). В игре: Esc — привал (сума, сохранить, управление, выйти в меню),
I — сума и снаряжение (надеть, снять, съесть, выбросить). Переходы между
локациями — с затемнением. Павший герой роняет серебро на месте гибели (в
сохранении его больше нет) — подбери, чтобы вернуть; экран смерти предлагает
вернуться к месту сохранения. Выход из кургана — экран «Путь пройден». Работают сундуки,
стела и рунные камни (сохранение), таблички, разговоры, монеты, переходы между
локациями, весь бой героя, враги на «Лесной тропе» и в кургане, ярл Хрёрек
(арена с решёткой, ярость и волки, награда после победы), добыча и опыт с убитых,
чары рун (F — сотворить, E — сменить руну), припасы (Q), отдых у стелы и камней
с распределением очков, торговцы (Торвальд, Млада, кузнец Добрыня) с лавками и
заточкой оружия.
Чучела — у тренера в Велеграде и на «Ристалище» (`scenes/levels/arena.tscn`, F6).
`scenes/debug/input_test.tscn` — проверка ввода.
`scenes/debug/asset_gallery.tscn` (F6 в редакторе) — все перенесённые ресурсы:
фон с параллаксом, постройки и объекты с анимацией, тайлы, иконки, шрифт.
