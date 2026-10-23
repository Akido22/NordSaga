class_name Wolf
extends Enemy
## Волк: замечает героя, приседает (глаза вспыхивают) и бросается в выпад.

const SHEET := preload("res://assets/sprites/characters/wolf.png")
const SHADER := preload("res://scripts/shaders/palette_swap.gdshader")

static var info := {}

var lunge_dmg := 3
var crouch_frames := 20
var lunge_cd_frames := 90
var lunge_range := 88.0
var chase_speed := 2.5
var patrol_speed := 1.0

var lunge_cd := 0
var crouch_t := 0
var lunging := false
var lunge_t := 0
var _sprite: Sprite2D


func _init() -> void:
	w = 36
	h = 22
	var d := load_stats("wolf")
	lunge_dmg = int(d.lunge_damage)
	crouch_frames = int(d.crouch_frames)
	lunge_cd_frames = int(d.lunge_cooldown)
	lunge_range = float(d.lunge_range)
	chase_speed = float(d.chase_speed)
	patrol_speed = float(d.patrol_speed)


func _ready() -> void:
	super._ready()
	if info.is_empty():
		info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/characters/wolf.json"))
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.material = ShaderMaterial.new()
	_sprite.material.shader = SHADER
	add_child(_sprite)
	move_child(_sprite, 0)


func interrupt() -> void:
	crouch_t = 0
	lunging = false


func current_contact_dmg() -> int:
	return lunge_dmg if lunging else contact_dmg


func think(world) -> void:
	if lunge_cd > 0:
		lunge_cd -= 1
	if lunging:
		lunge_t += 1
		if lunge_t > 4 and on_ground:
			lunging = false
			vx *= 0.3
		return
	if crouch_t > 0:  # присед перед прыжком — подсказка игроку
		crouch_t -= 1
		vx = 0
		if crouch_t == 0:
			vx = facing * 5.2
			vy = -4.8
			lunging = true
			lunge_t = 0
			lunge_cd = lunge_cd_frames
		return
	if not on_ground:
		return
	var p: Player = world.player
	if player_near(world, sight):
		facing = 1 if p.cx - cx >= 0 else -1
		if not ground_ahead(world.level, facing):
			vx = 0
		elif absf(p.cx - cx) < lunge_range and lunge_cd == 0:
			crouch_t = crouch_frames
			vx = 0
		else:
			vx = facing * chase_speed
	else:
		patrol(world, patrol_speed)


func sync() -> void:
	super.sync()
	if _sprite == null:
		return
	var anim := "idle"
	var i := 0
	if crouch_t:
		anim = "crouch"
	elif not on_ground:
		anim = "leap"
	elif absf(vx) > 0.2:
		anim = "run"
		i = anim_t / 6
	var frames: Array = info.anims[anim]
	var n := int(frames[posmod(i, frames.size())])
	var fw: float = info.frame_w
	var fh: float = info.frame_h
	_sprite.region_rect = Rect2(n * fw, 0, fw, fh)
	_sprite.flip_h = facing < 0
	_sprite.position = Vector2(w / 2 - fw / 2, h + 2 - fh)
	var eyes := {"a": "8"} if crouch_t and (crouch_t / 3) % 2 else {}  # глаза вспыхивают
	HumanoidLook._apply(_sprite.material, eyes, flash > 0)
