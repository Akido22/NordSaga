class_name Draugr
extends Enemy
## Драугр с ржавым мечом: подходит, замахивается (глаза вспыхивают) и рубит.
## После удара — передышка, время бить в ответ.

var strike_dmg := 4
var reach := 36.0
var windup := 34
var recover := 40
var chase_speed := 1.1
var patrol_speed := 0.6

var state := "walk"  # walk, windup, strike, recover
var state_t := 0
var struck := false
var look: HumanoidLook


func _init() -> void:
	w = 20
	h = 44
	_load_draugr()


func _load_draugr() -> void:
	var d := load_stats("draugr")
	strike_dmg = int(d.strike_damage)
	reach = float(d.reach)
	windup = int(d.windup_frames)
	recover = int(d.recover_frames)
	chase_speed = float(d.chase_speed)
	patrol_speed = float(d.patrol_speed)


func _ready() -> void:
	super._ready()
	look = HumanoidLook.new()
	look.position = Vector2(w / 2, h)
	add_child(look)
	move_child(look, 0)
	look.set_look(_look())


func _look() -> Array:
	return Looks.DRAUGR


func _to_state(s: String, t: int) -> void:
	state = s
	state_t = t


func interrupt() -> void:
	if state in ["windup", "strike"]:
		_to_state("recover", 24)


func think(world) -> void:
	var p: Player = world.player
	if state == "walk":
		if player_near(world, sight, 48):
			facing = 1 if p.cx - cx >= 0 else -1
			if absf(p.cx - cx) < 40:
				_to_state("windup", windup)
				vx = 0
			elif ground_ahead(world.level, facing):
				vx = facing * chase_speed
			else:
				vx = 0
		else:
			patrol(world, patrol_speed)
		return
	vx = 0
	state_t -= 1
	if state == "strike" and not struck and not p.dead:
		var hx := x + w if facing > 0 else x - reach
		if p.x < hx + reach and hx < p.x + p.w and p.y < y + h and y < p.y + p.h:
			if p.take_damage(strike_dmg, cx, world, true, self) != "miss":
				struck = true
	if state_t <= 0:
		if state == "windup":
			_to_state("strike", 12)
			struck = false
			Audio.sfx("swing")
		elif state == "strike":
			_to_state("recover", recover)
		else:
			_to_state("walk", 0)


## Кадр для текущего состояния.
func pose() -> int:
	if stun_t > 0 or hurt_t > 0:
		return HumanoidLook.anim("hurt")
	match state:
		"strike": return HumanoidLook.anim("attack", 2)
		"windup": return HumanoidLook.anim("attack", 0)
		"recover": return HumanoidLook.anim("attack", 3)
	if absf(vx) > 0.1:
		return HumanoidLook.anim("run", anim_t / 7)
	return HumanoidLook.anim("idle", anim_t / 18)


func sync() -> void:
	super.sync()
	if look != null:
		_show_look()


func _eyes() -> Dictionary:
	return {"c": "8"} if state == "windup" and (state_t / 4) % 2 else {}  # вспышка глаз


func _show_look() -> void:
	look.show_frame(pose(), facing, Looks.RUSTY_SWORD, null, null, false, flash > 0, _eyes())
