class_name RestMenu
extends Overlay
## Отдых у Стелы или рунного камня: распределение свободных очков по показателям.
## Если очки потрачены, при уходе игра сохраняется.

var title := ""
var index := 0
var spent := false


func _init(point: SavePoint) -> void:
	title = "СТЕЛА ПРЕДКОВ" if point.kind == "stela" else "РУННЫЙ КАМЕНЬ"


func update() -> void:
	var n := Inventory.STATS.size() + 1
	if Controls.pressed_repeat("move_up"):
		index = posmod(index - 1, n)
		Audio.sfx("move")
	elif Controls.pressed_repeat("move_down"):
		index = posmod(index + 1, n)
		Audio.sfx("move")
	elif Controls.pressed("back") or (Controls.pressed("confirm") and index == Inventory.STATS.size()):
		Audio.sfx("select")
		if spent:
			world.save_game()
		close()
	elif Controls.pressed("confirm"):
		var stat: String = Inventory.STATS[index]
		if inv.spend_point(stat):
			spent = true
			var p := world.player
			GameState.hp = inv.max_hp()
			p.stamina = inv.max_stamina()
			p.mana = inv.max_mana()
			Audio.sfx("charged")
			say("%s: %d" % [Inventory.STAT_NAMES[stat], inv.stats[stat]])
		else:
			say("Нет свободных очков", Pal.RED)
			Audio.sfx("deny")


func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	var cx := view.x / 2
	dim(c, 0.65)
	UiKit.panel(c, Rect2(60, 26, view.x - 120, 230), Pal.NIGHT)
	title_plate(c, cx, 17, title)
	UiKit.text_center(c, cx, 46, "Уровень %d" % inv.level, Pal.GOLD, Pal.NIGHT)
	var need := Inventory.xp_needed(inv.level)
	HudLayer.bar(c, Rect2(110, 60, view.x - 220, 7), inv.xp, need, Pal.MOSS)
	UiKit.text_center(c, cx, 71, "опыт %d / %d" % [inv.xp, need], Pal.STEEL)
	var pts_col := Pal.GOLD if inv.points and (t / 15) % 2 else Pal.LINEN
	UiKit.text_center(c, cx, 86, "Свободных очков: %d" % inv.points, pts_col)
	var hints := Inventory.stat_hints()
	for i in Inventory.STATS.size():
		var stat: String = Inventory.STATS[i]
		var y := 106 + i * 18
		var sel := i == index
		if sel:
			c.draw_rect(Rect2(76, y - 4, view.x - 152, 16), Pal.DARK_WOOD)
			c.draw_rect(Rect2(76.5, y - 3.5, view.x - 153, 15), Pal.GOLD, false, 1.0)
		UiKit.text(c, 90, y, Inventory.STAT_NAMES[stat], Pal.GOLD if sel else Pal.LINEN)
		UiKit.text(c, 190, y, str(inv.stats[stat]), Pal.SNOW)
		UiKit.text(c, 214, y, "(%s)" % hints[stat], Pal.STONE)
	var y := 106 + Inventory.STATS.size() * 18 + 4
	var sel := index == Inventory.STATS.size()
	UiKit.text_center(c, cx, y, "Встать", Pal.GOLD if sel else Pal.LINEN, Pal.NIGHT)
	if sel:
		UiKit.rhombus(c, cx - 30, y + 4, 2, Pal.RED)
		UiKit.rhombus(c, cx + 29, y + 4, 2, Pal.RED)
	UiKit.text_center(c, cx, 222, "Жизнь %d   Атака %d   Силы %d   Мана %d" % [
			inv.max_hp(), inv.attack(), inv.max_stamina(), inv.max_mana()], Pal.STEEL)
	if msg_t > 0:
		UiKit.text_center(c, cx, 238, msg, msg_col)
