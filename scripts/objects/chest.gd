@tool
class_name Chest
extends LevelObject
## Сундук: при открытии кладёт добычу в суму; что не влезло — остаётся внутри.

@export var loot: PackedStringArray = []

var opened := false


func _setup() -> void:
	bw = 32
	bh = 24
	bx = position.x - 8
	by = position.y - bh


func refresh() -> void:
	show_strip(OBJECTS, "chest_open" if opened else "chest_closed")


func hint() -> String:
	return "" if opened else "открыть"


func interact(world) -> void:
	if opened:
		return
	Audio.sfx("chest")
	var left := PackedStringArray()
	var items: Dictionary = Data.table("items")
	for id in loot:
		if GameState.add_item(id):
			var it: Dictionary = items[id]
			world.toast(("Выучена: " if it.kind == "rune" else "Получено: ") + it.name, Pal.GOLD)
		else:
			left.append(id)
	loot = left
	opened = left.is_empty()
	if not left.is_empty():
		world.toast("Сума полна! Освободи место", Pal.RED)
	GameState.chests[world.key(uid)] = Array(loot)
	world.sparks(bx + 16, by + 4, 10)
	refresh()
