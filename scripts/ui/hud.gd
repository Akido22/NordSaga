extends CanvasLayer
## Экранный слой мира: сообщения, название локации, табличка, разговор.
## Полный интерфейс (жизнь, выносливость, мана, руны) — шаг 8.

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
