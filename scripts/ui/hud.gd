class_name HudLayer
extends CanvasLayer
## Экранный слой мира: жизнь, выносливость, мана, серебро, припасы, уровень, руна,
## сообщения, название локации, полоса босса, табличка, разговор.

var world: World
var _canvas: Node2D


func _ready() -> void:
	layer = 10
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var c := _canvas
	var view := c.get_viewport_rect().size
	var cx := view.x / 2
	var w := world
	var banner_on := w.title_t > 0 and w.title_t < 170
	_draw_stats(c, w.player)

	# Сообщения.
	for i in w.toasts.size():
		var ts: Array = w.toasts[i]
		if ts[2] < 20 and (ts[2] / 2) % 2:
			continue
		var tw := UiKit.width(ts[0])
		var y := (96 if banner_on else 46) + i * 13
		c.draw_rect(Rect2(cx - tw / 2 - 6, y - 3, tw + 12, 14), Color(Pal.BLACK, 0.7))
		UiKit.text_center(c, cx, y, ts[0], ts[1])

	# Название локации при входе.
	if banner_on and (w.title_t > 30 or (w.title_t / 3) % 2):
		var title: String = w.banner[0] if w.banner else w.level.title
		var subtitle: String = w.banner[1] if w.banner else w.level.subtitle
		c.draw_rect(Rect2(0, 40, view.x, 46), Color(Pal.BLACK, 0.75))
		c.draw_rect(Rect2(0, 40, view.x, 1), Pal.GOLD)
		c.draw_rect(Rect2(0, 85, view.x, 1), Pal.GOLD)
		UiKit.text_center(c, cx, 46, title.to_upper(), Pal.GOLD, Pal.RED, 18)
		if subtitle:
			UiKit.text_center(c, cx, 70, subtitle, Pal.LINEN)

	# Полоса жизни босса.
	var boss := w.boss
	if boss != null and boss.awake and not boss.dead and boss.state != "rise":
		var r := Rect2(48, view.y - 34, view.x - 96, 28)
		UiKit.panel(c, r, Pal.BLACK, Pal.GOLD, Pal.RED)
		UiKit.text_center(c, cx, r.position.y + 6, boss.boss_name, Pal.GOLD)
		var col := Pal.RED if boss.phase == 1 or (w.t / 8) % 2 else Pal.FIRE
		bar(c, Rect2(r.position.x + 12, r.position.y + 17, r.size.x - 24, 6), boss.hp, boss.max_hp, col)

	# Разговор.
	var npc := w.talk_npc
	if npc != null:
		var all := npc.lines()
		var lines := UiKit.wrap(all[npc.line], 300)
		var r := Rect2(cx - 165, 30, 330, 30 + lines.size() * UiKit.LINE_H)
		UiKit.panel(c, r, Pal.NIGHT)
		UiKit.text(c, r.position.x + 12, r.position.y + 8, npc.display_name(), Pal.GOLD, Pal.BLACK)
		for i in lines.size():
			UiKit.text(c, r.position.x + 12, r.position.y + 21 + i * UiKit.LINE_H, lines[i], Pal.LINEN, Pal.BLACK)
		var tag := "↑ далее" if npc.line + 1 < all.size() else "↑ конец"
		UiKit.text(c, r.end.x - 12 - UiKit.width(tag), r.position.y + 8, tag, Pal.STONE)

	# Табличка.
	if w.near is Sign:
		var lines := UiKit.wrap(w.near.text, 300)
		var r := Rect2(cx - 165, 150, 330, 16 + lines.size() * UiKit.LINE_H)
		UiKit.panel(c, r, Pal.DARK_WOOD, Pal.WOOD, Pal.GOLD)
		for i in lines.size():
			UiKit.text(c, r.position.x + 12, r.position.y + 8 + i * UiKit.LINE_H, lines[i], Pal.LINEN, Pal.NIGHT)


## Полоса значения, как ui.bar в Pyxel-версии.
static func bar(c: CanvasItem, r: Rect2, value: float, max_value: float, col: Color, shine := true) -> void:
	c.draw_rect(r, Pal.NIGHT)
	var fill := floorf((r.size.x - 2) * maxf(0, value) / maxf(1, max_value))
	c.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(fill, r.size.y - 2)), col)
	if shine and fill > 2:
		c.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(fill, 1)), Pal.SNOW)
	c.draw_rect(r.grow(-0.5), Pal.DARK_WOOD, false, 1.0)


func _draw_stats(c: CanvasItem, p: Player) -> void:
	var inv := GameState.inv
	c.draw_rect(Rect2(2, 2, 150, 44), Pal.BLACK)
	c.draw_rect(Rect2(2.5, 2.5, 149, 43), Pal.DARK_WOOD, false, 1.0)
	var need := Inventory.xp_needed(inv.level)
	c.draw_rect(Rect2(3, 43, int(148.0 * inv.xp / need), 1), Pal.GOLD)
	var lvl_col := Pal.GOLD if inv.points and (world.t / 15) % 2 else Pal.STEEL
	UiKit.text(c, 116, 31, "УР.%d%s" % [inv.level, "+" if inv.points else ""], lvl_col)
	c.draw_texture(Icons.texture("heart"), Vector2(5, 4))
	bar(c, Rect2(24, 6, 86, 8), GameState.hp, GameState.max_hp(), Pal.RED)
	UiKit.text(c, 114, 5, "%d/%d" % [GameState.hp, GameState.max_hp()], Pal.LINEN)
	var flash := p.stamina_flash and (p.stamina_flash / 3) % 2
	bar(c, Rect2(24, 16, 86, 5), p.stamina, GameState.max_stamina(), Pal.RED if flash else Pal.MOSS, false)
	bar(c, Rect2(24, 23, 86, 5), p.mana, GameState.max_mana(), Pal.FJORD, false)
	UiKit.text(c, 114, 20, str(int(p.mana)), Pal.FJORD)
	c.draw_texture(Icons.texture("coin"), Vector2(5, 27))
	UiKit.text(c, 24, 31, str(inv.silver), Pal.LINEN)
	var idx := inv.first_consumable()
	if idx >= 0:
		var total := 0
		for i in inv.bag.size():
			if inv.bag[i] and inv.item_at(i).heal:
				total += inv.count_at(i)
		c.draw_texture(Icons.of(inv.item_at(idx)), Vector2(60, 27))
		UiKit.text(c, 78, 31, "x%d Q" % total, Pal.LINEN)
	# Выбранная руна.
	var rune := inv.spell()
	if rune:
		var cost := int(Spells.spell(rune).cost)
		var ready := p.mana >= cost
		c.draw_rect(Rect2(156, 2, 40, 44), Pal.BLACK)
		c.draw_rect(Rect2(156.5, 2.5, 39, 43), Pal.FJORD if ready else Pal.DARK_WOOD, false, 1.0)
		c.draw_texture_rect(Icons.of(Items.get_item(rune)), Rect2(160, 4, 32, 32), false)
		UiKit.text(c, 160, 35, "F", Pal.FJORD if ready else Pal.STONE)
		UiKit.text(c, 172, 35, str(cost), Pal.FJORD if ready else Pal.STONE)
