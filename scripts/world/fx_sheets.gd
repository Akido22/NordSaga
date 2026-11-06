class_name FxSheets
## Покадровые эффекты из листов assets/fx (выгружает tools/export_fx.mjs из pixelfx).
## Листы есть в двух масштабах: x2 — пиксели эффекта вдвое крупнее, x1 — как у героя.

const DIR := "res://assets/fx/"
const PHYSICS_FPS := 60.0

static var scale := 2
static var _info := {}
static var _tex := {}


static func has(name: String) -> bool:
	return _load().has(name)


static func _load() -> Dictionary:
	if _info.is_empty() and FileAccess.file_exists(DIR + "fx.json"):
		_info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "fx.json"))
	return _info


## Число кадров физики, которое длится эффект (для разовых).
static func length(name: String, speed := 0.0) -> int:
	var e: Dictionary = _load()[name]
	var s: float = speed if speed > 0 else float(e.speed)
	return ceili(e["x%d" % scale].frames * PHYSICS_FPS / (e.fps * s))


## Рисует кадр эффекта, который идёт age кадров физики; точка привязки — в at.
## Возвращает false, если разовый эффект уже кончился.
static func draw(c: CanvasItem, name: String, at: Vector2, age: int, flip := false, speed := 0.0) -> bool:
	var e: Dictionary = _load()[name]
	var s: Dictionary = e["x%d" % scale]
	var n := int(s.frames)
	var f := int(age * float(e.fps) * (speed if speed > 0 else float(e.speed)) / PHYSICS_FPS)
	if e.loop:
		f %= n
	elif f >= n:
		return false
	var key := "%s@%d" % [name, scale]
	if not _tex.has(key):
		_tex[key] = load(DIR + "x%d/%s.png" % [scale, name])
	var w := float(s.w)
	var h := float(s.h)
	var src := Rect2((f % int(s.cols)) * w, (f / int(s.cols)) * h, w, h)
	c.draw_set_transform(at.floor(), 0, Vector2(-1 if flip else 1, 1))
	c.draw_texture_rect_region(_tex[key], Rect2(-float(s.pivot[0]), -float(s.pivot[1]), w, h), src)
	c.draw_set_transform(Vector2.ZERO)
	return true
