class_name LostSilver
extends Node2D
## Серебро, оброненное героем при гибели. Подбери — вернёшь.
## (x, y) — левый верхний угол; узел стоит в той же точке.

const W := 20.0
const H := 16.0

var x := 0.0
var y := 0.0
var amount := 0


func _init(left: float, bottom: float, silver: int) -> void:
	x = left
	y = bottom - H
	amount = silver
	position = Vector2(x, y)


func overlaps(ox: float, oy: float, ow: float, oh: float) -> bool:
	return ox < x + W and x < ox + ow and oy < y + H and y < oy + oh


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Engine.get_physics_frames()
	draw_circle(Vector2(10, 8), 18, Color(Pal.STEEL, 0.25 + 0.1 * sin(t * 0.1)))
	var coins := [Vector2(2, -4), Vector2(8, -6), Vector2(14, -4), Vector2(6, -10), Vector2(12, -10)]
	for i in coins.size():
		draw_rect(Rect2(coins[i] + Vector2(0, H), Vector2(6, 4)), Pal.SNOW if (t / 8 + i) % 4 else Pal.STEEL)
	if (t / 6) % 5 == 0:
		draw_rect(Rect2(10, H - 18, 2, 2), Pal.SNOW)
