class_name Effects
extends Node2D
## Частицы-пиксели: пыль, искры, дым (как world.particles в Pyxel-версии, x2).

const SIZE := 2.0

## [x, y, vx, vy, жизнь, цвет, тяжесть]
var _parts := []


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


func tick() -> void:
	for p in _parts:
		p[0] += p[2]
		p[1] += p[3]
		p[3] += p[6]
		p[4] -= 1
	_parts = _parts.filter(func(p): return p[4] > 0)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		draw_rect(Rect2(floorf(p[0]), floorf(p[1]), SIZE, SIZE), p[5])
