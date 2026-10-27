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


## Тёмная полоса во всю ширину экрана — подложка под крупный текст.
static func backdrop(c: CanvasItem, y: float, h: float, line := Pal.GOLD) -> void:
	var w := c.get_viewport_rect().size.x
	c.draw_rect(Rect2(0, y, w, h), Pal.BLACK)
	c.draw_rect(Rect2(0, y, w, 1), line)
	c.draw_rect(Rect2(0, y + h - 1, w, 1), line)


## Полоса из ромбов, как на вышивке рушника.
static func ornament_band(c: CanvasItem, x: float, y: float, w: float, c1 := Pal.RED, c2 := Pal.GOLD) -> void:
	c.draw_rect(Rect2(x, y - 4, w, 1), c2)
	c.draw_rect(Rect2(x, y + 4, w, 1), c2)
	var i := 0
	for cx in range(int(x) + 4, int(x + w) - 3, 8):
		rhombus(c, cx, y, 2, c1 if i % 2 == 0 else c2)
		i += 1
