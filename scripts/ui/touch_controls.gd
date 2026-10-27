class_name TouchControls
extends CanvasLayer
## Экранное управление для телефона: плавающий стик слева, кнопки справа.
## Касания нажимают те же действия, что клавиатура и геймпад (Input.action_press),
## поэтому игра и окна не отличают палец от клавиши. Кнопки двойные, как на геймпаде:
## прыжок — ещё и «выбор» в окнах, кувырок — «назад», чары — «выбросить».
## Показывается на сенсорных устройствах; на ПК — с ключом запуска --touch
## (мышь тогда изображает палец).

const STICK_ZONE := 200.0  # левее этой границы касание хватает стик
const STICK_R := 30.0
const DEAD := 0.35  # мёртвая зона по горизонтали
const VERT := 0.6  # вверх/вниз — только при явном наклоне (говорить, спрыгнуть с доски)
const BUTTONS := [
	{"at": Vector2(438, 222), "r": 22, "label": "ПРЫЖОК", "actions": ["jump", "confirm"]},
	{"at": Vector2(390, 236), "r": 18, "label": "УДАР", "actions": ["attack"]},
	{"at": Vector2(446, 172), "r": 16, "label": "КУВ.", "actions": ["roll", "back"]},
	{"at": Vector2(342, 242), "r": 16, "label": "БЛОК", "actions": ["block"]},
	{"at": Vector2(396, 186), "r": 15, "label": "ЧАРЫ", "actions": ["cast", "drop"]},
	{"at": Vector2(352, 196), "r": 13, "label": "РУНА", "actions": ["next_rune"]},
	{"at": Vector2(452, 126), "r": 13, "label": "ЛЕЧ.", "actions": ["heal"]},
	{"at": Vector2(462, 18), "r": 12, "label": "II", "actions": ["pause"]},
	{"at": Vector2(432, 18), "r": 12, "label": "СУМА", "actions": ["inventory"]},
]

var enabled := false
var stick_home := Vector2(64, 210)
var stick_base := stick_home
var stick_knob := stick_home
var stick_finger := -1
var fingers := {}  # индекс пальца -> номер кнопки
var _holders := {}  # действие -> сколько касаний его держат
var _stick_actions: Array[String] = []
var _canvas: Node2D


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
			or "--touch" in OS.get_cmdline_user_args()
	visible = enabled
	if "--touch" in OS.get_cmdline_user_args():
		Input.emulate_touch_from_mouse = true
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)


func _input(event: InputEvent) -> void:
	if enabled and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		handle(event)
		get_viewport().set_input_as_handled()


## Касание в координатах экрана игры (480x270).
func handle(event: InputEvent) -> void:
	var at: Vector2 = event.position
	if event is InputEventScreenTouch and event.pressed:
		var b := button_at(at)
		if b >= 0:
			fingers[event.index] = b
			for a in BUTTONS[b].actions:
				_press(a)
		elif at.x < STICK_ZONE and stick_finger < 0:
			stick_finger = event.index
			stick_base = at
			_move_stick(at)
	elif event is InputEventScreenTouch:
		if fingers.has(event.index):
			for a in BUTTONS[fingers[event.index]].actions:
				_release(a)
			fingers.erase(event.index)
		elif event.index == stick_finger:
			stick_finger = -1
			stick_base = stick_home
			_move_stick(stick_home)
	elif event is InputEventScreenDrag and event.index == stick_finger:
		_move_stick(at)
	_canvas.queue_redraw()


## Номер кнопки под точкой или -1 (кнопка ловит палец чуть шире своего круга).
func button_at(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in BUTTONS.size():
		var d := at.distance_to(BUTTONS[i].at)
		if d < BUTTONS[i].r * 1.3 and d < best_d:
			best = i
			best_d = d
	return best


func _move_stick(at: Vector2) -> void:
	var off := (at - stick_base).limit_length(STICK_R)
	stick_knob = stick_base + off
	var d := off / STICK_R
	var want: Array[String] = []
	if d.x < -DEAD: want.append("move_left")
	elif d.x > DEAD: want.append("move_right")
	if d.y < -VERT: want.append("move_up")
	elif d.y > VERT: want.append("move_down")
	for a in _stick_actions:
		if not a in want:
			_release(a)
	for a in want:
		if not a in _stick_actions:
			_press(a)
	_stick_actions = want


func _press(action: String) -> void:
	_holders[action] = _holders.get(action, 0) + 1
	if _holders[action] == 1:
		Input.action_press(action)


func _release(action: String) -> void:
	_holders[action] = maxi(0, _holders.get(action, 0) - 1)
	if _holders[action] == 0:
		Input.action_release(action)


## Отпустить всё (приложение свернули — пальцы «потерялись»).
func release_all() -> void:
	for a in _holders:
		if _holders[a] > 0:
			Input.action_release(a)
	_holders.clear()
	fingers.clear()
	_stick_actions.clear()
	stick_finger = -1
	stick_base = stick_home
	stick_knob = stick_home
	_canvas.queue_redraw()


func _draw_controls() -> void:
	var c := _canvas
	c.draw_circle(stick_base, STICK_R + 4, Color(Pal.BLACK, 0.3))
	c.draw_arc(stick_base, STICK_R + 4, 0, TAU, 32, Color(Pal.STEEL, 0.5), 1.0)
	c.draw_circle(stick_knob, 13, Color(Pal.STEEL, 0.55 if stick_finger >= 0 else 0.35))
	var held := fingers.values()
	for i in BUTTONS.size():
		var b: Dictionary = BUTTONS[i]
		var down := i in held
		c.draw_circle(b.at, b.r, Color(Pal.GOLD if down else Pal.BLACK, 0.55 if down else 0.35))
		c.draw_arc(b.at, b.r, 0, TAU, 24, Color(Pal.GOLD, 0.7 if down else 0.4), 1.0)
		UiKit.text_center(c, b.at.x, b.at.y - 4, b.label, Color(Pal.LINEN, 0.85), Color(Pal.BLACK, 0.6))
