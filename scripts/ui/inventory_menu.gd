class_name InventoryMenu
extends Overlay
## Сума и снаряжение: фигура героя с надетыми вещами, 24 ячейки сумы, руны, описание.
## Стрелки — выбор, Выбор — надеть / снять / съесть, R — выбросить (с подтверждением).

const SLOT := 34
const BAG_X := 244
const BAG_Y := 34
## Колонки снаряжения вокруг фигуры: слева шлем/оружие/доспех, справа щит/оберег.
const EQUIP_COLUMNS := [["helmet", "weapon", "armor"], ["shield", "amulet"]]
const EQUIP_POS := {"helmet": Vector2(18, 34), "weapon": Vector2(18, 76), "armor": Vector2(18, 118),
		"shield": Vector2(182, 34), "amulet": Vector2(182, 76)}
const FIGURE := Rect2(58, 32, 116, 120)

var col := 2  # 0..1 — снаряжение, 2..7 — сума
var row := 0
var confirm_drop := false
var figure: HumanoidLook


func _ready() -> void:
	super._ready()
	figure = HumanoidLook.new()
	figure.rig = Player.RIG
	figure.zoom = 2.0
	figure.position = Vector2(FIGURE.get_center().x, FIGURE.end.y - 4)
	add_child(figure)
	figure.set_look(Player.look_layers())


func _column_len(c: int) -> int:
	return EQUIP_COLUMNS[c].size() if c < 2 else Inventory.BAG_ROWS


## ["slot", имя ячейки] или ["bag", индекс].
func selected() -> Array:
	if col < 2:
		return ["slot", EQUIP_COLUMNS[col][row]]
	return ["bag", row * Inventory.BAG_COLS + (col - 2)]


func _selected_item() -> Dictionary:
	var sel := selected()
	return inv.equipped(sel[1]) if sel[0] == "slot" else inv.item_at(sel[1])


func update() -> void:
	if confirm_drop:
		if Controls.pressed("drop"):
			var it := _selected_item()
			inv.bag[selected()[1]] = null
			say("Выброшено: " + it.name)
			Audio.sfx("hit")
			confirm_drop = false
		elif Controls.pressed("back") or Controls.pressed("confirm") or Controls.pressed("inventory"):
			confirm_drop = false
		return
	if Controls.pressed("back") or Controls.pressed("inventory"):
		Audio.sfx("select")
		close()
		return
	var moved := true
	if Controls.pressed_repeat("move_left") and col > 0:
		col -= 1
	elif Controls.pressed_repeat("move_right") and col < 7:
		col += 1
	elif Controls.pressed_repeat("move_up") and row > 0:
		row -= 1
	elif Controls.pressed_repeat("move_down") and row < _column_len(col) - 1:
		row += 1
	else:
		moved = false
	if moved:
		row = mini(row, _column_len(col) - 1)
		Audio.sfx("move")

	var sel := selected()
	if Controls.pressed("confirm"):
		if sel[0] == "slot":
			_unequip(sel[1])
		else:
			_use(sel[1])
	elif Controls.pressed("drop") and sel[0] == "bag" and not inv.item_at(sel[1]).is_empty():
		confirm_drop = true
		Audio.sfx("move")


func _unequip(slot: String) -> void:
	if inv.equipped(slot).is_empty():
		Audio.sfx("deny")
	elif inv.unequip(slot):
		Audio.sfx("select")
		_refresh_look()
	else:
		say("Сума полна!", Pal.RED)
		Audio.sfx("deny")


func _use(index: int) -> void:
	var it := inv.item_at(index)
	var p := world.player
	if it.is_empty():
		Audio.sfx("deny")
	elif it.kind == "material":
		say("Это для кузни: отнеси Добрыне", Pal.STEEL)
		Audio.sfx("deny")
	elif it.kind == "consumable" and it.mana and not it.heal:
		if p.mana >= inv.max_mana():
			say("Сила чар и так полна", Pal.STEEL)
			Audio.sfx("deny")
		else:
			p.mana = minf(inv.max_mana(), p.mana + int(it.mana))
			inv.remove_at(index)
			say("%s: +%d маны" % [it.name, int(it.mana)], Pal.FJORD)
			Audio.sfx("heal")
	elif it.kind == "consumable":
		if GameState.hp >= inv.max_hp():
			say("Ты и так полон сил", Pal.STEEL)
			Audio.sfx("deny")
		else:
			var healed := p.heal(int(it.heal))
			inv.remove_at(index)
			say("%s: +%d жизни" % [it.name, healed], Pal.MOSS)
			Audio.sfx("heal")
	else:
		inv.equip_from_bag(index)
		_refresh_look()
		say("Надето: " + it.name)
		Audio.sfx("chest")


func _refresh_look() -> void:
	figure.set_look(Player.look_layers())
	if world:
		world.player.rebuild_look()


# ------------------------------------------------------------ отрисовка
func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	var sel := selected()
	dim(c, 0.75)
	UiKit.panel(c, Rect2(4, 14, view.x - 8, view.y - 16), Pal.NIGHT)
	title_plate(c, view.x / 2, 5, "СУМА И СНАРЯЖЕНИЕ")

	# Фигура героя с надетыми вещами (сам облик — узел figure поверх холста).
	c.draw_rect(FIGURE, Pal.BLACK)
	c.draw_rect(FIGURE.grow(-0.5), Pal.DARK_WOOD, false, 1.0)
	c.draw_circle(FIGURE.get_center() + Vector2(0, 6), 44, Color(Pal.DUSK, 0.35))
	var wpn := inv.equipped("weapon")
	var shield := inv.equipped("shield")
	figure.show_frame(HumanoidLook.anim("idle", t / 15, Player.RIG), 1, null if wpn.is_empty() else wpn,
			null if shield.is_empty() else shield)
	for slot in EQUIP_POS:
		var at: Vector2 = EQUIP_POS[slot]
		var it := inv.equipped(slot)
		item_box(c, at.x, at.y, SLOT, it, 0, sel[0] == "slot" and sel[1] == slot, t)
		if it.is_empty():
			UiKit.text_center(c, at.x + SLOT / 2.0, at.y + 13, Items.SLOT_NAMES[slot].left(1), Pal.DARK_WOOD)

	# Показатели.
	var sy := 160
	UiKit.text(c, 18, sy, "Жизнь", Pal.STEEL)
	HudLayer.bar(c, Rect2(74, sy, 80, 9), GameState.hp, inv.max_hp(), Pal.RED)
	UiKit.text(c, 160, sy, "%d/%d" % [GameState.hp, inv.max_hp()], Pal.LINEN)
	UiKit.text(c, 18, sy + 14, "Атака", Pal.STEEL)
	UiKit.text(c, 74, sy + 14, str(inv.attack()), Pal.GOLD)
	UiKit.text(c, 18, sy + 28, "Защита", Pal.STEEL)
	UiKit.text(c, 74, sy + 28, str(inv.defense()), Pal.FJORD)
	c.draw_texture(Icons.texture("coin"), Vector2(116, sy + 12))
	UiKit.text(c, 136, sy + 20, str(inv.silver), Pal.LINEN)

	# Сума.
	for i in Inventory.BAG_SIZE:
		var x := BAG_X + (i % Inventory.BAG_COLS) * SLOT
		var y := BAG_Y + (i / Inventory.BAG_COLS) * SLOT
		item_box(c, x, y, SLOT - 2, inv.item_at(i), inv.count_at(i), sel[0] == "bag" and sel[1] == i, t)

	# Выученные руны.
	var ry := BAG_Y + Inventory.BAG_ROWS * SLOT + 4
	UiKit.text(c, BAG_X, ry + 12, "Руны", Pal.STEEL)
	if inv.spells.is_empty():
		UiKit.text(c, BAG_X + 40, ry + 12, "пока нет", Pal.STONE)
	for i in inv.spells.size():
		var rune: String = inv.spells[i]
		var rx := BAG_X + 40 + i * 38
		if rune == inv.spell():
			c.draw_rect(Rect2(rx - 1.5, ry - 1.5, 35, 35), Pal.FJORD, false, 1.0)
		c.draw_texture(Icons.of(Items.get_item(rune)), Vector2(rx, ry))
	UiKit.text(c, view.x - 18 - UiKit.width("(E)"), ry + 12, "(E)", Pal.STONE)

	# Описание выбранного.
	var it := _selected_item()
	var dy := 214
	c.draw_rect(Rect2(12, dy - 5, view.x - 24, 1), Pal.DARK_WOOD)
	if not it.is_empty():
		UiKit.text(c, 18, dy, inv.item_name(it), Pal.GOLD, Pal.NIGHT)
		var label: String = Items.KIND_NAMES.get(it.kind, "")
		UiKit.text(c, view.x - 18 - UiKit.width(label), dy, label, Pal.STONE)
		var stats := "   ".join(Items.stat_lines(it))
		if it.kind == "weapon" and inv.upgrade_level(it.id):
			stats += "   Заточка +%d" % inv.upgrade_level(it.id)
		UiKit.text(c, 18, dy + 12, stats, Pal.MOSS)
		var lines := UiKit.wrap(it.desc, view.x - 36)
		for i in mini(2, lines.size()):
			UiKit.text(c, 18, dy + 24 + i * UiKit.LINE_H, lines[i], Pal.LINEN)
	elif sel[0] == "slot":
		UiKit.text(c, 18, dy, Items.SLOT_NAMES[sel[1]] + ": пусто", Pal.STONE)
	else:
		UiKit.text(c, 18, dy, "Пустая ячейка", Pal.STONE)

	# Подсказка.
	var hy := view.y - 14
	if confirm_drop:
		UiKit.text_center(c, view.x / 2, hy, "Выбросить? R — да, ESC — нет", Pal.RED)
	elif msg_t > 0:
		UiKit.text_center(c, view.x / 2, hy, msg, msg_col)
	else:
		var action := "надеть"
		if sel[0] == "slot":
			action = "снять"
		elif not it.is_empty() and it.kind == "consumable":
			action = "съесть"
		elif not it.is_empty() and it.kind == "material":
			action = "—"
		UiKit.text_center(c, view.x / 2, hy, "Z — %s   R — выбросить   I — закрыть" % action, Pal.STONE)
