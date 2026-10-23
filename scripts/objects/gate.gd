@tool
class_name Gate
extends LevelObject
## Врата-выход. target — имя локации или "end" (конец пути), spawn — точка появления там.

@export var target := "end"
@export var spawn := ""
@export_enum("forest", "town", "barrow") var style := "forest"

var locked := false:
	set(v):
		locked = v
		if is_node_ready():
			refresh()


func _setup() -> void:
	if style == "town":
		bw = 80
		bh = 112
	else:
		bw = 48
		bh = 64
	bx = position.x + 8 - bw / 2
	by = position.y - bh


func refresh() -> void:
	show_strip(OBJECTS, "gate_barrow_locked" if style == "barrow" and locked else "gate_" + style)


func hint() -> String:
	if locked:
		return "заперто"
	return "войти" if target == "end" else "в путь"


func interact(world) -> void:
	if locked:
		world.toast("Заперто. Хозяин кургана ещё не повержен", Pal.RED)
		Audio.sfx("deny")
	else:
		world.leave(target, spawn)
