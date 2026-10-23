extends Node
## Корень игры: держит текущий мир и переключает локации.
## Главное меню и загрузка сохранения — шаг 8; пока сразу новая игра в Велеграде.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var world: World


func _ready() -> void:
	GameState.reset()
	enter(GameState.level, str(GameState.spawn))


## Войти в локацию level_name в точке spawn.
func enter(level_name: String, spawn: String) -> void:
	if world:
		remove_child(world)
		world.queue_free()
	world = WORLD_SCENE.instantiate()
	world.level_name = level_name
	world.spawn = spawn
	world.exit_requested.connect(_on_exit)
	add_child(world)


func _on_exit(target: String, spawn: String) -> void:
	GameState.level = target
	GameState.spawn = spawn
	enter.call_deferred(target, spawn)
