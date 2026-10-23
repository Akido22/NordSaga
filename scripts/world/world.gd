class_name World
extends Node2D
## Мир одной локации: уровень, герой, эффекты, камера. Логика — кадрами в tick(),
## порядок как в Pyxel-версии: ввод -> герой -> частицы -> камера.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LOOK_AHEAD := 48.0  # камера смотрит вперёд по ходу героя
const CAM_LERP := 0.12

@export_file("*.txt") var level_path := "res://data/levels/test_level.txt"
## Пока нет экрана смерти (шаг 8): павший герой встаёт на старте.
var respawn_after_death := true

var level: Level
var player: Player
var effects: Effects
var camera: Camera2D
var cam := Vector2.ZERO


func _ready() -> void:
	level = Level.new()
	level.load_txt(level_path)
	add_child(level)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.place(level.start_point())
	effects = Effects.new()
	add_child(effects)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	cam = _target_cam()
	_sync()


func _physics_process(_delta: float) -> void:
	tick()


func tick() -> void:
	player.poll_input()
	player.tick(self)
	if player.dead and player.dead_t > 150 and respawn_after_death:
		_respawn()
	effects.tick()
	cam += (_target_cam() - cam) * CAM_LERP
	_sync()


func _respawn() -> void:
	var fresh: Player = PLAYER_SCENE.instantiate()
	player.queue_free()
	player = fresh
	add_child(player)
	GameState.hp = GameState.max_hp()
	player.place(level.start_point())


func _sync() -> void:
	player.sync()
	camera.position = Vector2(int(cam.x), int(cam.y))


func _target_cam() -> Vector2:
	var view := get_viewport_rect().size
	var tx := player.cx - view.x / 2 + player.facing * LOOK_AHEAD
	var ty := player.cy - view.y * 0.6
	return Vector2(clampf(tx, 0, maxf(0, level.pixel_w - view.x)), clampf(ty, 0, maxf(0, level.pixel_h - view.y)))


func dust(x: float, y: float, n := 5) -> void:
	effects.dust(x, y, n)


func sparks(x: float, y: float, n := 6) -> void:
	effects.sparks(x, y, n)
