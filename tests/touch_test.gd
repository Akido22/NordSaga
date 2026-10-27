extends Node
## Проверка экранного управления: касания стика и кнопок нажимают действия;
## прыжок в главном меню — «выбор» (новая игра), стик вправо ведёт героя,
## кнопка паузы открывает привал, кувырок закрывает его, мультитач не путает пальцы.
## godot --headless --path . res://tests/touch_test.tscn

var failures: Array[String] = []
var game: Game
var touch: TouchControls


func _ready() -> void:
	SaveSystem.path = "user://touch_test_save.json"
	SaveSystem.delete()
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	touch = game.touch
	touch.enabled = true
	touch.visible = true
	await _frames(5)

	# Кнопка прыжка = «выбор»: в главном меню начинается новая игра.
	await _tap(_button("ПРЫЖОК"))
	_expect(game.world != null and game.overlay == null, "прыжок не выбрал «Новая игра»")
	await _frames(20)

	# Стик вправо — герой идёт; отпустили — действие отпущено.
	var p := game.world.player
	var x0 := p.x
	_touch(1, Vector2(60, 210), true)
	_drag(1, Vector2(95, 212))
	_expect(Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up"), "стик вправо не держит «вправо»")
	# Второй палец одновременно — удар; стик при этом не отпускается.
	_touch(2, _button("УДАР"), true)
	_expect(Input.is_action_pressed("attack") and Input.is_action_pressed("move_right"), "мультитач: удар сбил стик")
	await _frames(2)
	_touch(2, _button("УДАР"), false)
	await _frames(30)
	_expect(p.x > x0 + 20, "герой не пошёл вправо: %.1f -> %.1f" % [x0, p.x])
	_drag(1, Vector2(60, 170))
	_expect(Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_right"), "стик вверх не держит «вверх»")
	_touch(1, Vector2(60, 170), false)
	_expect(not Input.is_action_pressed("move_up") and touch.stick_base == touch.stick_home, "стик не отпустился")
	# Слабый наклон вниз не считается «вниз» (чтобы не спрыгивать с досок случайно).
	_touch(3, Vector2(60, 210), true)
	_drag(3, Vector2(60, 225))
	_expect(not Input.is_action_pressed("move_down"), "слабый наклон дал «вниз»")
	_touch(3, Vector2(60, 225), false)

	# Пауза и выход из неё кувырком (= «назад»).
	await _tap(_button("II"))
	_expect(game.overlay is PauseMenu, "кнопка паузы не открыла привал")
	await _tap(_button("КУВ."))
	_expect(game.overlay == null, "кувырок (назад) не закрыл привал")

	# Касание мимо кнопок справа ничего не нажимает.
	_touch(4, Vector2(300, 60), true)
	_expect(touch.fingers.is_empty() and touch.stick_finger < 0, "касание в пустоте что-то нажало")
	_touch(4, Vector2(300, 60), false)

	# Настоящий путь события: касание в пикселях окна (масштаб x3) доходит до кнопки.
	var e := InputEventScreenTouch.new()
	e.index = 5
	e.pressed = true
	e.position = get_tree().root.get_final_transform() * _button("БЛОК")
	Input.parse_input_event(e)
	await _frames(2)
	_expect(Input.is_action_pressed("block"), "касание окна %s не попало в «БЛОК»" % e.position)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)
	_expect(not Input.is_action_pressed("block"), "«БЛОК» не отпустился")

	touch.release_all()
	SaveSystem.delete()
	if failures.is_empty():
		print("TOUCH OK")
	else:
		for f in failures:
			printerr("FAIL: ", f)
	get_tree().quit(1 if failures else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _button(label: String) -> Vector2:
	for b in TouchControls.BUTTONS:
		if b.label == label:
			return b.at
	failures.append("нет кнопки " + label)
	return Vector2.ZERO


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	touch.handle(e)


func _drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	touch.handle(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Коснуться и отпустить через кадр, подождать, пока окна отработают.
func _tap(at: Vector2) -> void:
	_touch(9, at, true)
	await _frames(2)
	_touch(9, at, false)
	await _frames(4)
