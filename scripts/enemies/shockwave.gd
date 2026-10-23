class_name Shockwave
extends Node2D
## Ударная волна по полу. Не отбивается; блок тратит силы, прыжок и перекат спасают.

var x := 0.0
var y := 0.0
var w := 20.0
var h := 16.0
var vx := 0.0
var damage := 3
var dead := false
var hit := false
var life := 110


static func create(cx_: float, ground_y: float, speed: float, dmg: int) -> Shockwave:
	var s := Shockwave.new()
	s.x = cx_ - s.w / 2
	s.y = ground_y - s.h
	s.vx = speed
	s.damage = dmg
	s.z_index = 12
	return s


func deflectable() -> bool:
	return false


func overlaps(ox: float, oy: float, ow: float, oh: float) -> bool:
	return ox < x + w and x < ox + ow and oy < y + h and y < oy + oh


func on_blocked(_world, _player) -> void:
	pass


func tick(world) -> void:
	life -= 1
	x += vx
	var lvl: Level = world.level
	var front := x + (w if vx > 0 else 0.0)
	var floor_ty := floori((y + h + 2) / Level.TILE)
	if (life <= 0 or lvl.is_solid(floori(front / Level.TILE), floori((y + 8) / Level.TILE))
			or not lvl.is_solid(floori(front / Level.TILE), floor_ty)):
		dead = true
		return
	if world.t % 3 == 0:
		world.dust(x + w / 2, y + h, 1)
	var p: Player = world.player
	if not hit and not p.dead and overlaps(p.x, p.y, p.w, p.h):
		var s := 1 if vx >= 0 else -1
		if p.take_damage(damage, p.cx - s * 20, world, false, self) != "miss":
			hit = true


func sync() -> void:
	position = Vector2(x, y)
	queue_redraw()


func _draw() -> void:
	var t := Engine.get_physics_frames()
	for i in 4:
		var hh := 6 + ((t / 2 + i * 3) % 6) * 2
		draw_rect(Rect2(i * 6, h - hh, 2, hh), Pal.STEEL if i % 2 else Pal.LINEN)
	draw_rect(Rect2(0, h - 2, w, 2), Pal.STONE)
