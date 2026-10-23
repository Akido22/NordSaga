@tool
class_name HumanoidLook
extends Node2D
## Гуманоид из слоёв спрайтов: ноги -> туловище -> голова -> шлем, плюс оружие и щит.
## «Облик» (look) — список [лист, перекраска]; перекраска {"6": "a"} меняет цвет
## палитры 6 на 10, так из одних листов получаются герой, драугры, ярл и жители.
## Узел стоит в середине низа хитбокса; scale.x = -1 разворачивает влево.

const DIR := "res://assets/sprites/characters"
const SHADER := preload("res://scripts/shaders/palette_swap.gdshader")
const BLOCK_ANGLE := 20  # оружие поперёк, когда блок без щита

static var hum := {}  # humanoid.json: кадры, анимации, точки привязки
static var weapons := {}  # weapons.json: ячейка, хват, порядок

var _layers: Array[Sprite2D] = []
var _weapon: Sprite2D
var _front: Node2D  # щит перед собой — поверх слоёв
var _back_shield = null  # предмет-щит за спиной или null
var _front_shield = null
var _back_at := Vector2.ZERO
var _front_at := Vector2.ZERO


static func load_data() -> void:
	if hum.is_empty():
		hum = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/humanoid.json"))
		weapons = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/weapons.json"))


## Кадр анимации по счётчику (зацикленно).
static func anim(anim_name: String, i := 0) -> int:
	load_data()
	var frames: Array = hum.anims[anim_name]
	return int(frames[posmod(i, frames.size())])


## Кадр анимации по доле 0..1 (без зацикливания); start — с какого кадра.
static func anim_at(anim_name: String, progress: float, start := 0) -> int:
	load_data()
	var frames: Array = hum.anims[anim_name].slice(start)
	return int(frames[clampi(int(progress * frames.size()), 0, frames.size() - 1)])


static func info(frame: int) -> Dictionary:
	load_data()
	return hum.frames[frame]


## Точка привязки кадра (hand/back/head) относительно середины низа, без разворота.
static func local_anchor(frame: int, key: String) -> Vector2:
	var p: Array = info(frame)[key]
	return Vector2(p[0] - hum.frame_w / 2.0, p[1] - hum.frame_h)


## Точка привязки в мире: (cx, bottom) — середина низа, facing — 1 или -1.
static func anchor(frame: int, key: String, cx: float, bottom: float, facing: int) -> Vector2:
	var p := local_anchor(frame, key)
	return Vector2(cx + p.x * facing, bottom + p.y)


func _ready() -> void:
	load_data()
	_weapon = Sprite2D.new()
	_weapon.texture = load(DIR + "/weapons.png")
	_weapon.centered = false
	_weapon.region_enabled = true
	_weapon.offset = -Vector2(weapons.grip[0], weapons.grip[1])
	_weapon.material = _material()
	add_child(_weapon)
	_front = Node2D.new()
	_front.draw.connect(_draw_front_shield)
	add_child(_front)


## Задаёт облик: [[лист, перекраска или null], ...].
func set_look(look: Array) -> void:
	for s in _layers:
		s.queue_free()
	_layers.clear()
	for i in look.size():
		var s := Sprite2D.new()
		s.texture = load("%s/%s.png" % [DIR, look[i][0]])
		s.centered = false
		s.region_enabled = true
		s.offset = Vector2(-hum.frame_w / 2.0, -hum.frame_h)
		s.material = _material()
		s.set_meta("tint", look[i][1] if look[i][1] is Dictionary else {})
		add_child(s)
		move_child(s, i)
		_layers.append(s)


## Показывает кадр. weapon/shield — словари предметов из items или null.
## weapon_angle: null — угол из кадра; число — свой угол.
func show_frame(frame: int, facing: int, weapon = null, shield = null, weapon_angle = null,
		shield_front := false, flash := false, extra := {}, weapon_tint := {}) -> void:
	scale.x = facing
	var cols := int(hum.cols)
	var region := Rect2((frame % cols) * hum.frame_w, (frame / cols) * hum.frame_h, hum.frame_w, hum.frame_h)
	for s in _layers:
		s.region_rect = region
		var tint: Dictionary = s.get_meta("tint").duplicate()
		tint.merge(extra, true)
		_apply(s.material, tint, flash)

	var hand := local_anchor(frame, "hand")
	_back_shield = shield if shield != null and not shield_front else null
	_back_at = local_anchor(frame, "back")
	_front_shield = shield if shield_front else null
	_front_at = hand + Vector2(2, 0)

	var angle = info(frame).weapon if weapon_angle == null else weapon_angle
	if shield_front:
		angle = BLOCK_ANGLE if shield == null else null
	_weapon.visible = weapon != null and angle != null
	if _weapon.visible:
		var order: Array = weapons.order
		var idx := order.find(weapon.get("icon", ""))
		if idx < 0:
			idx = order.find("sword")
		_weapon.region_rect = Rect2(idx * weapons.cell[0], 0, weapons.cell[0], weapons.cell[1])
		_weapon.position = hand
		_weapon.rotation_degrees = angle
		var tint: Dictionary = weapon.get("tint", {}).duplicate()
		tint.merge(weapon_tint, true)
		_apply(_weapon.material, tint, false)
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	if _back_shield != null:
		_shield(self, _back_shield, _back_at, 1.6)


func _draw_front_shield() -> void:
	if _front_shield != null:
		_shield(_front, _front_shield, _front_at, 2.0)


## Круглый щит: обод, поле, умбон (как gfx.shield в Pyxel, радиус x2).
static func _shield(canvas: CanvasItem, item: Dictionary, at: Vector2, size: float) -> void:
	var colors: Array = item.get("shield_colors", [2, 4, 6])
	var r := 3.0 * size * 2
	canvas.draw_circle(at, r, Pal.BY_INDEX[int(colors[1])])
	canvas.draw_circle(at, r, Pal.BY_INDEX[int(colors[0])], false, 2.0)
	canvas.draw_circle(at, maxf(1.0, (size - 1) * 2), Pal.BY_INDEX[int(colors[2])])


static func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	return m


## Перекраска {"6": "a"} (номера палитры в hex) -> параметры шейдера.
static func _apply(m: ShaderMaterial, tint: Dictionary, flash: bool) -> void:
	var src := PackedColorArray()
	var dst := PackedColorArray()
	for k in tint:
		src.append(Pal.BY_INDEX[("0x" + str(k)).hex_to_int()])
		dst.append(Pal.BY_INDEX[("0x" + str(tint[k])).hex_to_int()])
	var n := src.size()
	src.resize(16)
	dst.resize(16)
	m.set_shader_parameter("src", src)
	m.set_shader_parameter("dst", dst)
	m.set_shader_parameter("count", n)
	m.set_shader_parameter("flash", flash)
