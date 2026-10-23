class_name Items
## База предметов (data/items.toml): поля с умолчаниями, названия видов, строки свойств.

## Ячейки снаряжения в порядке отображения.
const SLOTS := ["weapon", "shield", "helmet", "armor", "amulet"]
const SLOT_NAMES := {"weapon": "Оружие", "shield": "Щит", "helmet": "Шлем", "armor": "Доспех", "amulet": "Оберег"}
const KIND_NAMES := {"weapon": "Оружие", "shield": "Щит", "helmet": "Шлем", "armor": "Доспех", "amulet": "Оберег",
		"consumable": "Припасы", "material": "Для кузни", "rune": "Руна"}
const DEFAULTS := {"desc": "", "atk": 0, "defense": 0, "hp": 0, "heal": 0, "mana": 0, "tint": {},
		"reach": 0, "swing": 0, "stamina": 0, "shield_colors": [2, 4, 6], "price": 0}

static var _cache := {}


static func has(id) -> bool:
	return id is String and Data.table("items").has(id)


## Предмет со всеми полями (id, name, kind, icon, atk…).
static func get_item(id: String) -> Dictionary:
	if not _cache.has(id):
		var it: Dictionary = DEFAULTS.duplicate(true)
		it.merge(Data.table("items")[id], true)
		for k in it:  # JSON отдаёт числа дробными; в предметах они целые
			if it[k] is float and it[k] == floorf(it[k]):
				it[k] = int(it[k])
		it["id"] = id
		_cache[id] = it
	return _cache[id]


static func stackable(it: Dictionary) -> bool:
	return it.kind in ["consumable", "material"]


static func sell_price(it: Dictionary) -> int:
	var rate := float(Data.table("progression").trade.sell_rate)
	return maxi(1, int(int(it.price) * rate))


static func stat_lines(it: Dictionary) -> Array:
	var lines := []
	if it.atk: lines.append("Атака +%d" % it.atk)
	if it.defense: lines.append("Защита +%d" % it.defense)
	if it.hp: lines.append("Здоровье +%d" % it.hp)
	if it.heal: lines.append("Лечит %d" % it.heal)
	if it.mana: lines.append("Мана +%d" % it.mana)
	if it.reach:
		var sw := int(it.swing)
		lines.append("Удар: " + ("быстрый" if sw <= 16 else "средний" if sw <= 22 else "медленный"))
	if it.stamina: lines.append("Силы: %d" % it.stamina)
	return lines
