class_name UiKit
## Рисование интерфейса в стиле Pyxel-версии: рамки-панели с ромбами, текст пиксельным шрифтом.

const FONT: Font = preload("res://assets/fonts/nord_font.fnt")
const SIZE := 9  # родной размер шрифта; 18 — крупный (x2)
const LINE_H := 9


static func rhombus(c: CanvasItem, cx: float, cy: float, r: int, col: Color) -> void:
	for i in r + 1:
		var w := r - i
		c.draw_rect(Rect2(cx - w, cy - i, w * 2 + 1, 1), col)
		c.draw_rect(Rect2(cx - w, cy + i, w * 2 + 1, 1), col)


## Панель: заливка, тёмная рамка, цветная рамка, ромбы по углам.
static func panel(c: CanvasItem, r: Rect2, fill: Color, border := Pal.GOLD, accent := Pal.RED) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(r.grow(-0.5), Pal.DARK_WOOD, false, 1.0)
	c.draw_rect(r.grow(-1.5), border, false, 1.0)
	c.draw_rect(r.grow(-2.5), Pal.DARK_WOOD, false, 1.0)
	for p in [r.position + Vector2(1, 1), Vector2(r.end.x - 2, r.position.y + 1),
			Vector2(r.position.x + 1, r.end.y - 2), r.end - Vector2(2, 2)]:
		rhombus(c, p.x, p.y, 2, accent)
		c.draw_rect(Rect2(p, Vector2.ONE), border)


static func width(s: String, size := SIZE) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Текст; (x, y) — левый верхний угол строки. shadow — цвет тени (+1, +1) или null.
static func text(c: CanvasItem, x: float, y: float, s: String, col: Color, shadow = null, size := SIZE) -> void:
	var base := y + FONT.get_ascent(size)
	if shadow != null:
		c.draw_string(FONT, Vector2(x + size / SIZE, base + size / SIZE), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	c.draw_string(FONT, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_center(c: CanvasItem, cx: float, y: float, s: String, col: Color, shadow = null, size := SIZE) -> void:
	text(c, roundf(cx - width(s, size) / 2), y, s, col, shadow, size)


## Перенос строк по ширине в пикселях.
static func wrap(s: String, max_w: float, size := SIZE) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var cur := ""
		for word in para.split(" "):
			var cand := word if cur == "" else cur + " " + word
			if width(cand, size) > max_w and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = cand
		out.append(cur)
	return out
