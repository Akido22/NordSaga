class_name Game
extends Node
## Корень игры: главное меню, текущий мир, переходы между локациями с затемнением,
## окна поверх игры (стопкой: пауза -> сума), экраны смерти и победы.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const FADE := 18  # кадров затемнения и проявления
const DEATH_DELAY := 90  # кадров от гибели до экрана смерти

var world: World
var overlays: Array[Overlay] = []
var overlay: Overlay:  # верхнее окно или null
	get: return overlays.back() if overlays else null
var fade_in := 0  # >0 — проявление после входа в локацию
var fade_out := 0  # >0 — затемнение перед переходом
var dead_t := 0
var _exit_to = null  # [локация, точка появления]
var _title_bg: Node2D
var _title_cam: Camera2D
var _title_dir := 1.0
var _fade_canvas: Node2D


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_fade_canvas = Node2D.new()
	_fade_canvas.draw.connect(_draw_fade)
	layer.add_child(_fade_canvas)
	show_title()


# ------------------------------------------------------------ экраны
## Главное меню поверх плывущего Велеграда.
func show_title() -> void:
	close_all()
	_drop_world()
	_title_bg = Node2D.new()
	var town: Level = load(World.LEVELS % "town").instantiate()
	_title_bg.add_child(town)
	_title_cam = Camera2D.new()
	_title_cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_title_bg.add_child(_title_cam)
	add_child(_title_bg)
	move_child(_title_bg, 0)
	_title_cam.position = Vector2(0, town.pixel_h - get_viewport().get_visible_rect().size.y)
	_title_cam.make_current()
	fade_in = FADE
	fade_out = 0
	Audio.music("town")
	open_overlay(TitleMenu.new())


func new_game() -> void:
	GameState.reset()
	enter_level(GameState.level, "start")


## Продолжить с сохранения; false — сохранения нет или оно испорчено.
func load_game() -> bool:
	var data = SaveSystem.load_data()
	if data == null:
		Audio.sfx("deny")
		return false
	GameState.from_save(data)
	enter_level(GameState.level, "")
	return true


## Войти в локацию level_name в точке spawn (пусто — точное место из сохранения).
func enter_level(level_name: String, spawn: String) -> void:
	close_all()
	_drop_world()
	GameState.level = level_name
	GameState.spawn = spawn if spawn else null
	world = WORLD_SCENE.instantiate()
	world.level_name = level_name
	world.spawn = spawn
	world.respawn_after_death = false
	world.exit_requested.connect(_on_exit)
	world.ui_requested.connect(_on_ui)
	add_child(world)
	move_child(world, 0)  # под окнами и затемнением
	fade_in = FADE
	fade_out = 0
	dead_t = 0
	_exit_to = null


func _drop_world() -> void:
	if world:
		remove_child(world)
		world.queue_free()
		world = null
	if _title_bg:
		remove_child(_title_bg)
		_title_bg.queue_free()
		_title_bg = null


# ------------------------------------------------------------ кадр
func _physics_process(_delta: float) -> void:
	if fade_in > 0:
		fade_in -= 1
	_fade_canvas.queue_redraw()
	if _title_bg:
		_pan_title()
	if world == null:
		return
	if fade_out > 0:
		fade_out -= 1
		if fade_out == 0:
			enter_level(_exit_to[0], _exit_to[1])
		return
	if overlay != null:
		return
	if Controls.pressed("pause"):
		Audio.sfx("select")
		open_overlay(PauseMenu.new())
		return
	if Controls.pressed("inventory") and not world.player.dead:
		Audio.sfx("select")
		open_overlay(InventoryMenu.new())
		return
	if world.player.dead:
		if dead_t == 0:
			world.on_player_died()
		dead_t += 1
		if dead_t > DEATH_DELAY:
			open_overlay(DeathMenu.new())
	elif world.finished:
		Audio.sfx("save")
		open_overlay(VictoryMenu.new())


func _pan_title() -> void:
	var town: Level = _title_bg.get_child(0)
	var max_x := town.pixel_w - get_viewport().get_visible_rect().size.x
	_title_cam.position.x += 0.6 * _title_dir
	if _title_cam.position.x >= max_x or _title_cam.position.x <= 0:
		_title_dir = -_title_dir
		_title_cam.position.x = clampf(_title_cam.position.x, 0, max_x)


func _on_exit(target: String, spawn: String) -> void:
	_exit_to = [target, spawn]
	fade_out = FADE
	world.set_physics_process(false)  # на время затемнения мир стоит


func _on_ui(kind: String, target: Node) -> void:
	match kind:
		"rest": open_overlay(RestMenu.new(target))
		"npc": open_overlay(NpcMenu.new(target))


func _draw_fade() -> void:
	var dark := 0.0
	if fade_in > 0:
		dark = float(fade_in) / FADE
	elif fade_out > 0:
		dark = 1.0 - float(fade_out) / FADE
	if dark > 0:
		Overlay.dim(_fade_canvas, minf(1.0, dark))


# ------------------------------------------------------------ окна
## Открыть окно вместо всех открытых; мир стоит, пока окно открыто.
func open_overlay(ov: Overlay) -> void:
	close_all()
	push_overlay(ov)


## Открыть окно поверх текущего (пауза -> сума); закрыв его, вернёмся в нижнее.
func push_overlay(ov: Overlay) -> void:
	if overlay:
		overlay.set_physics_process(false)
	ov.game = self
	ov.world = world
	overlays.append(ov)
	if world:
		world.set_physics_process(false)
	add_child(ov)
	ov.layer = 20 + overlays.size()


## Закрыть верхнее окно.
func close_overlay() -> void:
	if overlays.is_empty():
		return
	overlays.pop_back().queue_free()
	if overlay:
		overlay.skip = 1
		overlay.set_physics_process(true)
	elif world and fade_out == 0:
		world.set_physics_process(true)


func close_all() -> void:
	for ov in overlays:
		ov.queue_free()
	overlays.clear()
	if world and fade_out == 0:
		world.set_physics_process(true)
