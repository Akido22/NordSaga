class_name Dummy
extends Enemy
## Соломенное чучело для отработки ударов: не нападает и не погибает.

var wobble := 0.0


func _init() -> void:
	w = 24
	h = 48
	kind = "dummy"
	max_hp = 999
	hp = max_hp
	contact_dmg = 0
	knock = 0


func take_hit(dmg: int, direction: int, world, heavy := false, _plunge := false) -> String:
	flash = 5
	wobble = direction * (4.0 if heavy else 2.5)
	world.float_text(cx, y - 8, str(dmg), Pal.GOLD)
	world.sparks(cx - direction * 6, cy, 8 if heavy else 4)
	world.freeze(5 if heavy else 3)
	Audio.sfx("heavy" if heavy else "hit")
	return "hit"


func tick(_world) -> void:
	anim_t += 1
	if flash > 0:
		flash -= 1
	wobble *= 0.9


func _draw() -> void:
	var b := h
	var c := w / 2
	var lean := roundf(wobble * cos(anim_t * 0.5) * 2)
	var top := c + lean
	var white := flash > 0
	var col := func(k: Color) -> Color: return Pal.SNOW if white else k
	draw_rect(Rect2(c - 2, b - 52, 4, 52), col.call(Pal.DARK_WOOD))  # кол
	draw_rect(Rect2(top - 18, b - 36, 36, 2), col.call(Pal.WOOD))  # руки-перекладина
	draw_rect(Rect2(top - 20, b - 38, 2, 2), col.call(Pal.GOLD))
	draw_rect(Rect2(top + 18, b - 38, 2, 2), col.call(Pal.GOLD))
	_ellipse(Rect2(top - 12, b - 38, 24, 26), col.call(Pal.GOLD))  # соломенное тулово
	draw_rect(Rect2(top - 10, b - 24, 20, 2), col.call(Pal.WOOD))  # опояска
	draw_circle(Vector2(top, b - 46), 8, col.call(Pal.LINEN))  # мешок-голова
	draw_rect(Rect2(top - 2, b - 48, 2, 2), col.call(Pal.NIGHT))
	draw_rect(Rect2(top + 4, b - 48, 2, 2), col.call(Pal.NIGHT))
	draw_rect(Rect2(top - 2, b - 42, 8, 2), col.call(Pal.RED))


func _ellipse(r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		pts.append(r.get_center() + Vector2(cos(a) * r.size.x / 2, sin(a) * r.size.y / 2))
	draw_colored_polygon(pts, color)
