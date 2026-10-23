extends Node
## Состояние похода, общее для всех локаций: сума, здоровье, сундуки, находки,
## точка сохранения. Формат — как у Pyxel-версии (сохранение v2).

const START_LEVEL := "town"

var inv: Inventory  # сума, снаряжение, уровень, руны
var hp := 10
var collected := {}  # "локация:uid" -> true, подобранные предметы с карты
var chests := {}  # "локация:uid" -> оставшаяся добыча
var save_point = null  # "локация:uid" последнего камня/стелы
var flags := {}  # например "boss:jarl" -> true
var lost_silver = null  # {"level", "x", "y", "amount"} — серебро на месте гибели
var level := START_LEVEL
var spawn = "start"
var pos = null  # Vector2 из сохранения


func _ready() -> void:
	reset()


func reset() -> void:
	inv = Inventory.starting()
	hp = inv.max_hp()
	collected = {}
	chests = {}
	save_point = null
	flags = {}
	lost_silver = null
	level = START_LEVEL
	spawn = "start"
	pos = null


# ------------------------------------------------------------ короткие обращения к суме
## id надетого предмета в ячейке (weapon, shield, helmet, armor, amulet) или "".
func equipped(slot: String) -> String:
	var id = inv.equipment.get(slot)
	return id if id is String else ""


func add_item(id: String, count := 1) -> bool:
	return inv.add(id, count)


func max_hp() -> int:
	return inv.max_hp()


func attack() -> int:
	return inv.attack()


func defense() -> int:
	return inv.defense()


func max_stamina() -> int:
	return inv.max_stamina()


func max_mana() -> int:
	return inv.max_mana()


# ------------------------------------------------------------ сохранение
static func key(level_name: String, uid: String) -> String:
	return "%s:%s" % [level_name, uid]


func to_save(level_name: String, at: Vector2) -> Dictionary:
	var collected_list := collected.keys()
	collected_list.sort()
	var flag_list := flags.keys()
	flag_list.sort()
	return {
		"level": level_name,
		"pos": [at.x, at.y],
		"hp": hp,
		"inventory": inv.to_dict(),
		"collected": collected_list,
		"chests": chests,
		"save_point": save_point,
		"flags": flag_list,
		"lost_silver": lost_silver,
	}


func from_save(data: Dictionary) -> void:
	reset()
	inv = Inventory.from_dict(data.get("inventory", {}))
	hp = clampi(int(data.get("hp", hp)), 1, inv.max_hp())
	for k in data.get("collected", []):
		collected[k] = true
	var items: Dictionary = data.get("chests", {})
	for k in items:
		chests[k] = Array(items[k]).filter(func(id): return Items.has(id))
	save_point = data.get("save_point")
	for f in data.get("flags", []):
		flags[f] = true
	lost_silver = data.get("lost_silver")
	level = data.get("level", START_LEVEL)
	var p = data.get("pos")
	pos = Vector2(p[0], p[1]) if p is Array and p.size() == 2 else null
	spawn = null
