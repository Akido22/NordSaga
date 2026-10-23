extends Node
## Состояние похода, общее для всех локаций: сума, здоровье, сундуки, находки,
## точка сохранения. Формат — как у Pyxel-версии (сохранение v2).

const START_LEVEL := "town"

var inventory := {}  # до шага 7 — словарь в формате сохранения: equipment, bag…
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
	inventory = starting_inventory()
	hp = max_hp()
	collected = {}
	chests = {}
	save_point = null
	flags = {}
	lost_silver = null
	level = START_LEVEL
	spawn = "start"
	pos = null


const BAG_SIZE := 24
const MAX_STACK := 9


## Начальная сума (data/progression.toml [start]); формат — как в сохранении.
func starting_inventory() -> Dictionary:
	var start: Dictionary = Data.table("progression").get("start", {})
	inventory = {
		"equipment": {"weapon": start.get("weapon"), "armor": start.get("armor")},
		"bag": [], "silver": 0, "spells": [],
	}
	inventory.bag.resize(BAG_SIZE)
	for pair in start.get("items", []):
		add_item(pair[0], int(pair[1]))
	return inventory


## Кладёт предмет в суму; false — места нет. Руны не занимают места — запоминаются.
## (Полная сума и снаряжение — шаг 7.)
func add_item(id: String, count := 1) -> bool:
	var it: Dictionary = Data.table("items").get(id, {})
	if it.get("kind") == "rune":
		if not id in inventory.spells:
			inventory.spells.append(id)
		return true
	var bag: Array = inventory.bag
	if it.get("kind") in ["consumable", "material"]:
		for cell in bag:
			if cell and cell[0] == id and cell[1] + count <= MAX_STACK:
				cell[1] += count
				return true
	for i in bag.size():
		if bag[i] == null:
			bag[i] = [id, count]
			return true
	return false


## id надетого предмета в ячейке (weapon, shield, helmet, armor, amulet) или "".
func equipped(slot: String) -> String:
	var item = inventory.get("equipment", {}).get(slot)
	return item if item is String else ""


## Сумма поля stat по надетым вещам (hp, atk, defense…).
func equipment_sum(stat: String) -> int:
	var total := 0
	var items: Dictionary = Data.table("items")
	for slot in inventory.get("equipment", {}):
		var id := equipped(slot)
		if id and items.has(id):
			total += int(items[id].get(stat, 0))
	return total


## Очки прокачки в показателе: str, sta, vit, spi (полная прокачка — шаг 7).
func stat(id: String) -> int:
	return int(inventory.get("stats", {}).get(id, 0))


## Заточка оружия id: 0..max_upgrade.
func upgrade_level(id: String) -> int:
	return int(inventory.get("upgrades", {}).get(id, 0))


## Наибольшая жизнь: основа + вещи + очки Живучести.
func max_hp() -> int:
	var prog: Dictionary = Data.table("progression")
	return int(prog.base.hp) + equipment_sum("hp") + stat("vit") * int(prog.stats.vitality)


## Атака: основа + вещи + заточка оружия + очки Силы.
func attack() -> int:
	var prog: Dictionary = Data.table("progression")
	var weapon := equipped("weapon")
	var bonus := upgrade_level(weapon) if weapon else 0
	return int(prog.base.attack) + equipment_sum("atk") + bonus + stat("str") * int(prog.stats.strength)


func defense() -> int:
	return int(Data.table("progression").base.defense) + equipment_sum("defense")


func max_stamina() -> int:
	var prog: Dictionary = Data.table("progression")
	return int(prog.base.stamina) + stat("sta") * int(prog.stats.endurance)


func max_mana() -> int:
	var prog: Dictionary = Data.table("progression")
	return int(prog.base.mana) + stat("spi") * int(prog.stats.spirit)


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
		"inventory": inventory,
		"collected": collected_list,
		"chests": chests,
		"save_point": save_point,
		"flags": flag_list,
		"lost_silver": lost_silver,
	}


func from_save(data: Dictionary) -> void:
	reset()
	inventory = data.get("inventory", inventory)
	hp = clampi(int(data.get("hp", hp)), 1, max_hp())
	for k in data.get("collected", []):
		collected[k] = true
	chests = data.get("chests", {})
	save_point = data.get("save_point")
	for f in data.get("flags", []):
		flags[f] = true
	lost_silver = data.get("lost_silver")
	level = data.get("level", START_LEVEL)
	var p = data.get("pos")
	pos = Vector2(p[0], p[1]) if p is Array and p.size() == 2 else null
	spawn = null
