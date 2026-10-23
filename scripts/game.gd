extends Node
## Корень игры: держит текущий мир, переключает локации и открывает окна поверх
## игры (отдых, торговец, лавка). Главное меню и загрузка сохранения — шаг 8;
## пока сразу новая игра в Велеграде.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var world: World
var overlay: Overlay


func _ready() -> void:
	GameState.reset()
	enter(GameState.level, str(GameState.spawn))


## Войти в локацию level_name в точке spawn.
func enter(level_name: String, spawn: String) -> void:
	close_overlay()
	if world:
		remove_child(world)
		world.queue_free()
	world = WORLD_SCENE.instantiate()
	world.level_name = level_name
	world.spawn = spawn
	world.exit_requested.connect(_on_exit)
	world.ui_requested.connect(_on_ui)
	add_child(world)


func _on_exit(target: String, spawn: String) -> void:
	GameState.level = target
	GameState.spawn = spawn
	enter.call_deferred(target, spawn)


func _on_ui(kind: String, target: Node) -> void:
	match kind:
		"rest": open_overlay(RestMenu.new(target))
		"npc": open_overlay(NpcMenu.new(target))


## Открыть окно (прежнее закрывается); мир стоит, пока окно открыто.
func open_overlay(ov: Overlay) -> void:
	if overlay:
		overlay.queue_free()
	overlay = ov
	overlay.game = self
	overlay.world = world
	world.set_physics_process(false)
	add_child(overlay)


func close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	if world:
		world.set_physics_process(true)
