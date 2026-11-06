class_name Weather
extends Node2D
## Снегопад поверх уровня, в координатах экрана. Рецепт из pixelfx (weather/snow, MIT):
## три слоя — дальние точки, хлопья, крупные снежинки; у каждого своя скорость, качание
## и параллакс; общий порывистый ветер. Всё — функция времени, без состояния.

const W := 480.0
const H := 270.0
## [сколько, скорость падения, качание, ветер, параллакс]
const LAYERS := [
	[220, 22.0, 2.0, 6.0, 0.25],
	[120, 34.0, 5.0, 12.0, 0.6],
	[18, 52.0, 11.0, 18.0, 1.0],
]

var t := 0
var cam := Vector2.ZERO


func tick(camera_pos: Vector2) -> void:
	t += 1
	cam = camera_pos
	position = camera_pos
	queue_redraw()


static func _r(i: int, k: int) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


func _gust(s: float) -> float:
	return 10.0 * sin(s * TAU / 12.0 + 0.6) + 4.0 * sin(s * TAU / 6.0 + 2.1)


func _draw() -> void:
	var s := t / 60.0
	for li in LAYERS.size():
		var L: Array = LAYERS[li]
		for i in int(L[0]):
			var id := li * 1000 + i
			var fall: float = L[1] * (0.8 + 0.4 * _r(id, 1))
			var y: float = fposmod(_r(id, 2) * H + s * fall - cam.y * L[4], H + 16) - 8
			var x: float = _r(id, 3) * W + s * L[3] + _gust(s) * L[4] \
					+ L[2] * sin(TAU * (0.25 + _r(id, 4) * 0.35) * s + _r(id, 5) * TAU) - cam.x * L[4]
			x = fposmod(x, W + 16) - 8
			var at := Vector2(x, y).floor()
			match li:
				0:
					draw_rect(Rect2(at, Vector2.ONE), Pal.STONE if _r(id, 6) < 0.5 else Pal.STEEL)
				1:
					_flake(at, _r(id, 6) < 0.3)
				2:
					_crystal(at, 3 + int(_r(id, 6) * 3), int(s * (1.5 + _r(id, 7) * 2.5)) % 2)


func _flake(at: Vector2, big: bool) -> void:
	draw_rect(Rect2(at, Vector2.ONE), Pal.SNOW)
	if big:
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2(at + d, Vector2.ONE), Pal.STEEL)
	else:
		draw_rect(Rect2(at + Vector2(1, 0), Vector2.ONE), Pal.LINEN)
		draw_rect(Rect2(at + Vector2(0, 1), Vector2.ONE), Pal.LINEN)


## Крупная снежинка: длинные лучи по одной четвёрке направлений, короткие — по другой;
## поворот — смена четвёрок.
func _crystal(at: Vector2, r: int, turn: int) -> void:
	var axis := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var diag := [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]
	var long: Array = diag if turn else axis
	var short: Array = axis if turn else diag
	var lr := r - 1 if turn else r
	for d in long:
		for k in range(1, lr + 1):
			draw_rect(Rect2(at + d * k, Vector2.ONE), Pal.SNOW if k == lr else Pal.STEEL)
	for d in short:
		draw_rect(Rect2(at + d, Vector2.ONE), Pal.STEEL)
	draw_rect(Rect2(at, Vector2.ONE), Pal.SNOW)
