class_name Arrow
extends Node2D
## Стрела лучника. Отбитая ударом или парированием летит обратно и ранит врагов.

var x := 0.0
var y := 0.0
var w := 12.0
var h := 4.0
var vx := 0.0
var damage := 2
var reflected_damage := 3
var hostile := true
var dead := false
var life := 200


## Стрела с серединой в (cx, top).
static func create(cx_: float, top: float, speed: float, dmg: int, reflected: int) -> Arrow:
	var a := Arrow.new()
	a.x = cx_ - a.w / 2
	a.y = top
	a.vx = speed
	a.damage = dmg
	a.reflected_damage = reflected
	a.z_index = 12
	return a


func deflectable() -> bool:
	return hostile


func overlaps(ox: float, oy: float, ow: float, oh: float) -> bool:
	return ox < x + w and x < ox + ow and oy < y + h and y < oy + oh


func deflect(world) -> void:
	vx = -vx * 1.3
	hostile = false
	life = 200
	world.sparks(x + w / 2, y, 5)
	Audio.sfx("block")


func on_parried(world, _player) -> void:
	deflect(world)


func on_blocked(_world, _player) -> void:
	dead = true


func tick(world) -> void:
	life -= 1
	x += vx
	var tip := x + (w if vx > 0 else 0.0)
	if life <= 0 or world.level.is_solid(floori(tip / Level.TILE), floori((y + 2) / Level.TILE)):
		dead = true
		world.sparks(tip, y, 2)
		return
	if hostile:
		var p: Player = world.player
		if not p.dead and overlaps(p.x, p.y, p.w, p.h):
			var s := 1 if vx >= 0 else -1
			if p.take_damage(damage, p.cx - s * 20, world, true, self) == "hit":
				dead = true
	else:
		for e in world.enemies:
			if not e.dead and e.overlaps(x, y, w, h):
				e.take_hit(reflected_damage, 1 if vx >= 0 else -1, world)
				dead = true
				break


func sync() -> void:
	position = Vector2(x, y)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, w, 2), Pal.WOOD)
	if vx > 0:
		draw_rect(Rect2(w, 0, 2, 2), Pal.STEEL)
		draw_rect(Rect2(0, -2, 2, 2), Pal.LINEN)
		draw_rect(Rect2(0, 2, 2, 2), Pal.LINEN)
	else:
		draw_rect(Rect2(-2, 0, 2, 2), Pal.STEEL)
		draw_rect(Rect2(w - 2, -2, 2, 2), Pal.LINEN)
		draw_rect(Rect2(w - 2, 2, 2, 2), Pal.LINEN)
