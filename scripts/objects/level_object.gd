@tool
class_name LevelObject
extends Node2D
## Объект уровня. Узел стоит на низ-левом углу своего тайла (как символ на карте
## Pyxel-версии); хитбокс (bx, by, bw, bh) — в координатах уровня, размеры x2.
## @tool — картинка видна и в редакторе, логика работает только в игре.

const T := 16
const OBJECTS := "res://assets/sprites/objects"
const PROPS := "res://assets/sprites/props"

var bx := 0.0
var by := 0.0
var bw := 0.0
var bh := 0.0
var _visual: Node2D


## Тайл объекта, uid — как в сохранениях Pyxel-версии («столбец,строка»).
var tx: int:
	get: return roundi(position.x / T)
var ty: int:
	get: return roundi(position.y / T) - 1
var uid: String:
	get: return "%d,%d" % [tx, ty]


func _ready() -> void:
	_setup()
	refresh()


## Хитбокс. Переопределяется.
func _setup() -> void:
	pass


## Обновить картинку под состояние. Переопределяется.
func refresh() -> void:
	pass


## Подпись над объектом («открыть», «в путь»…) или "" — нечего делать.
func hint() -> String:
	return ""


func interact(_world) -> void:
	pass


func tick(_world) -> void:
	pass


func center_x() -> float:
	return bx + bw / 2


## Лента кадров из objects/props; точка (0, 0) узла — точка привязки.
func show_strip(dir: String, strip: String) -> void:
	if _visual:
		_visual.queue_free()
	_visual = Strips.sprite(dir, strip)
	add_child(_visual)


## Прямоугольник в мировых координатах пересекается с хитбоксом.
func overlaps(x: float, y: float, w: float, h: float) -> bool:
	return x < bx + bw and bx < x + w and y < by + bh and by < y + h
