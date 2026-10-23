class_name Fireball
extends Node2D
## Огненный шар Кеназ: летит прямо, взрывается о врага или стену.

var x := 0.0
var y := 0.0
var w := 12.0
var h := 12.0
var vx := 0.0
var damage := 4
var dead := false
var life := 90


## Шар с серединой в (cx_, cy_).
static func create(cx_: float, cy_: float, speed: float, dmg: int) -> Fireball:
	var f := Fireball.new()
	f.x = cx_ - f.w / 2
	f.y = cy_ - f.h / 2
	f.vx = speed
	f.damage = dmg
	f.z_index = 12
	return f


func deflectable() -> bool:
	return false


func overlaps(ox: float, oy: float, ow: float, oh: float) -> bool:
	return ox < x + w and x < ox + ow and oy < y + h and y < oy + oh


func tick(world) -> void:
	life -= 1
	x += vx
	if world.t % 2 == 0:
		world.effects.trail(x + w / 2, y + h / 2, -vx * 0.2)
	var c := x + w / 2
	if life <= 0 or world.level.is_solid(floori(c / Level.TILE), floori((y + h / 2) / Level.TILE)):
		_burst(world)
		return
	for e in world.enemies:
		if not e.dead and e.overlaps(x, y, w, h):
			e.take_hit(damage, 1 if vx > 0 else -1, world)
			_burst(world)
			return


func _burst(world) -> void:
	dead = true
	world.effects.burst(x + w / 2, y + h / 2)


func sync() -> void:
	position = Vector2(x, y)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(w / 2, h / 2)
	var flick := Engine.get_physics_frames() % 4 < 2
	draw_circle(c, 6, Pal.RED)
	draw_circle(c, 4, Pal.FIRE if flick else Pal.GOLD)
	draw_rect(Rect2(c - Vector2.ONE, Vector2(2, 2)), Pal.SNOW)
