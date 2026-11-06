class_name Effects
extends Node2D
## Частицы-пиксели: пыль, искры, дым (как world.particles в Pyxel-версии, x2).

const SIZE := 2.0

## [x, y, vx, vy, жизнь, цвет, тяжесть]
var _parts := []
## Эффекты из листов (FxSheets): [имя, x, y, отражён, возраст, скорость, за кем следует]
var _sheets := []


## Разовый эффект из листа. follow — объект с x, y, w, h: эффект едет за его ногами.
func play(name: String, x: float, y: float, flip := false, speed := 0.0, follow: Object = null) -> void:
	if FxSheets.has(name):
		_sheets.append([name, x, y, flip, 0, speed, follow])


func dust(x: float, y: float, n := 5) -> void:
	for i in n:
		_parts.append([x, y, randf_range(-1.6, 1.6), randf_range(-1.2, -0.2), randi_range(10, 18), Pal.LINEN, 0.1])


func sparks(x: float, y: float, n := 6) -> void:
	for i in n:
		_parts.append([x, y, randf_range(-3.2, 3.2), randf_range(-3.6, 0.4), randi_range(8, 16),
				[Pal.GOLD, Pal.SNOW, Pal.FIRE].pick_random(), 0.1])


func smoke(x: float, y: float, n := 12) -> void:
	for i in n:
		_parts.append([x + randf_range(-8, 8), y + randf_range(-12, 8), randf_range(-0.8, 0.8),
				randf_range(-1.8, -0.4), randi_range(18, 34), [Pal.STONE, Pal.STEEL, Pal.DUSK].pick_random(), 0.02])


## Дымок из трубы: медленно поднимается и сносится ветром.
func puff(x: float, y: float) -> void:
	_parts.append([x + randf_range(-2, 2), y, randf_range(0.1, 0.5), randf_range(-1.0, -0.6),
			randi_range(40, 70), [Pal.STONE, Pal.STEEL].pick_random(), 0.0])


## Зелёные искры лечения вокруг героя (x, top — середина и верх хитбокса).
func heal_glow(x: float, top: float) -> void:
	for i in 14:
		_parts.append([x + randf_range(-12, 12), top + randf_range(0, 30), randf_range(-0.4, 0.4),
				randf_range(-2.0, -0.8), randi_range(20, 36), [Pal.MOSS, Pal.PINE, Pal.SNOW].pick_random(), 0.0])


## Хвост огненного шара.
func trail(x: float, y: float, vx: float) -> void:
	_parts.append([x, y, vx, randf_range(-0.6, 0.6), randi_range(6, 12), [Pal.FIRE, Pal.GOLD, Pal.RED].pick_random(), 0.0])


## Взрыв огненного шара.
func burst(x: float, y: float) -> void:
	for i in 10:
		_parts.append([x, y, randf_range(-2.8, 2.8), randf_range(-3.2, 0.8), randi_range(8, 16),
				[Pal.FIRE, Pal.GOLD, Pal.RED].pick_random(), 0.06])


func tick() -> void:
	for p in _parts:
		p[0] += p[2]
		p[1] += p[3]
		p[3] += p[6]
		p[4] -= 1
	_parts = _parts.filter(func(p): return p[4] > 0)
	for s in _sheets:
		s[4] += 1
		if s[6] != null and is_instance_valid(s[6]):
			s[1] = s[6].x + s[6].w / 2
			s[2] = s[6].y + s[6].h
	_sheets = _sheets.filter(func(s): return s[4] < FxSheets.length(s[0], s[5]))
	queue_redraw()


func _draw() -> void:
	for s in _sheets:
		FxSheets.draw(self, s[0], Vector2(s[1], s[2]), s[4], s[3], s[5])
	for p in _parts:
		draw_rect(Rect2(floorf(p[0]), floorf(p[1]), SIZE, SIZE), p[5])
