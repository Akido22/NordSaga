class_name TradeMenu
extends Overlay
## Лавка: вкладки «Купить», «Продать», «Ковать» (у кузнеца) — data/shops.toml.
## ←/→ — вкладки, ↑/↓ — список, Выбор — купить/продать/выковать, Назад — уйти.

const TAB_NAMES := {"buy": "Купить", "sell": "Продать", "forge": "Ковать"}
const ROWS := 10
const ROW_H := 17
const LIST := Rect2(18, 58, 214, ROWS * ROW_H)

var shop_id := ""
var shop: Dictionary
var tab := 0
var index := 0
var scroll := 0


func _init(id: String, start_tab := 0) -> void:
	shop_id = id
	shop = Data.table("shops")[id]
	tab = maxi(0, start_tab)


func kind() -> String:
	return shop.get("tabs", ["buy", "sell"])[tab]


## Строки вкладки: [вид, предмет, ячейка сумы или -1].
func entries() -> Array:
	if kind() == "buy":
		return Array(shop.stock).map(func(id): return ["buy", Items.get_item(id), -1])
	if kind() == "sell":
		var rows := []
		for i in inv.bag.size():
			if inv.bag[i]:
				rows.append(["sell", inv.item_at(i), i])
		return rows
	var rows := []
	var weapon := inv.equipped("weapon")
	var seen := {}
	if not weapon.is_empty():
		rows.append(["forge", weapon, -1])
		seen[weapon.id] = true
	for i in inv.bag.size():
		var it := inv.item_at(i)
		if not it.is_empty() and it.kind == "weapon" and not seen.has(it.id):
			seen[it.id] = true
			rows.append(["forge", it, i])
	return rows


# ------------------------------------------------------------ логика
func update() -> void:
	if Controls.pressed("back"):
		Audio.sfx("select")
		close()
		return
	var rows := entries()
	var tabs: Array = shop.get("tabs", ["buy", "sell"])
	if Controls.pressed_repeat("move_left") and tab > 0:
		_switch(-1)
	elif Controls.pressed_repeat("move_right") and tab < tabs.size() - 1:
		_switch(1)
	elif Controls.pressed_repeat("move_up") and index > 0:
		index -= 1
		Audio.sfx("move")
	elif Controls.pressed_repeat("move_down") and index < rows.size() - 1:
		index += 1
		Audio.sfx("move")
	elif Controls.pressed("confirm") and not rows.is_empty():
		act(rows[index])
	rows = entries()
	index = clampi(index, 0, maxi(0, rows.size() - 1))
	if index < scroll:
		scroll = index
	elif index >= scroll + ROWS:
		scroll = index - ROWS + 1


func _switch(step: int) -> void:
	tab += step
	index = 0
	scroll = 0
	Audio.sfx("move")


## Купить, продать или выковать (как TradeScene._act в Pyxel-версии).
func act(row: Array) -> void:
	var it: Dictionary = row[1]
	match row[0]:
		"buy":
			if it.kind == "rune" and inv.knows(it.id):
				say("Эту руну ты уже знаешь", Pal.STEEL)
				Audio.sfx("deny")
			elif inv.silver < int(it.price):
				say("Не хватает серебра", Pal.RED)
				Audio.sfx("deny")
			elif not inv.add(it.id):
				say("Сума полна", Pal.RED)
				Audio.sfx("deny")
			else:
				inv.silver -= int(it.price)
				say("Куплено: " + it.name)
				Audio.sfx("coin")
		"sell":
			var price := Items.sell_price(it)
			inv.remove_at(row[2])
			inv.silver += price
			if it.kind == "weapon" and inv.count_of(it.id) == 0 and inv.equipment.weapon != it.id:
				inv.upgrades.erase(it.id)  # проданная заточка уходит вместе с оружием
			say("Продано: %s за %d" % [it.name, price])
			Audio.sfx("coin")
		"forge":
			var err := inv.upgrade(it.id)
			if err:
				say(err, Pal.RED)
				Audio.sfx("deny")
			else:
				say("Выковано: " + inv.item_name(it))
				Audio.sfx("heavy")
				if world:
					world.sparks(world.player.cx, world.player.y, 6)


# ------------------------------------------------------------ отрисовка
func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	dim(c, 0.75)
	UiKit.panel(c, Rect2(8, 16, view.x - 16, view.y - 22), Pal.NIGHT)
	title_plate(c, view.x / 2, 7, shop.title)
	# Вкладки.
	var x := 20.0
	var tabs: Array = shop.get("tabs", ["buy", "sell"])
	for i in tabs.size():
		var label: String = TAB_NAMES[tabs[i]]
		var w := UiKit.width(label) + 16
		var active := i == tab
		c.draw_rect(Rect2(x, 34, w, 16), Pal.DARK_WOOD if active else Pal.BLACK)
		c.draw_rect(Rect2(x + 0.5, 34.5, w - 1, 15), Pal.GOLD if active else Pal.STONE, false, 1.0)
		UiKit.text(c, x + 8, 38, label, Pal.GOLD if active else Pal.STEEL)
		x += w + 6
	UiKit.text(c, view.x - 22 - UiKit.width("← →"), 38, "← →", Pal.STONE)

	var rows := entries()
	c.draw_rect(LIST.grow(2), Pal.BLACK)
	if rows.is_empty():
		UiKit.text(c, LIST.position.x + 6, LIST.position.y + 6,
				{"buy": "Товара нет", "sell": "Нечего продать", "forge": "Нет оружия"}[kind()], Pal.STONE)
	for n in range(scroll, mini(rows.size(), scroll + ROWS)):
		var row: Array = rows[n]
		var it: Dictionary = row[1]
		var y := LIST.position.y + (n - scroll) * ROW_H
		if n == index:
			c.draw_rect(Rect2(LIST.position.x - 1, y, LIST.size.x + 2, ROW_H), Pal.DARK_WOOD)
			c.draw_rect(Rect2(LIST.position.x - 0.5, y + 0.5, LIST.size.x + 1, ROW_H - 1), Pal.GOLD, false, 1.0)
		c.draw_texture(Icons.of(it), Vector2(LIST.position.x + 1, y + 1))
		var item_name := inv.item_name(it)
		if row[0] == "sell" and inv.count_at(row[2]) > 1:
			item_name += " x%d" % inv.count_at(row[2])
		UiKit.text(c, LIST.position.x + 22, y + 4, _fit(item_name, 150), Pal.LINEN)
		var tag := ""
		var col := Pal.GOLD
		if row[0] == "buy" and it.kind == "rune" and inv.knows(it.id):
			tag = "есть"
			col = Pal.STONE
		elif row[0] == "buy":
			tag = str(it.price)
			col = Pal.GOLD if inv.silver >= int(it.price) else Pal.RED
		elif row[0] == "sell":
			tag = str(Items.sell_price(it))
		else:
			var lvl := inv.upgrade_level(it.id)
			tag = "+%d" % lvl if lvl else "-"
			col = Pal.MOSS
			if row[2] < 0:
				UiKit.rhombus(c, LIST.end.x - 28, y + 8, 2, Pal.GOLD)  # надетое оружие
		UiKit.text(c, LIST.end.x - 3 - UiKit.width(tag), y + 4, tag, col)
	if scroll > 0:
		UiKit.text(c, LIST.end.x - 8, LIST.position.y - 11, "↑", Pal.STONE)
	if scroll + ROWS < rows.size():
		UiKit.text(c, LIST.end.x - 8, LIST.end.y + 2, "↓", Pal.STONE)
	if not rows.is_empty():
		_draw_details(c, rows[index], view)

	# Низ: кошель и подсказка.
	var by := view.y - 30
	c.draw_rect(Rect2(18, by - 4, view.x - 36, 1), Pal.DARK_WOOD)
	c.draw_texture(Icons.texture("coin"), Vector2(18, by))
	UiKit.text(c, 38, by + 4, str(inv.silver), Pal.LINEN)
	c.draw_texture(Icons.texture("ore"), Vector2(78, by))
	UiKit.text(c, 98, by + 4, str(inv.count_of("ore")), Pal.LINEN)
	if msg_t > 0:
		UiKit.text_center(c, 300, by + 4, msg, msg_col)
	var hint: String = {"buy": "Z — купить", "sell": "Z — продать", "forge": "Z — выковать"}[kind()]
	UiKit.text_center(c, view.x / 2, view.y - 16, hint + "    ESC — уйти", Pal.STONE)


func _fit(text: String, width: float) -> String:
	if UiKit.width(text) <= width:
		return text
	while text and UiKit.width(text + ".") > width:
		text = text.left(-1)
	return text + "."


func _draw_details(c: CanvasItem, row: Array, view: Vector2) -> void:
	var it: Dictionary = row[1]
	var x := 248.0
	var y := 58.0
	c.draw_rect(Rect2(x - 4, y - 4, view.x - x - 14, ROWS * ROW_H + 6), Pal.BLACK)
	item_box(c, x, y, 36, it)
	var lvl := inv.upgrade_level(it.id) if it.kind == "weapon" else 0
	UiKit.text(c, x + 44, y + 4, _fit(it.name, 160), Pal.GOLD)
	UiKit.text(c, x + 44, y + 16, Items.KIND_NAMES.get(it.kind, "") + ("  +%d" % lvl if lvl else ""), Pal.STONE)
	var ty := y + 46
	if row[0] == "forge":
		UiKit.text(c, x, ty, "Атака: %d" % inv.item_atk(it), Pal.LINEN)
		var cost := inv.upgrade_cost(it.id)
		if cost.is_empty():
			UiKit.text(c, x, ty + 14, "Наивысшая заточка", Pal.MOSS)
		else:
			UiKit.text(c, x, ty + 14, "Заточка: +%d → +%d" % [lvl, lvl + 1], Pal.MOSS)
			UiKit.text(c, x, ty + 28, "Атака станет %d" % (inv.item_atk(it) + 1), Pal.MOSS)
			UiKit.text(c, x, ty + 46, "Серебро: %d" % cost[0], Pal.GOLD if inv.silver >= cost[0] else Pal.RED)
			var have := inv.count_of("ore")
			UiKit.text(c, x, ty + 60, "Криц: %d (есть %d)" % [cost[1], have], Pal.GOLD if have >= cost[1] else Pal.RED)
		return
	for line in Items.stat_lines(it).slice(0, 3):
		UiKit.text(c, x, ty, line, Pal.MOSS)
		ty += 12
	# Сравнение с надетым.
	if it.kind in Items.SLOTS:
		var cur := inv.equipped(it.kind)
		if not cur.is_empty() and cur.id != it.id:
			UiKit.text(c, x, ty + 2, "Надето: " + _fit(cur.name, 140), Pal.STONE)
			ty += 14
			for cmp in [["Атака", inv.item_atk(cur), int(it.atk)], ["Защита", int(cur.defense), int(it.defense)],
					["Жизнь", int(cur.hp), int(it.hp)]]:
				if cmp[1] != cmp[2]:
					UiKit.text(c, x, ty, "%s: %d → %d" % cmp, Pal.MOSS if cmp[2] > cmp[1] else Pal.RED)
					ty += 12
	for line in UiKit.wrap(it.desc, view.x - x - 24).slice(0, 4):
		UiKit.text(c, x, ty + 4, line, Pal.STEEL)
		ty += 11
