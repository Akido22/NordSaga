class_name Player
extends TileBody
## Герой. Шаг 3: движение — бег, прыжок с «койотом» и буфером, спрыгивание
## с досок, колья. Бой, перекат, блок и чары — шаг 5 (состояния уже заложены).
## Логика идёт кадрами (tick), как в Pyxel-версии; числа — data/player.toml.

const ACCEL := 0.56
const AIR_ACCEL := 0.36
const JUMP_CUT := -3.2  # прыжок отпущен — подъём обрывается до этой скорости
const ARMOR_SHEETS := {"shirt": "hero_torso_shirt", "leather": "hero_torso_leather", "mail": "hero_torso_mail"}
const HELMET_SHEETS := {"cap": "hero_helmet_cap", "shishak": "hero_helmet_shishak"}

var max_speed: float
var jump_v: float
var coyote_frames: int
var jump_buffer: int
var invuln_frames: int

var facing := 1
var state := "move"  # move; шаг 5: attack, charge, plunge, roll, block, stun, recover, cast
var state_t := 0
var anim_t := 0
var coyote := 0
var jump_buf := 0
var drop_t := 0
var invuln := 0
var flash := 0
var dead := false
var dead_t := 0
var safe_x := 0.0  # куда вернуть после кольев (float64: Vector2 — 32 бита)
var safe_y := 0.0

@onready var look: HumanoidLook = $Look


func _init() -> void:
	w = 20.0
	h = 44.0
	var p: Dictionary = Data.table("player")
	max_speed = p.movement.max_speed
	jump_v = -float(p.movement.jump_velocity)
	coyote_frames = int(p.movement.coyote_frames)
	jump_buffer = int(p.movement.jump_buffer)
	invuln_frames = int(p.combat.invuln_frames)


func _ready() -> void:
	look.position = Vector2(w / 2, h)
	rebuild_look()


## Ставит героя: at — левый край и низ (ноги) хитбокса.
func place(at: Vector2) -> void:
	x = at.x
	y = at.y - h
	safe_x = x
	safe_y = y
	sync()


func rebuild_look() -> void:
	var armor := GameState.equipped("armor")
	var helmet := GameState.equipped("helmet")
	var layers := [["hero_legs", null], [ARMOR_SHEETS.get(armor, "hero_torso_plain"), null],
			["hero_head_male", null]]
	if HELMET_SHEETS.has(helmet):
		layers.append([HELMET_SHEETS[helmet], null])
	look.set_look(layers)


func item(slot: String):
	var id := GameState.equipped(slot)
	return Data.table("items").get(id) if id else null


# ------------------------------------------------------------ ввод
## Запоминает нажатия. Вызывается каждый кадр, даже во время стоп-кадра.
func poll_input() -> void:
	if Controls.pressed("jump"):
		jump_buf = jump_buffer


# ------------------------------------------------------------ логика
func tick(world) -> void:
	var level: Level = world.level
	if dead:
		dead_t += 1
		apply_gravity()
		vx *= 0.9
		move(level)
		return
	for timer in ["invuln", "flash"]:
		if get(timer) > 0:
			set(timer, get(timer) - 1)
	anim_t += 1
	var direction := Controls.direction()

	call("_st_" + state, world, direction)
	if jump_buf > 0:
		jump_buf -= 1

	apply_gravity()
	var was_on_ground := on_ground
	move(level, drop_t > 0)
	if drop_t > 0:
		drop_t -= 1
	if on_ground:
		coyote = coyote_frames
		if not was_on_ground and vy == 0:
			world.dust(cx, y + h, 3)
	elif coyote > 0:
		coyote -= 1

	# --- колья и падение за край мира
	if level.touches_spikes(x, y, w, h) or y > level.pixel_h:
		hurt_by_hazard(world)
	elif on_ground and not on_platform:
		var ty := floori((y + h) / Level.TILE)
		if level.is_solid(floori(x / Level.TILE), ty) and level.is_solid(floori((x + w - 0.02) / Level.TILE), ty):
			safe_x = x
			safe_y = y


func _to_state(new_state: String, t := 0) -> void:
	state = new_state
	state_t = t


func _walk(direction: int, top_scale := 1.0, turn := true) -> void:
	if direction and turn:
		facing = direction
	var accel := ACCEL if on_ground else AIR_ACCEL
	var top := max_speed * top_scale
	if direction:
		vx = clampf(vx + direction * accel, -top, top)
	else:
		_brake(accel)


func _brake(amount: float) -> void:
	if absf(vx) <= amount:
		vx = 0
	else:
		vx -= amount * signf(vx)


func _st_move(world, direction: int) -> void:
	_walk(direction)
	if jump_buf > 0 and (on_ground or coyote > 0):
		if Controls.held("move_down") and on_platform:
			drop_t = 10
		else:
			vy = jump_v
			coyote = 0
			Audio.sfx("jump")
			world.dust(cx, y + h)
		jump_buf = 0
	if vy < JUMP_CUT and not Controls.held("jump"):
		vy = JUMP_CUT


# ------------------------------------------------------------ урон
func hurt_by_hazard(world) -> void:
	var was_invuln := invuln
	invuln = 0
	_apply_damage(2, cx, world)
	if not dead:
		x = safe_x
		y = safe_y
		vx = 0
		vy = 0
		_to_state("move")
		invuln = maxi(invuln, was_invuln)


func _apply_damage(dmg: int, from_x: float, _world, knock := 1.0) -> void:
	var actual := maxi(1, ceili(dmg * 6.0 / 6.0))  # защита — шаг 7
	GameState.hp -= actual
	invuln = invuln_frames
	flash = 8
	var side := 1 if cx >= from_x else -1
	vx = side * 4.4 * knock
	vy = -4.4 * knock
	if GameState.hp <= 0:
		GameState.hp = 0
		dead = true
		Audio.sfx("death")
	else:
		Audio.sfx("hurt")


# ------------------------------------------------------------ отрисовка
func frame() -> int:
	if dead:
		return HumanoidLook.anim_at("death", dead_t / 40.0)
	if state == "stun" or flash:
		return HumanoidLook.anim("hurt")
	if not on_ground:
		return HumanoidLook.anim("jump" if vy < 0 else "fall")
	if absf(vx) > 0.4 and state == "move":
		return HumanoidLook.anim("run", anim_t / 5)
	return HumanoidLook.anim("idle", Engine.get_physics_frames() / 15)


func sync() -> void:
	super.sync()
	if not is_node_ready():
		return
	visible = dead or not (invuln > 0 and (invuln / 3) % 2)
	look.show_frame(frame(), facing, item("weapon"), item("shield"), null, state == "block", flash > 0)
