class_name Player
extends TileBody
## Герой: движение и бой — выносливость, перекат, блок и парирование, серия ударов,
## тяжёлый удар, удар в падении. Чары — шаг 7.
## Логика идёт кадрами (tick), как в Pyxel-версии; числа — data/player.toml, x2.

const ACCEL := 0.56
const AIR_ACCEL := 0.36
const JUMP_CUT := -3.2  # прыжок отпущен — подъём обрывается до этой скорости
const ROLL_SPEED := 5.4
const PLUNGE_SPEED := 8.8
const PLUNGE_BOUNCE := -6.8
const ARMOR_SHEETS := {"shirt": "hero_torso_shirt", "leather": "hero_torso_leather", "mail": "hero_torso_mail"}
const HELMET_SHEETS := {"cap": "hero_helmet_cap", "shishak": "hero_helmet_shishak"}
## Кулак — когда оружия нет.
const FIST := {"id": "fist", "icon": "", "atk": 0, "reach": 18, "swing": 14, "stamina": 8}

var max_speed: float
var jump_v: float
var coyote_frames: int
var jump_buffer: int
var invuln_frames: int
var roll_time: int
var roll_iframes: Array
var stamina_regen: float
var stamina_delay: int
var exhaust_delay: int
var roll_cost: int
var heavy_cost: int
var plunge_cost: int
var parry_window: int
var block_cooldown: int
var charge_time: int
var combo_max: int
var input_buffer: int
var mana_regen: float

var facing := 1
var state := "move"  # move, attack, charge, plunge, roll, block, stun, recover; шаг 7: cast
var state_t := 0
var anim_t := 0
var attack_kind := ""  # light, heavy, air, plunge
var attack_t := 0
var attack_dur := 1
var combo := 0
var queued := 0  # сколько ударов серии ждут своей очереди
var charge := 0
var hit_ids := {}
var block_t := 0
var block_cd := 0
var stamina := 0.0
var mana := 0.0
var shield_t := 0  # щит Перуна (шаг 7)
var stamina_wait := 0
var stamina_flash := 0
var invuln := 0
var coyote := 0
var jump_buf := 0
var buf_attack := 0
var buf_roll := 0
var drop_t := 0
var flash := 0
var dead := false
var dead_t := 0
var safe_x := 0.0  # куда вернуть после кольев (float64: Vector2 — 32 бита)
var safe_y := 0.0

@onready var look: HumanoidLook = $Look
var _fx: Node2D  # след клинка и звёздочки оглушения — поверх облика


func _init() -> void:
	w = 20.0
	h = 44.0
	var p: Dictionary = Data.table("player")
	max_speed = p.movement.max_speed
	jump_v = -float(p.movement.jump_velocity)
	coyote_frames = int(p.movement.coyote_frames)
	jump_buffer = int(p.movement.jump_buffer)
	invuln_frames = int(p.combat.invuln_frames)
	roll_time = int(p.combat.roll_frames)
	roll_iframes = p.combat.roll_iframes
	parry_window = int(p.combat.parry_window)
	block_cooldown = int(p.combat.block_cooldown)
	charge_time = int(p.combat.charge_frames)
	combo_max = int(p.combat.combo_max)
	input_buffer = int(p.combat.input_buffer)
	stamina_regen = p.stamina.regen
	stamina_delay = int(p.stamina.delay)
	exhaust_delay = int(p.stamina.exhaust_delay)
	roll_cost = int(p.stamina.roll_cost)
	heavy_cost = int(p.stamina.heavy_cost)
	plunge_cost = int(p.stamina.plunge_cost)
	mana_regen = p.magic.mana_regen
	stamina = GameState.max_stamina()
	mana = GameState.max_mana()


func _ready() -> void:
	look.position = Vector2(w / 2, h)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
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


## Оружие в руке или кулак.
func weapon() -> Dictionary:
	var it = item("weapon")
	return it if it != null else FIST


# ------------------------------------------------------------ выносливость
func spend(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	stamina_wait = exhaust_delay if stamina <= 0 else stamina_delay


## Действие разрешено, пока есть хоть немного сил (как в souls-играх).
func can_act() -> bool:
	if stamina > 0:
		return true
	stamina_flash = 20
	return false


func _regen() -> void:
	if stamina_wait > 0:
		stamina_wait -= 1
		return
	var rate := stamina_regen * (0.35 if state == "block" else 1.0)
	stamina = minf(GameState.max_stamina(), stamina + rate)


# ------------------------------------------------------------ ввод
## Запоминает нажатия. Вызывается каждый кадр, даже во время стоп-кадра.
func poll_input() -> void:
	if Controls.pressed("attack"):
		buf_attack = input_buffer
	if Controls.pressed("roll"):
		buf_roll = input_buffer
	if Controls.pressed("jump"):
		jump_buf = jump_buffer


## Забирает запомненное нажатие ("attack" или "roll").
func _take(buf: String) -> bool:
	var attr := "buf_" + buf
	if get(attr) > 0:
		set(attr, 0)
		return true
	return false


# ------------------------------------------------------------ логика
func tick(world) -> void:
	var level: Level = world.level
	if dead:
		dead_t += 1
		apply_gravity()
		vx *= 0.9
		move(level)
		return

	_regen()
	mana = minf(GameState.max_mana(), mana + mana_regen)
	for timer in ["invuln", "flash", "stamina_flash", "block_cd", "shield_t"]:
		if get(timer) > 0:
			set(timer, get(timer) - 1)
	anim_t += 1
	var direction := Controls.direction()

	call("_st_" + state, world, direction)
	for timer in ["buf_attack", "buf_roll", "jump_buf"]:
		if get(timer) > 0:
			set(timer, get(timer) - 1)

	if state != "plunge":
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

	if state == "plunge":
		_plunge_contact(world)

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


# --- обычное движение и начало действий
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

	if buf_roll and on_ground:
		buf_roll = 0
		if can_act():
			_start_roll(world, direction)
	elif Controls.held("block") and on_ground and block_cd == 0:
		_to_state("block")
		block_t = 0
	elif _take("attack"):
		if can_act():
			if not on_ground and Controls.held("move_down"):
				_start_attack(world, "plunge")
			else:
				combo = 0
				_start_attack(world, "light" if on_ground else "air")


# --- перекат
func _start_roll(world, direction: int) -> void:
	spend(roll_cost)
	if direction:
		facing = direction
	_to_state("roll", roll_time)
	Audio.sfx("roll")
	world.dust(cx, y + h, 4)


func rolling_invuln() -> bool:
	if state != "roll":
		return false
	var t := roll_time - state_t
	return int(roll_iframes[0]) <= t and t <= int(roll_iframes[1])


func _st_roll(_world, _direction: int) -> void:
	var t := roll_time - state_t
	var speed := ROLL_SPEED if t < 14 else ROLL_SPEED * maxf(0.0, (roll_time - t) / 8.0)
	vx = facing * speed
	state_t -= 1
	if state_t <= 0:
		_to_state("move")


# --- блок и парирование
func _st_block(world, direction: int) -> void:
	block_t += 1
	_brake(0.6)
	if not Controls.held("block") or not on_ground:
		block_cd = block_cooldown
		_to_state("move")
	elif _take("roll") and can_act():
		block_cd = block_cooldown
		_start_roll(world, direction)


func _parry(world, source) -> void:
	Audio.sfx("parry")
	world.freeze(8)
	world.shake(2)
	var fx := cx + facing * 16
	world.sparks(fx, y + 12, 14)
	world.float_text(fx, y - 12, "ПАРИРОВАНО", Pal.GOLD)
	stamina = minf(GameState.max_stamina(), stamina + 15)
	if source != null and source.has_method("on_parried"):
		source.on_parried(world, self)


# --- оглушение (пробитый блок, пропущенный удар) и короткое восстановление
func _st_stun(_world, _direction: int) -> void:
	_brake(0.3)
	state_t -= 1
	if state_t <= 0:
		_to_state("move")


func _st_recover(world, direction: int) -> void:
	_st_stun(world, direction)


# --- удары
func _start_attack(world, kind: String) -> void:
	var wpn := weapon()
	var cost: int = {"heavy": heavy_cost, "plunge": plunge_cost}.get(kind, int(wpn.get("stamina", 8)))
	spend(cost)
	attack_kind = kind
	hit_ids.clear()
	if kind != "light" or combo == 0:
		queued = 0
	if kind == "plunge":
		_to_state("plunge")
		vy = PLUNGE_SPEED
		Audio.sfx("swing")
		return
	var dur := int(wpn.get("swing", 14))
	if kind == "heavy":
		dur = int(dur * 1.5) + 6
		Audio.sfx("heavy")
	else:
		if kind == "light" and combo == combo_max - 1:
			dur = int(dur * 1.15)
		Audio.sfx("swing")
	attack_dur = dur
	attack_t = dur
	_to_state("attack")


func attack_progress() -> float:
	return 1.0 - float(attack_t) / maxi(1, attack_dur)


func attack_active() -> bool:
	if state != "attack":
		return false
	var lo := 0.35 if attack_kind == "heavy" else 0.2
	var hi := 0.8 if attack_kind == "heavy" else 0.75
	var p := attack_progress()
	return lo <= p and p <= hi


func attack_damage() -> int:
	var atk := GameState.attack()
	if attack_kind == "heavy":
		return atk * 2
	if attack_kind == "plunge":
		return ceili(atk * 1.5)
	if attack_kind == "light" and combo == combo_max - 1:
		return ceili(atk * 1.3)
	return atk


## Прямоугольник удара: [x, y, ширина, высота].
func attack_box() -> Array:
	var reach := float(weapon().get("reach", 18)) + (8 if attack_kind == "heavy" else 0)
	var hx := x + w if facing > 0 else x - reach
	return [hx, y - 4, reach, h]


func _st_attack(world, direction: int) -> void:
	var on_ground_attack := attack_kind in ["light", "heavy"] and on_ground
	if on_ground_attack:
		_walk(direction, 0.45 if attack_kind == "light" else 0.2, false)
	else:
		_walk(direction, 1.0, false)
	if attack_active():
		var b := attack_box()
		_hit_box(world, b[0], b[1], b[2], b[3])
	if attack_kind == "light" and buf_attack:
		buf_attack = 0
		queued = mini(combo_max - 1 - combo, queued + 1)
	attack_t -= 1
	if attack_t > 0:
		return
	if attack_kind == "light" and queued > 0 and combo < combo_max - 1 and on_ground:
		if can_act():
			queued -= 1
			combo += 1
			if direction:
				facing = direction
			_start_attack(world, "light")
			return
	if attack_kind == "light" and Controls.held("attack") and on_ground:
		charge = 0
		_to_state("charge")
		return
	combo = 0
	_to_state("move")


func _st_charge(world, direction: int) -> void:
	_walk(direction, 0.3, false)
	charge += 1
	if charge == charge_time:
		Audio.sfx("charged")
		world.sparks(cx + facing * 12, y + 8, 4)
	if _take("roll") and can_act():
		_start_roll(world, direction)
	elif not Controls.held("attack"):
		if charge >= charge_time and can_act():
			combo = 0
			_start_attack(world, "heavy")
			world.shake(2)
		else:
			_to_state("move")


func _st_plunge(world, _direction: int) -> void:
	_brake(0.2)
	vy = PLUNGE_SPEED
	if on_ground:
		world.dust(cx, y + h, 6)
		world.shake(2)
		_to_state("recover", 12)


func _plunge_contact(world) -> void:
	if state != "plunge":
		return
	if _hit_box(world, x - 6, y + h - 4, w + 12, 20):
		vy = PLUNGE_BOUNCE
		_to_state("move")


## Бьёт врагов и стрелы в прямоугольнике. Возвращает true, если по кому-то попал.
func _hit_box(world, hx: float, hy: float, hw: float, hh: float) -> bool:
	var hit_any := false
	for enemy in world.enemies:
		var eid: int = enemy.get_instance_id()
		if hit_ids.has(eid) or enemy.dead or not enemy.overlaps(hx, hy, hw, hh):
			continue
		hit_ids[eid] = true
		hit_any = true
		var result: String = enemy.take_hit(attack_damage(), facing, world,
				attack_kind == "heavy", attack_kind == "plunge")
		if result == "blocked":
			Audio.sfx("block")
			vx = -facing * 3.2
			spend(10)
			world.freeze(3)
	for arrow in world.projectiles:
		if arrow.deflectable() and arrow.overlaps(hx, hy, hw, hh):
			arrow.deflect(world)
			hit_any = true
	return hit_any


# ------------------------------------------------------------ урон
## Возвращает "miss", "parry", "blocked" или "hit".
func take_damage(dmg: int, from_x: float, world, parryable := true, source = null, unblockable := false) -> String:
	if dead or invuln > 0 or rolling_invuln():
		return "miss"
	if shield_t > 0 and not unblockable:
		Audio.sfx("block")
		world.sparks(cx, cy, 6)
		if source != null and source.has_method("on_blocked"):
			source.on_blocked(world, self)
		return "blocked"
	var front := (from_x - cx) * facing >= 0
	if state == "block" and front and not unblockable:
		if parryable and block_t <= parry_window:
			_parry(world, source)
			return "parry"
		var shield = item("shield")
		var cost := maxi(8, dmg * 9 - (int(shield.get("defense", 0)) * 4 if shield != null else 0))
		if shield == null:
			cost = int(cost * 1.3)
		if stamina >= cost:
			spend(cost)
			Audio.sfx("block")
			world.sparks(cx + facing * 14, y + 12, 6)
			world.freeze(3)
			vx = -facing * 2.4
			if source != null and source.has_method("on_blocked"):
				source.on_blocked(world, self)
			if shield != null:
				return "blocked"
			dmg = ceili(dmg * 0.5)  # без щита часть удара проходит
		else:
			stamina = 0
			stamina_wait = exhaust_delay
			stamina_flash = 30
			Audio.sfx("guard_break")
			world.float_text(cx, y - 24, "ЩИТ ПРОБИТ", Pal.RED)
			dmg = ceili(dmg * 0.5)
			_to_state("stun", 45)
			_apply_damage(dmg, from_x, world, 0.8)
			return "hit"
	_apply_damage(dmg, from_x, world)
	if not dead:
		_to_state("stun", 14)
	return "hit"


func _apply_damage(dmg: int, from_x: float, world, knock := 1.0) -> void:
	var actual := maxi(1, ceili(dmg * 6.0 / (6 + GameState.defense())))
	GameState.hp -= actual
	invuln = invuln_frames
	flash = 8
	combo = 0
	var side := 1 if cx >= from_x else -1
	vx = side * 4.4 * knock
	vy = -4.4 * knock
	world.float_text(cx, y - 8, "-%d" % actual, Pal.RED)
	world.shake(4)
	if GameState.hp <= 0:
		GameState.hp = 0
		dead = true
		Audio.sfx("death")
	else:
		Audio.sfx("hurt")


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


func heal(amount: int) -> int:
	var before := GameState.hp
	GameState.hp = mini(GameState.max_hp(), GameState.hp + amount)
	return GameState.hp - before


# ------------------------------------------------------------ отрисовка
func frame() -> int:
	if dead:
		return HumanoidLook.anim_at("death", dead_t / 40.0)
	match state:
		"roll":
			return HumanoidLook.anim_at("roll", 1.0 - float(state_t) / roll_time)
		"attack":
			var p := attack_progress()
			if attack_kind == "heavy":
				return HumanoidLook.anim_at("heavy", p, 1)
			return HumanoidLook.anim_at("attack2" if attack_kind == "light" and combo == 1 else "attack", p)
		"charge":
			return HumanoidLook.anim("heavy", 0)
		"plunge":
			return HumanoidLook.anim("plunge")
		"block":
			return HumanoidLook.anim("block")
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
	var wpn = item("weapon")
	var charged := state == "charge" and charge >= charge_time and (anim_t / 3) % 2
	look.show_frame(frame(), facing,
			null if state == "roll" or dead else wpn,
			item("shield") if state != "roll" else null,
			null, state == "block", flash > 0, {},
			{"6": "a", "f": "a"} if charged else {})
	_fx.queue_redraw()


func _draw_fx() -> void:
	var f := frame()
	var wpn = item("weapon")
	if attack_active() and wpn != null:
		_draw_slash(f)
	if state == "stun" and state_t > 14:
		_draw_stun_stars()


## Дуга-след за клинком (в локальных координатах героя).
func _draw_slash(f: int) -> void:
	var angle = HumanoidLook.info(f).weapon
	if angle == null:
		return
	var heavy := attack_kind == "heavy"
	var hand := HumanoidLook.anchor(f, "hand", w / 2, h, facing)
	var r := 28.0 + (8.0 if heavy else 0.0)
	var back := 1 if attack_kind == "light" and combo == 1 else -1
	for i in (12 if heavy else 8):
		var a := deg_to_rad(float(angle) + back * i * 8)
		var p := Vector2(hand.x + sin(a) * r * facing, hand.y - cos(a) * r)
		var col := (Pal.GOLD if i < 5 else Pal.FIRE) if heavy else (Pal.SNOW if i < 3 else Pal.LINEN)
		_fx.draw_rect(Rect2(p.floor(), Vector2(2, 4 if heavy else 2)), col)


func _draw_stun_stars() -> void:
	var t := Engine.get_physics_frames()
	for i in 3:
		var a := t * 0.15 + i * 2.1
		_fx.draw_rect(Rect2(Vector2(w / 2 + cos(a) * 10, -14 + sin(a) * 3).floor(), Vector2(2, 2)),
				Pal.GOLD if i % 2 else Pal.SNOW)
