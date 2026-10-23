class_name Archer
extends Enemy
## Драугр-лучник: держит дистанцию и стреляет, предупреждая натянутой тетивой.

var aim := 44
var shot_cd := 50
var arrow_speed := 5.6
var keep_away := 96.0
var arrow_damage := 2
var reflected_damage := 3

var state := "walk"  # walk, aim
var state_t := 0
var cooldown := 30
var look: HumanoidLook


func _init() -> void:
	w = 20
	h = 44
	var d := load_stats("archer")
	aim = int(d.aim_frames)
	shot_cd = int(d.shot_cooldown)
	arrow_speed = float(d.arrow_speed)
	keep_away = float(d.keep_away)
	arrow_damage = int(d.arrow_damage)
	reflected_damage = int(d.reflected_damage)


func _ready() -> void:
	super._ready()
	look = HumanoidLook.new()
	look.position = Vector2(w / 2, h)
	add_child(look)
	move_child(look, 0)
	look.set_look(Looks.ARCHER)


func interrupt() -> void:
	if state == "aim":
		state = "walk"
		cooldown = 40


func think(world) -> void:
	var p: Player = world.player
	if cooldown > 0:
		cooldown -= 1
	if state == "aim":
		vx = 0
		facing = 1 if p.cx - cx >= 0 else -1
		state_t -= 1
		if state_t <= 0:
			world.add_projectile(Arrow.create(cx + facing * 16, y + 18, facing * arrow_speed,
					arrow_damage, reflected_damage))
			Audio.sfx("bow")
			state = "walk"
			cooldown = shot_cd
		return
	if not player_near(world, sight, 80):
		patrol(world, 0.6)
		return
	var dist := absf(p.cx - cx)
	facing = 1 if p.cx - cx >= 0 else -1
	if dist < keep_away and ground_ahead(world.level, -facing):
		vx = -facing * 1.4  # пятится, не сводя глаз с героя
	elif dist > 260 and ground_ahead(world.level, facing):
		vx = facing * 1.0
	else:
		vx = 0
		if cooldown == 0:
			state = "aim"
			state_t = aim


func pose() -> int:
	if stun_t > 0 or hurt_t > 0:
		return HumanoidLook.anim("hurt")
	if state == "aim":
		return HumanoidLook.anim("cast", 0)
	if absf(vx) > 0.1:
		return HumanoidLook.anim("run", anim_t / 7)
	return HumanoidLook.anim("idle", anim_t / 18)


func sync() -> void:
	super.sync()
	if look != null:
		look.show_frame(pose(), facing, null, null, null, false, flash > 0)


## Лук в вытянутой руке; натянут — блеск наконечника перед выстрелом.
func _draw_fx() -> void:
	var f := pose()
	var hand := HumanoidLook.anchor(f, "hand", w / 2, h, facing)
	var hx := hand.x
	var hy := hand.y
	var d := facing
	var aiming := state == "aim"
	_fx.draw_line(Vector2(hx, hy - 12), Vector2(hx + d * 4, hy - 6), Pal.WOOD, 2)
	_fx.draw_line(Vector2(hx + d * 4, hy - 6), Vector2(hx + d * 4, hy + 6), Pal.WOOD, 2)
	_fx.draw_line(Vector2(hx + d * 4, hy + 6), Vector2(hx, hy + 12), Pal.WOOD, 2)
	var pull := 6 if aiming else 0
	_fx.draw_line(Vector2(hx, hy - 12), Vector2(hx - d * pull, hy), Pal.LINEN, 1)
	_fx.draw_line(Vector2(hx - d * pull, hy), Vector2(hx, hy + 12), Pal.LINEN, 1)
	if aiming:
		_fx.draw_line(Vector2(hx - d * pull, hy), Vector2(hx + d * 10, hy), Pal.WOOD, 2)
		if state_t < 14 and (state_t / 2) % 2:
			_fx.draw_rect(Rect2(hx + d * 12, hy - 1, 2, 2), Pal.SNOW)
	draw_status(_fx, -12)
