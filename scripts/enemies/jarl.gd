class_name JarlBoss
extends Enemy
## Ярл-драугр Хрёрек — владыка кургана. Атаки читаются по позе и вспышке:
##   * серия из трёх рубящих ударов — парируется, после парирования ярл оглушён;
##   * прыжок с ударом оземь — по полу расходятся две ударные волны;
##   * круговой удар (вторая фаза) — тело вспыхивает красным: щитом не отразить.
## На половине здоровья ярл впадает в ярость: зовёт волков, атакует быстрее.

var boss_name := "ЯРЛ-ДРАУГР ХРЁРЕК"
var subtitle := "Владыка кургана"
var flag := "boss:jarl"
var chain_dmg := 4
var slam_dmg := 5
var sweep_dmg := 5
var shock_dmg := 3
var rage_at := 0.5
var rage_speed := 1.3
var walk_speed := 1.1
var chain_reach := 64.0
var chain_windup := 24
var chain_next := 15
var chain_recover := 50
var stun_frames := 70
var rage_stun := 50
var shock_speed := 4.6
var rage_shock_speed := 5.6
var leap_windup := 34
var slam_recover := 46
var leap_distance := 140.0
var sweep_reach := 76.0
var sweep_windup := 40
var sweep_recover := 45
var sweep_chance := 0.4

var state := "sleep"
var state_t := 0
var phase := 1
var combo_n := 0
var struck := false
var attack_cd := 30
var dying := false
var leap_t := 0
var look: HumanoidLook


func _init() -> void:
	w = 40
	h = 88
	kind = "jarl"
	var d: Dictionary = Data.table("bosses").jarl
	boss_name = d.name
	subtitle = d.subtitle
	max_hp = int(d.hp)
	hp = max_hp
	contact_dmg = int(d.contact_damage)
	knock = 0
	xp = int(d.xp)
	silver = [int(d.silver), int(d.silver)]
	rage_at = float(d.rage_at)
	rage_speed = float(d.rage_speed)
	walk_speed = float(d.walk_speed)
	chain_dmg = int(d.chain_damage)
	chain_reach = float(d.chain_reach)
	chain_windup = int(d.chain_windup)
	chain_next = int(d.chain_next)
	chain_recover = int(d.chain_recover)
	stun_frames = int(d.stun_frames)
	rage_stun = int(d.rage_stun_frames)
	slam_dmg = int(d.slam_damage)
	shock_dmg = int(d.shockwave_damage)
	shock_speed = float(d.shockwave_speed)
	rage_shock_speed = float(d.rage_shockwave_speed)
	leap_windup = int(d.leap_windup)
	slam_recover = int(d.slam_recover)
	leap_distance = float(d.leap_distance)
	sweep_dmg = int(d.sweep_damage)
	sweep_reach = float(d.sweep_reach)
	sweep_windup = int(d.sweep_windup)
	sweep_recover = int(d.sweep_recover)
	sweep_chance = float(d.sweep_chance)


func _ready() -> void:
	super._ready()
	look = HumanoidLook.new()
	look.zoom = 2.0
	look.position = Vector2(w / 2, h)
	add_child(look)
	move_child(look, 0)
	look.set_look(Looks.JARL)


# ------------------------------------------------------------ свойства
var awake: bool:
	get: return state != "sleep" and not dead


func speed() -> float:
	return rage_speed if phase == 2 else 1.0


func vulnerable() -> bool:
	return not state in ["sleep", "rise", "roar"] and not dying


func _to_state(s: String, t := 0.0) -> void:
	state = s
	state_t = int(t)


static func _sign(v: float) -> int:
	return 1 if v >= 0 else -1


func _box_hits(p: Player, bx: float, by: float, bw: float, bh: float) -> bool:
	return bx < p.x + p.w and p.x < bx + bw and by < p.y + p.h and p.y < by + bh


# ------------------------------------------------------------ урон
func take_hit(dmg: int, direction: int, world, heavy := false, _plunge := false) -> String:
	if not vulnerable():
		world.sparks(cx - direction * 12, y + 24, 4)
		return "blocked"
	var crit := stun_t > 0
	if crit:
		dmg = ceili(dmg * 2.5)
		stun_t = 0
		_to_state("recover", 20)
		world.float_text(cx, y - 28, "КРИТ!", Pal.GOLD)
	hp -= dmg
	flash = 6
	world.float_text(cx, y - 8, str(dmg), Pal.SNOW if crit else Pal.GOLD)
	world.sparks(cx - direction * 12, y + 24, 12 if crit or heavy else 6)
	world.freeze(7 if crit else 5 if heavy else 3)
	if crit or heavy:
		world.shake(3)
	if hp <= 0:
		hp = 0
		dying = true
		_to_state("dying", 120)
		stun_t = 0
		Audio.sfx("roar")
		world.shake(8)
	elif phase == 1 and hp <= max_hp * rage_at:
		_to_state("roar", 80)
		stun_t = 0
		Audio.sfx("heavy")
	else:
		Audio.sfx("heavy" if crit or heavy else "hit")
	return "hit"


func on_parried(_world, _player) -> void:
	if state == "chain_strike":
		stun_t = stun_frames if phase == 1 else rage_stun
		_to_state("recover", 30)
		vx = 0


func on_blocked(_world, _player) -> void:
	pass  # ярла щитом не оттолкнуть


# ------------------------------------------------------------ цикл
func tick(world) -> void:
	anim_t += 1
	if flash > 0:
		flash -= 1
	if contact_cd > 0:
		contact_cd -= 1
	if dying:
		_tick_dying(world)
		return
	if stun_t > 0:
		stun_t -= 1
		vx *= 0.8
	else:
		think(world)
	apply_gravity()
	move(world.level, true)
	var p: Player = world.player
	if (vulnerable() and not p.dead and contact_cd == 0 and stun_t == 0
			and _box_hits(p, x + 6, y, w - 12, h)):
		if p.take_damage(contact_dmg, cx, world, false, self) != "miss":
			contact_cd = 40


func _tick_dying(world) -> void:
	state_t -= 1
	vx = 0
	if state_t % 12 == 0:
		world.effects.smoke(cx + randf_range(-16, 16), y + randf_range(8, 52), 6)
		world.sparks(cx, y + 28, 4)
	if state_t <= 0:
		dead = true
		world.on_boss_defeated(self)


func think(world) -> void:
	var p: Player = world.player
	var dx := p.cx - cx
	var dist := absf(dx)
	match state:
		"sleep":
			if world.arena_trigger >= 0 and p.cx > world.arena_trigger and not p.dead:
				world.start_boss_fight(self)
				_to_state("rise", 90)
		"rise":
			state_t -= 1
			if state_t == 45:
				Audio.sfx("roar")
				world.shake(6)
			if state_t <= 0:
				_to_state("walk")
		"roar":
			vx = 0
			state_t -= 1
			if state_t == 60:
				Audio.sfx("roar")
				world.shake(8)
				world.float_text(cx, y - 28, "ЯРОСТЬ!", Pal.RED)
				phase = 2
				world.summon_wolves()
			if state_t <= 0:
				_to_state("walk")
				attack_cd = 10
		"walk":
			facing = _sign(dx)
			if attack_cd > 0:
				attack_cd -= 1
			if p.dead:
				vx = 0
				return
			if attack_cd <= 0:
				if phase == 2 and dist < 88 and world.rand() < sweep_chance:
					_to_state("sweep_wind", sweep_windup / speed())
					vx = 0
					return
				if dist < 68:
					combo_n = 0
					_to_state("chain_wind", chain_windup / speed())
					vx = 0
					return
				if dist > leap_distance or world.rand() < 0.02:
					_to_state("leap_wind", leap_windup / speed())
					vx = 0
					return
			vx = facing * walk_speed * speed() if dist > 52 else 0.0
		"chain_wind":
			vx = 0
			state_t -= 1
			if state_t <= 0:
				_to_state("chain_strike", 9)
				struck = false
				vx = facing * 2.4
				Audio.sfx("swing")
		"chain_strike":
			vx *= 0.8
			state_t -= 1
			var hx := x + w if facing > 0 else x - chain_reach
			if not struck and _box_hits(p, hx, y + 8, chain_reach, h - 8):
				if p.take_damage(chain_dmg, cx, world, true, self) != "miss":
					struck = true
			if state == "chain_strike" and state_t <= 0:
				combo_n += 1
				if combo_n < 3:
					facing = _sign(dx)
					_to_state("chain_wind", chain_next / speed())
				else:
					_to_state("recover", chain_recover / speed())
		"leap_wind":
			vx = 0
			state_t -= 1
			if state_t <= 0:
				var air := 2 * 10.4 / 0.44
				vx = clampf(dx / air, -6.0, 6.0)
				vy = -10.4
				leap_t = 0
				_to_state("leap")
				Audio.sfx("jump")
		"leap":
			leap_t += 1
			if leap_t > 6 and on_ground:
				_slam(world)
		"sweep_wind":
			vx = 0
			state_t -= 1
			if state_t <= 0:
				_to_state("sweep", 18)
				struck = false
				Audio.sfx("heavy")
		"sweep":
			state_t -= 1
			if not struck and _box_hits(p, x - sweep_reach, y + 8, w + sweep_reach * 2, h - 8):
				if p.take_damage(sweep_dmg, cx, world, false, self) != "miss":
					struck = true
			if state_t <= 0:
				_to_state("recover", sweep_recover / speed())
		"recover":
			vx *= 0.7
			state_t -= 1
			if state_t <= 0:
				_to_state("walk")
				attack_cd = 24 if phase == 1 else 12


func _slam(world) -> void:
	vx = 0
	var ground := y + h
	Audio.sfx("slam")
	world.shake(7)
	world.dust(cx, ground, 12)
	var sp := rage_shock_speed if phase == 2 else shock_speed
	world.add_projectile(Shockwave.create(cx - 20, ground, -sp, shock_dmg))
	world.add_projectile(Shockwave.create(cx + 20, ground, sp, shock_dmg))
	var p: Player = world.player
	if _box_hits(p, x - 12, ground - 24, w + 24, 24):
		p.take_damage(slam_dmg, cx, world, false, self)
	_to_state("recover", slam_recover / speed())


# ------------------------------------------------------------ отрисовка
func pose() -> int:
	var t := anim_t
	if state == "dying":
		return HumanoidLook.anim_at("death", (120 - state_t) / 100.0)
	if stun_t > 0 or state == "roar":
		return HumanoidLook.anim("hurt")
	match state:
		"sleep", "rise": return HumanoidLook.anim("idle", 0)
		"chain_wind": return HumanoidLook.anim("attack", 0)
		"chain_strike": return HumanoidLook.anim("attack" if combo_n % 2 == 0 else "attack2", 2)
		"leap_wind", "sweep_wind": return HumanoidLook.anim("heavy", 0)
		"leap": return HumanoidLook.anim("jump" if vy < 0 else "fall")
		"sweep": return HumanoidLook.anim("attack", t / 2)
		"recover": return HumanoidLook.anim("attack", 3)
	if absf(vx) > 0.1:
		return HumanoidLook.anim("run", t / 8)
	return HumanoidLook.anim("idle", Engine.get_physics_frames() / 20)


func sync() -> void:
	super.sync()
	if look == null:
		return
	var extra := {}
	# Цвет глаз: тлеют во сне, синие в первой фазе, красные в ярости.
	if state == "sleep" or (state == "rise" and (state_t / 4) % 2 and state_t > 45):
		extra["c"] = "1"
	elif phase == 2 or (state == "roar" and state_t < 60):
		extra["c"] = "8"
	# Предупреждения: золото — прыжок, красная вспышка — круговой удар.
	if state == "leap_wind" and (state_t / 3) % 2:
		extra.merge({"1": "a", "5": "a"}, true)
	if state == "sweep_wind" and (state_t / 3) % 2:
		for c in range(1, 16):
			extra["%x" % c] = "8"
	var fl := flash > 0 or (state == "dying" and (anim_t / 3) % 2)
	var shaking := state in ["roar", "rise"] and state_t < 60
	look.position = Vector2(w / 2 + (randi_range(-1, 1) * 2 if shaking else 0), h)
	look.show_frame(pose(), facing, Looks.JARL_AXE if state != "dying" else null, null, null, false, fl, extra)


func _draw_fx() -> void:
	draw_status(_fx, -16)
