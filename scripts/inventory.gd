class_name Inventory
extends RefCounted
## Сума, снаряжение, серебро, уровень и очки, заточка оружия, выученные руны.
## Как Inventory в Pyxel-версии; to_dict/from_dict — тот же формат сохранения.

const BAG_COLS := 6
const BAG_ROWS := 4
const BAG_SIZE := BAG_COLS * BAG_ROWS
const MAX_STACK := 9
const STATS := ["str", "sta", "vit", "spi"]
const STAT_NAMES := {"str": "Сила", "sta": "Стойкость", "vit": "Здоровье", "spi": "Дух"}

var bag := []  # [id, число] или null
var equipment := {}
var silver := 0
var level := 1
var xp := 0
var points := 0
var stats := {}
var upgrades := {}  # id оружия -> заточка (+1..+3)
var spells := []  # выученные руны (id предметов вида rune)
var active_spell := 0


func _init() -> void:
	bag.resize(BAG_SIZE)
	for slot in Items.SLOTS:
		equipment[slot] = null
	for s in STATS:
		stats[s] = 0


static func _prog() -> Dictionary:
	return Data.table("progression")


static func xp_needed(lvl: int) -> int:
	var l: Dictionary = _prog().levels
	return int(l.xp_base) + int(l.xp_step) * (lvl - 1)


static func stat_hints() -> Dictionary:
	var s: Dictionary = _prog().stats
	return {"str": "атака +%d" % s.strength, "sta": "силы +%d" % s.endurance,
			"vit": "жизнь +%d" % s.vitality, "spi": "мана +%d, чары +1" % s.spirit}


static func max_upgrade() -> int:
	return int(_prog().forge.max_upgrade)


# ------------------------------------------------------------ сума
## Кладёт предмет в суму; false — места нет. Руны не занимают места — сразу запоминаются.
func add(id: String, count := 1) -> bool:
	var it := Items.get_item(id)
	if it.kind == "rune":
		if not id in spells:
			spells.append(id)
		return true
	if Items.stackable(it):
		for cell in bag:
			if cell and cell[0] == id and cell[1] + count <= MAX_STACK:
				cell[1] += count
				return true
	for i in bag.size():
		if bag[i] == null:
			bag[i] = [id, count]
			return true
	return false


func remove_at(index: int, count := 1) -> void:
	var cell = bag[index]
	if cell == null:
		return
	cell[1] -= count
	if cell[1] <= 0:
		bag[index] = null


## Предмет в ячейке или пустой словарь.
func item_at(index: int) -> Dictionary:
	var cell = bag[index]
	return Items.get_item(cell[0]) if cell else {}


func count_at(index: int) -> int:
	var cell = bag[index]
	return int(cell[1]) if cell else 0


## Индекс самого слабого лечащего предмета (чтобы зря не тратить мёд); -1 — нет.
func first_consumable() -> int:
	var best := -1
	for i in bag.size():
		if bag[i]:
			var it := Items.get_item(bag[i][0])
			if it.heal and (best < 0 or it.heal < item_at(best).heal):
				best = i
	return best


# ------------------------------------------------------------ снаряжение
## Надетый предмет или пустой словарь.
func equipped(slot: String) -> Dictionary:
	var id = equipment.get(slot)
	return Items.get_item(id) if id else {}


## Надевает предмет из сумы; снятый встаёт на его место.
func equip_from_bag(index: int) -> bool:
	var it := item_at(index)
	if it.is_empty() or not equipment.has(it.kind):
		return false
	var previous = equipment[it.kind]
	equipment[it.kind] = it.id
	bag[index] = [previous, 1] if previous else null
	return true


func unequip(slot: String) -> bool:
	var id = equipment.get(slot)
	if not id:
		return false
	for i in bag.size():
		if bag[i] == null:
			bag[i] = [id, 1]
			equipment[slot] = null
			return true
	return false


func count_of(id: String) -> int:
	var n := 0
	for c in bag:
		if c and c[0] == id:
			n += int(c[1])
	return n


## Забирает count штук предмета (с разных ячеек); false — не хватает.
func take(id: String, count: int) -> bool:
	if count_of(id) < count:
		return false
	for i in bag.size():
		var cell = bag[i]
		while cell and cell[0] == id and count > 0:
			remove_at(i)
			count -= 1
			cell = bag[i]
	return true


# ------------------------------------------------------------ опыт и уровни
## Начисляет опыт; возвращает число полученных уровней.
func add_xp(amount: int) -> int:
	var l: Dictionary = _prog().levels
	var gained := 0
	xp += amount
	while level < int(l.max_level) and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		points += int(l.get("points_per_level", 1))
		gained += 1
	return gained


func spend_point(stat: String) -> bool:
	if points <= 0 or not stats.has(stat):
		return false
	points -= 1
	stats[stat] += 1
	return true


# ------------------------------------------------------------ заточка оружия
func upgrade_level(id) -> int:
	return int(upgrades.get(id, 0)) if id else 0


func item_name(it: Dictionary) -> String:
	var lvl := upgrade_level(it.id) if it.kind == "weapon" else 0
	return "%s +%d" % [it.name, lvl] if lvl else it.name


func item_atk(it: Dictionary) -> int:
	return int(it.atk) + (upgrade_level(it.id) if it.kind == "weapon" else 0)


## Цена следующей ступени [серебро, крицы] или [] — выше некуда.
func upgrade_cost(id: String) -> Array:
	var lvl := upgrade_level(id)
	var costs: Array = _prog().forge.cost
	if lvl >= max_upgrade() or lvl >= costs.size():
		return []
	return [int(costs[lvl][0]), int(costs[lvl][1])]


## Заточить оружие на +1. Возвращает текст ошибки или "" при успехе.
func upgrade(id: String) -> String:
	var cost := upgrade_cost(id)
	if cost.is_empty():
		return "Лучше уже не выковать"
	if silver < cost[0]:
		return "Не хватает серебра"
	if count_of("ore") < cost[1]:
		return "Не хватает криц"
	silver -= cost[0]
	take("ore", cost[1])
	upgrades[id] = upgrade_level(id) + 1
	return ""


# ------------------------------------------------------------ показатели
func _sum(field: String) -> int:
	var total := 0
	for slot in Items.SLOTS:
		var it := equipped(slot)
		if not it.is_empty():
			total += int(it[field])
	return total


func max_hp() -> int:
	return int(_prog().base.hp) + _sum("hp") + stats.vit * int(_prog().stats.vitality)


func attack() -> int:
	var weapon := equipped("weapon")
	var bonus := upgrade_level(weapon.id) if not weapon.is_empty() else 0
	return int(_prog().base.attack) + _sum("atk") + bonus + stats.str * int(_prog().stats.strength)


func defense() -> int:
	return int(_prog().base.defense) + _sum("defense")


func max_stamina() -> int:
	return int(_prog().base.stamina) + stats.sta * int(_prog().stats.endurance)


func max_mana() -> int:
	return int(_prog().base.mana) + stats.spi * int(_prog().stats.spirit)


func knows(rune: String) -> bool:
	return rune in spells


## Выбранная руна или "".
func spell() -> String:
	return spells[active_spell % spells.size()] if not spells.is_empty() else ""


func next_spell() -> String:
	if not spells.is_empty():
		active_spell = (active_spell + 1) % spells.size()
	return spell()


# ------------------------------------------------------------ сохранение
func to_dict() -> Dictionary:
	return {"bag": bag.duplicate(true), "equipment": equipment.duplicate(), "silver": silver,
			"level": level, "xp": xp, "points": points, "stats": stats.duplicate(),
			"upgrades": upgrades.duplicate(), "spells": spells.duplicate(), "active_spell": active_spell}


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	var cells: Array = d.get("bag", [])
	for i in mini(cells.size(), BAG_SIZE):
		var cell = cells[i]
		if cell and Items.has(cell[0]):
			inv.bag[i] = [cell[0], int(cell[1])]
	var eq: Dictionary = d.get("equipment", {})
	for slot in eq:
		if inv.equipment.has(slot) and Items.has(eq[slot]):
			inv.equipment[slot] = eq[slot]
	inv.silver = int(d.get("silver", 0))
	inv.level = maxi(1, int(d.get("level", 1)))
	inv.xp = int(d.get("xp", 0))
	inv.points = int(d.get("points", 0))
	var st: Dictionary = d.get("stats", {})
	for s in st:
		if inv.stats.has(s):
			inv.stats[s] = int(st[s])
	var up: Dictionary = d.get("upgrades", {})
	for k in up:
		if Items.has(k):
			inv.upgrades[k] = mini(max_upgrade(), int(up[k]))
	for s in d.get("spells", []):
		if Items.has(s):
			inv.spells.append(s)
	inv.active_spell = int(d.get("active_spell", 0))
	return inv


static func starting() -> Inventory:
	var inv := Inventory.new()
	var start: Dictionary = _prog().get("start", {})
	inv.equipment["weapon"] = start.get("weapon")
	inv.equipment["armor"] = start.get("armor")
	for pair in start.get("items", []):
		inv.add(pair[0], int(pair[1]))
	return inv
