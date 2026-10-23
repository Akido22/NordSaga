class_name TileBody
extends Node2D
## Прямоугольник с физикой и столкновениями с тайлами — как Body в Pyxel-версии.
## Все расстояния — пиксели Pyxel x2, поэтому допуски тоже удвоены (0.02, 1.0, 2).
## (x, y) — левый верхний угол хитбокса; считаются в float двойной точности,
## узел только отображает их (sync()).

const GRAVITY := 0.44
const MAX_FALL := 9.0

var w := 16.0
var h := 16.0
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var on_ground := false
var hit_wall := false
var on_platform := false


var cx: float:
	get: return x + w / 2

var cy: float:
	get: return y + h / 2


func sync() -> void:
	position = Vector2(x, y)


func apply_gravity() -> void:
	vy = minf(vy + GRAVITY, MAX_FALL)


func move(level: Level, drop_through := false) -> void:
	var t := Level.TILE
	hit_wall = false
	# --- по горизонтали
	x += vx
	var top := floori(y / t)
	var bottom := floori((y + h - 0.02) / t)
	if vx > 0:
		var edge := floori((x + w - 0.02) / t)
		if _any_solid_column(level, edge, top, bottom):
			x = edge * t - w
			vx = 0
			hit_wall = true
	elif vx < 0:
		var edge := floori(x / t)
		if _any_solid_column(level, edge, top, bottom):
			x = (edge + 1) * t
			vx = 0
			hit_wall = true
	# --- по вертикали
	var prev_bottom := y + h
	y += vy
	on_ground = false
	on_platform = false
	var left := floori(x / t)
	var right := floori((x + w - 0.02) / t)
	if vy > 0:
		var edge := floori((y + h - 0.02) / t)
		for tx in range(left, right + 1):
			var solid := level.is_solid(tx, edge)
			var plank := (not drop_through and level.is_platform(tx, edge)
					and prev_bottom <= edge * t + 1.0)
			if solid or plank:
				y = edge * t - h
				vy = 0
				on_ground = true
				on_platform = plank and not solid
				break
	elif vy < 0:
		var edge := floori(y / t)
		for tx in range(left, right + 1):
			if level.is_solid(tx, edge):
				y = (edge + 1) * t
				vy = 0
				break


## Есть ли опора впереди (чтобы враги не падали с обрывов).
func ground_ahead(level: Level, direction: int) -> bool:
	var fx := x + w + 2 if direction > 0 else x - 2
	var tx := floori(fx / Level.TILE)
	var ty := floori((y + h + 2) / Level.TILE)
	return level.is_solid(tx, ty) or level.is_platform(tx, ty)


func _any_solid_column(level: Level, tx: int, top: int, bottom: int) -> bool:
	for ty in range(top, bottom + 1):
		if level.is_solid(tx, ty):
			return true
	return false
