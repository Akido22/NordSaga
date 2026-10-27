class_name World
extends Node2D
## Мир одной локации: уровень, герой, объекты, эффекты, камера. Логика — кадрами в tick(),
## порядок как в Pyxel-версии: ввод -> (стоп-кадр) -> герой -> враги -> объекты ->
## взаимодействие -> частицы -> камера.

signal exit_requested(target: String, spawn: String)
## Открыть окно поверх игры: "rest" (камень/стела) или "npc" (меню торговца).
signal ui_requested(kind: String, target: Node)

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const LEVELS := "res://scenes/levels/%s.tscn"
const LOOK_AHEAD := 48.0  # камера смотрит вперёд по ходу героя
const CAM_LERP := 0.12
const INTERACT_DIST := 28.0
## Сдвиг врага по x от левого края тайла метки, как в Pyxel-версии (x2).
const ENEMY_OFFSETS := {"wolf": -6.0, "draugr": 0.0, "shield_draugr": 0.0, "archer": 0.0, "dummy": -2.0, "jarl": -8.0}

## Имя локации из scenes/levels или полный путь к сцене (тесты).
@export var level_name := "town"
## Точка появления (имя из Spawns); пусто — Start.
@export var spawn := ""
## Песочница и сцены без корня игры: павший герой встаёт на старте.
## В игре (game.gd) — false: после гибели открывается экран смерти.
var respawn_after_death := true
## false — без врагов (сверка одного движения героя).
var spawn_enemies := true

var t := 0
var level: Level
var player: Player
var effects: Effects
var camera: Camera2D
var hud: CanvasLayer
var cam := Vector2.ZERO

var chests: Array[Chest] = []
var save_points: Array[SavePoint] = []
var signs: Array[Sign] = []
var gates: Array[Gate] = []
var edge_exits: Array[EdgeExit] = []
var pickups: Array[Pickup] = []
var props: Array = []
var npcs: Array = []
var enemies: Array = []
var pending_enemies: Array = []
var projectiles: Array = []  # стрелы, ударные волны, огонь — шаг 6–7
var hitstop := 0  # «стоп-кадр» при сильных попаданиях
var shake_t := 0
var hidden_chest: Chest = null  # награда за босса — появится после победы
var boss_defeated := false
var boss: JarlBoss = null
var arena_trigger := -1.0  # x, за которым босс просыпается; -1 — арены нет
var arena_door: Array[Vector2i] = []  # тайлы решётки
var door_drop := 0.0  # 0 — решётка поднята, 1 — опущена
## Для сверки с Pyxel: состояние детерминированного генератора; -1 — обычный randf().
var scripted_rng := -1

var near: LevelObject = null  # ближайший объект для взаимодействия
var talk_npc: Npc = null
var title_t := 180  # показ названия локации
var banner = null  # [заголовок, подзаголовок] вместо названия локации
var toasts := []  # [текст, цвет, жизнь]
var texts := []  # всплывающие надписи [x, y, текст, цвет, жизнь]
var exit_to = null
var finished := false
var ui_request = null  # [вид, объект] — окно, которое надо открыть после кадра
var lost_pile: LostSilver = null  # серебро, оброненное при прошлой гибели

var _overlay: Node2D  # подсказки и надписи в мире — поверх всего


func _ready() -> void:
	level = load(level_name if level_name.begins_with("res://") else LEVELS % level_name).instantiate()
	add_child(level)
	GameState.level = level_name
	_collect_objects()

	player = PLAYER_SCENE.instantiate()
	player.z_index = 10
	add_child(player)
	if GameState.pos != null:
		player.place(GameState.pos + Vector2(0, player.h))
	else:
		player.place(level.spawn_point(spawn if spawn else str(GameState.spawn if GameState.spawn else "")))
	GameState.pos = null
	GameState.hp = clampi(GameState.hp, 1, GameState.max_hp())
	var lost = GameState.lost_silver
	if lost is Dictionary and lost.get("level") == level_name and int(lost.get("amount", 0)) > 0:
		lost_pile = LostSilver.new(float(lost.x), float(lost.y) + player.h, int(lost.amount))
		lost_pile.z_index = 8
		add_child(lost_pile)

	effects = Effects.new()
	effects.z_index = 20
	add_child(effects)
	_overlay = Node2D.new()
	_overlay.z_index = 50
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	hud = HUD_SCRIPT.new()
	hud.world = self
	add_child(hud)
	cam = _target_cam()
	Audio.music(level.music)
	_sync()


func _collect_objects() -> void:
	var b: Dictionary = level.boss
	boss_defeated = not b.is_empty() and GameState.flags.has("boss:" + str(b.boss))
	if not b.is_empty():
		arena_trigger = int(b.get("arena_trigger", 0)) * Level.TILE
		var d: Array = b.get("arena_door", [])
		if d.size() == 3:
			for ty in range(int(d[1]), int(d[2]) + 1):
				arena_door.append(Vector2i(int(d[0]), ty))
	for o in level.objects():
		if o is Pickup:
			var uid := "%s%d,%d" % ["o" if o.kind == "coin" else "h", roundi(o.x / Level.TILE), roundi((o.y + o.h) / Level.TILE) - 1]
			if GameState.collected.has(key(uid)):
				o.queue_free()
				continue
			o.uid = uid
			pickups.append(o)
		elif o is Chest:
			if GameState.chests.has(key(o.uid)):
				o.loot = PackedStringArray(GameState.chests[key(o.uid)])
				o.opened = o.loot.is_empty()
				o.refresh()
			if not b.is_empty() and o.uid == str(b.get("boss_chest")) and not boss_defeated:
				hidden_chest = o
				o.visible = false
			else:
				chests.append(o)
		elif o is SavePoint:
			o.active = key(o.uid) == GameState.save_point
			o.refresh()
			save_points.append(o)
		elif o is Sign:
			signs.append(o)
		elif o is Gate:
			if not b.is_empty():
				o.locked = not boss_defeated
			gates.append(o)
		elif o is EdgeExit:
			edge_exits.append(o)
	props = level.props()
	npcs = level.npcs()
	for m in level.enemy_markers():
		if not spawn_enemies or (m.kind == "jarl" and boss_defeated):
			continue
		var e := _make_enemy(m.kind)
		e.z_index = 9
		add_child(e)
		e.place_on_tile(m.tx, m.ty, ENEMY_OFFSETS[m.kind])
		enemies.append(e)
		if e is JarlBoss:
			boss = e
	var door := Node2D.new()
	door.z_index = 5
	door.name = "ArenaDoor"
	door.draw.connect(_draw_arena_door.bind(door))
	add_child(door)


func _make_enemy(kind: String) -> Enemy:
	match kind:
		"wolf": return Wolf.new()
		"draugr": return Draugr.new()
		"shield_draugr": return ShieldDraugr.new()
		"archer": return Archer.new()
		"jarl": return JarlBoss.new()
	return Dummy.new()


func key(uid: String) -> String:
	return GameState.key(level_name, uid)


# ------------------------------------------------------------ цикл
func _physics_process(_delta: float) -> void:
	tick()


func tick() -> void:
	t += 1
	player.poll_input()
	if hitstop > 0:
		hitstop -= 1
		return
	player.tick(self)
	if player.dead and player.dead_t > 150 and respawn_after_death:
		_respawn()
	for e in enemies:
		e.tick(self)
	for e in enemies.filter(func(e): return e.dead):
		e.queue_free()
	enemies = enemies.filter(func(e): return not e.dead) + pending_enemies
	pending_enemies = []
	var closing := not arena_door.is_empty() and level.blocked.has(arena_door[0])
	door_drop = minf(1.0, door_drop + 0.08) if closing else maxf(0.0, door_drop - 0.03)
	for pr in projectiles:
		pr.tick(self)
	for pr in projectiles.filter(func(pr): return pr.dead):
		pr.queue_free()
	projectiles = projectiles.filter(func(pr): return not pr.dead)
	for o in props:
		o.tick(self)
	for o in npcs:
		o.tick(self)
	for pk in pickups:
		pk.tick(self)
	for pk in pickups.filter(func(p): return p.taken):
		pk.queue_free()
	pickups = pickups.filter(func(p): return not p.taken)
	if talk_npc != null and not talk_npc.talking:
		talk_npc = null
	if title_t > 0:
		title_t -= 1
	_interactions()

	effects.tick()
	for tx in texts:
		tx[1] -= 0.8
		tx[4] -= 1
	texts = texts.filter(func(tx): return tx[4] > 0)
	for ts in toasts:
		ts[2] -= 1
	toasts = toasts.filter(func(ts): return ts[2] > 0)
	if shake_t > 0:
		shake_t -= 1
	cam += (_target_cam() - cam) * CAM_LERP
	_sync()
	if ui_request != null:
		var req = ui_request
		ui_request = null
		ui_requested.emit(req[0], req[1])


func _interactions() -> void:
	near = null
	if player.dead:
		return
	var p := player
	var best := INTERACT_DIST
	for o in chests + save_points + signs + gates + npcs:
		var d := absf(o.center_x() - p.cx)
		if d < best + o.bw / 2 and absf((o.by + o.bh) - (p.y + p.h)) < 24:
			near = o
			best = d
	if near != null and Controls.pressed("move_up"):
		near.interact(self)
	if Controls.pressed("heal"):
		use_heal_item()
	if Controls.pressed("next_rune"):
		var rune := GameState.inv.next_spell()
		if rune:
			toast("Руна: " + Items.get_item(rune).name, Pal.FJORD)
			Audio.sfx("move")
	for ex in edge_exits:
		if exit_to == null and ex.overlaps(p.x, p.y, p.w, p.h):
			leave(ex.target, ex.spawn)
	if lost_pile != null and lost_pile.overlaps(p.x, p.y, p.w, p.h):
		GameState.inv.silver += lost_pile.amount
		toast("Серебро возвращено: %d" % lost_pile.amount, Pal.GOLD)
		Audio.sfx("coin")
		sparks(lost_pile.x + 10, lost_pile.y, 12)
		GameState.lost_silver = null
		lost_pile.queue_free()
		lost_pile = null


func _respawn() -> void:
	var fresh: Player = PLAYER_SCENE.instantiate()
	fresh.z_index = player.z_index
	player.queue_free()
	player = fresh
	add_child(player)
	GameState.hp = GameState.max_hp()
	player.place(level.spawn_point(spawn))


func _sync() -> void:
	player.sync()
	for e in enemies:
		e.sync()
	for pr in projectiles:
		pr.sync()
	get_node("ArenaDoor").queue_redraw()
	var jitter := randi_range(-1, 1) * mini(2, shake_t) * 2 if shake_t > 0 else 0
	camera.position = Vector2(int(cam.x) + jitter, int(cam.y))
	_overlay.queue_redraw()


func _target_cam() -> Vector2:
	var view := get_viewport_rect().size
	var tx := player.cx - view.x / 2 + player.facing * LOOK_AHEAD
	var ty := player.cy - view.y * 0.6
	return Vector2(clampf(tx, 0, maxf(0, level.pixel_w - view.x)), clampf(ty, 0, maxf(0, level.pixel_h - view.y)))


# ------------------------------------------------------------ события
func toast(text: String, col := Pal.LINEN) -> void:
	toasts.append([text, col, 150])
	toasts = toasts.slice(-3)


func float_text(x: float, y: float, text: String, col: Color) -> void:
	texts.append([x, y, text, col, 40])


func shake(amount: int) -> void:
	shake_t = maxi(shake_t, amount)


func freeze(frames: int) -> void:
	hitstop = maxi(hitstop, frames)


## Случайное число 0..1. Для сверки с Pyxel — детерминированный генератор (как в эталоне).
func rand() -> float:
	if scripted_rng < 0:
		return randf()
	scripted_rng = (scripted_rng * 1103515245 + 12345) % 2147483648
	return scripted_rng / 2147483648.0


func add_projectile(pr: Node2D) -> void:
	add_child(pr)
	projectiles.append(pr)
	pr.sync()


func smoke(x: float, y: float, n := 12) -> void:
	effects.smoke(x, y, n)


## Вещь или монета, выпавшая из врага: (x, y) — левый верхний угол.
func drop(kind: String, x: float, y: float, vx: float, vy: float) -> void:
	var pk := Pickup.new()
	pk.kind = kind
	pk.floating = false
	pk.position = Vector2(x, y + 16)  # узел Pickup стоит на низу своего тайла
	pk.vx = vx
	pk.vy = vy
	add_child(pk)
	pickups.append(pk)


func gain_xp(amount: int, x: float, y: float) -> void:
	var levels := GameState.inv.add_xp(amount)
	float_text(x, y - 20, "+%d опыта" % amount, Pal.MOSS)
	if levels:
		toast("Новый уровень: %d! Поклонись Стеле или камню" % GameState.inv.level, Pal.GOLD)
		Audio.sfx("save")


## Серебро остаётся на месте гибели; в сохранении пропадает только оно.
func on_player_died() -> void:
	var amount := GameState.inv.silver
	var lost = {"level": level_name, "x": player.safe_x, "y": player.safe_y, "amount": amount} if amount > 0 else null
	GameState.lost_silver = lost
	var data = SaveSystem.load_data()
	if data != null:
		data["inventory"]["silver"] = 0
		data["lost_silver"] = lost
		SaveSystem.write(data)


func on_enemy_killed(e: Enemy) -> void:
	smoke(e.cx, e.cy)
	shake(2)
	if e.xp:
		gain_xp(e.xp, e.cx, e.y)
	if randf() < e.ore_chance:
		drop("ore", e.cx - 8, e.y, randf_range(-1.6, 1.6), -4.4)
	for i in randi_range(int(e.silver[0]), int(e.silver[1])):
		drop("coin", e.cx - 8, e.y, randf_range(-2.4, 2.4), randf_range(-5.6, -3.2))
	if randf() < e.bread_chance:
		drop("bread", e.cx - 8, e.y, 0, -5.0)


## Герой вошёл на арену: решётка падает, звучит боевая музыка.
func start_boss_fight(b: JarlBoss) -> void:
	for c in arena_door:
		level.blocked[c] = true
	Audio.sfx("slam")
	Audio.music("boss")
	shake(4)
	show_banner(b.boss_name, b.subtitle)


## Ярость ярла: из тьмы по краям арены выходят волки.
func summon_wolves() -> void:
	var ground := boss.y + boss.h
	var left: float = (arena_door[0].x + 2) * Level.TILE if not arena_door.is_empty() else boss.x - 240
	var right: float = level.pixel_w - 5 * Level.TILE
	for x in [left, right]:
		var wolf := Wolf.new()
		wolf.z_index = 9
		add_child(wolf)
		wolf.x = x
		wolf.y = ground - wolf.h
		wolf.facing = 1 if x < boss.x else -1
		wolf.sync()
		pending_enemies.append(wolf)
		smoke(x + 14, ground - 12, 8)


func on_boss_defeated(b: JarlBoss) -> void:
	GameState.flags[b.flag] = true
	boss_defeated = true
	for c in arena_door:
		level.blocked.erase(c)
	for g in gates:
		g.locked = false
	if hidden_chest != null:
		chests.append(hidden_chest)
		hidden_chest.visible = true
		sparks(hidden_chest.bx + 16, hidden_chest.by + 8, 16)
		hidden_chest = null
	gain_xp(b.xp, b.cx, b.y)
	for i in int(b.silver[0]):
		drop("coin", b.cx - 8, b.y + 20, randf_range(-3.2, 3.2), randf_range(-6.8, -3.6))
	smoke(b.cx, b.cy, 24)
	Audio.music(level.music)
	show_banner("ЯРЛ ПОВЕРЖЕН", "Курган открыт")
	save_game()


func show_banner(title: String, subtitle := "") -> void:
	banner = [title, subtitle]
	title_t = 180


func dust(x: float, y: float, n := 5) -> void:
	effects.dust(x, y, n)


func sparks(x: float, y: float, n := 6) -> void:
	effects.sparks(x, y, n)


func collect(pk: Pickup) -> void:
	if pk.kind == "coin":
		GameState.inv.silver += 1
		Audio.sfx("coin")
	else:
		if not GameState.add_item(pk.kind):
			if pk.age % 120 == 21:
				toast("Сума полна!", Pal.RED)
			return
		toast("Получено: " + Data.table("items")[pk.kind].name, Pal.GOLD)
		Audio.sfx("coin")
	pk.taken = true
	if pk.uid:
		GameState.collected[key(pk.uid)] = true
	sparks(pk.x + 8, pk.y + 8, 4)


func activate_save_point(sp: SavePoint) -> void:
	for o in save_points:
		o.active = o == sp
		o.refresh()
	GameState.save_point = key(sp.uid)
	GameState.hp = GameState.max_hp()
	player.mana = GameState.max_mana()
	save_game()
	ui_request = ["rest", sp]


## Съесть самый слабый лечащий припас (Q).
func use_heal_item() -> void:
	var inv := GameState.inv
	if GameState.hp >= inv.max_hp():
		toast("Ты и так полон сил", Pal.STEEL)
		Audio.sfx("deny")
		return
	var idx := inv.first_consumable()
	if idx < 0:
		toast("В суме нет припасов", Pal.STEEL)
		Audio.sfx("deny")
		return
	var it := inv.item_at(idx)
	var healed := player.heal(int(it.heal))
	inv.remove_at(idx)
	float_text(player.cx, player.y - 8, "+%d" % healed, Pal.MOSS)
	toast("%s: +%d" % [it.name, healed], Pal.MOSS)
	Audio.sfx("heal")


## Начать или продолжить разговор с жителем.
func start_talk(npc: Npc) -> void:
	npc.talk()
	talk_npc = npc if npc.talking else null
	Audio.sfx("move")


func save_game() -> bool:
	var ok := SaveSystem.write(GameState.to_save(level_name, Vector2(player.safe_x, player.safe_y)))
	toast("Путь сохранён" if ok else "Не удалось сохранить!", Pal.GOLD if ok else Pal.RED)
	if ok:
		Audio.sfx("save")
	return ok


## Уйти в другую локацию (target, точка появления) или в конец пути ("end").
func leave(target: String, spawn_name: String) -> void:
	if target == "end":
		finished = true
		return
	exit_to = [target, spawn_name]
	exit_requested.emit(target, spawn_name)


# ------------------------------------------------------------ отрисовка
## Кованая решётка арены, падающая сверху.
func _draw_arena_door(c: Node2D) -> void:
	if door_drop <= 0 or arena_door.is_empty():
		return
	var x := arena_door[0].x * Level.TILE
	var top := arena_door[0].y * Level.TILE
	var full := arena_door.size() * Level.TILE
	var hh := int(full * door_drop)
	c.draw_rect(Rect2(x - 2, top - 6, 20, 6), Pal.DARK_WOOD)
	for bx in [x, x + 6, x + 12]:
		c.draw_rect(Rect2(bx, top, 2, hh), Pal.STEEL)
		c.draw_rect(Rect2(bx, top + hh, 2, 2), Pal.SNOW)
	for yy in range(top + 12, top + hh, 24):
		c.draw_rect(Rect2(x - 2, yy, 20, 2), Pal.STONE)


func _draw_overlay() -> void:
	for tx in texts:
		UiKit.text_center(_overlay, tx[0], tx[1], tx[2], tx[3], Pal.NIGHT)
	if near != null and not player.dead:
		var hint := near.hint()
		if hint:
			var bob := (t / 15) % 2
			UiKit.text_center(_overlay, near.center_x(), near.by - 22 - bob * 2, "↑ " + hint, Pal.SNOW, Pal.NIGHT)
