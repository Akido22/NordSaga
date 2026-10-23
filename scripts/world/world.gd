class_name World
extends Node2D
## Мир одной локации: уровень, герой, объекты, эффекты, камера. Логика — кадрами в tick(),
## порядок как в Pyxel-версии: ввод -> (стоп-кадр) -> герой -> враги -> объекты ->
## взаимодействие -> частицы -> камера.

signal exit_requested(target: String, spawn: String)

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const LEVELS := "res://scenes/levels/%s.tscn"
const LOOK_AHEAD := 48.0  # камера смотрит вперёд по ходу героя
const CAM_LERP := 0.12
const INTERACT_DIST := 28.0
## Враги, которые уже перенесены (остальные метки ждут шага 6): вид -> сдвиг по x, как в Pyxel (x2).
const ENEMY_OFFSETS := {"dummy": -2.0}

@export var level_name := "town"
## Точка появления (имя из Spawns); пусто — Start.
@export var spawn := ""
## Пока нет экрана смерти (шаг 8): павший герой встаёт на старте.
var respawn_after_death := true

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

var near: LevelObject = null  # ближайший объект для взаимодействия
var talk_npc: Npc = null
var title_t := 180  # показ названия локации
var banner = null  # [заголовок, подзаголовок] вместо названия локации
var toasts := []  # [текст, цвет, жизнь]
var texts := []  # всплывающие надписи [x, y, текст, цвет, жизнь]
var exit_to = null
var finished := false

var _overlay: Node2D  # подсказки и надписи в мире — поверх всего


func _ready() -> void:
	level = load(LEVELS % level_name).instantiate()
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
		var e := _make_enemy(m.kind)
		if e:
			e.z_index = 9
			add_child(e)
			e.place_on_tile(m.tx, m.ty, ENEMY_OFFSETS[m.kind])
			enemies.append(e)


func _make_enemy(kind: String) -> Enemy:
	match kind:
		"dummy": return Dummy.new()
	return null


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
	for pr in projectiles:
		pr.tick(self)
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
	for ex in edge_exits:
		if exit_to == null and ex.overlaps(p.x, p.y, p.w, p.h):
			leave(ex.target, ex.spawn)


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


## Добыча, опыт и прочее — шаг 6–7.
func on_enemy_killed(e: Enemy) -> void:
	effects.smoke(e.cx, e.cy)
	shake(2)


func dust(x: float, y: float, n := 5) -> void:
	effects.dust(x, y, n)


func sparks(x: float, y: float, n := 6) -> void:
	effects.sparks(x, y, n)


func collect(pk: Pickup) -> void:
	if pk.kind == "coin":
		GameState.inventory.silver = int(GameState.inventory.get("silver", 0)) + 1
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
	save_game()


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
		toast("Конец пути. Экран победы — шаг 8", Pal.GOLD)
		return
	exit_to = [target, spawn_name]
	exit_requested.emit(target, spawn_name)


# ------------------------------------------------------------ отрисовка
func _draw_overlay() -> void:
	for tx in texts:
		UiKit.text_center(_overlay, tx[0], tx[1], tx[2], tx[3], Pal.NIGHT)
	if near != null and not player.dead:
		var hint := near.hint()
		if hint:
			var bob := (t / 15) % 2
			UiKit.text_center(_overlay, near.center_x(), near.by - 22 - bob * 2, "↑ " + hint, Pal.SNOW, Pal.NIGHT)
