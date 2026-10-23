@tool
class_name SavePoint
extends LevelObject
## Рунный камень или Стела Предков: восстанавливает силы и сохраняет путь.

@export_enum("runestone", "stela") var kind := "runestone"

var active := false


func _setup() -> void:
	if kind == "stela":
		bw = 96
		bh = 192
		bx = position.x + 8 - bw / 2
	else:
		bw = 32
		bh = 32
		bx = position.x - 8
	by = position.y - bh


func refresh() -> void:
	show_strip(OBJECTS, kind + ("_active" if active else ""))


func hint() -> String:
	return "поклониться" if kind == "stela" else "сохранить"


func interact(world) -> void:
	world.activate_save_point(self)
	world.float_text(world.player.cx, world.player.y - 8, "ПРЕДКИ" if kind == "stela" else "РУНЫ", Pal.GOLD)
