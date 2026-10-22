extends Node
## Действия ввода: клавиатура и геймпад. Раскладка та же, что в Pyxel-версии.
## Клавиши заданы физически (physical_keycode), поэтому WASD работает
## и на русской раскладке.
## Действия регистрируются кодом, а не в Input Map редактора: так их проще
## переназначать в настройках игры и сохранять.

const STICK_DEADZONE := 0.35

## действие -> {keys: клавиши, pad: кнопки геймпада, axis: [ось, направление]}
const BINDINGS := {
	"move_left": {"keys": [KEY_LEFT, KEY_A], "pad": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right": {"keys": [KEY_RIGHT, KEY_D], "pad": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"move_up": {"keys": [KEY_UP, KEY_W], "pad": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_down": {"keys": [KEY_DOWN, KEY_S], "pad": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"jump": {"keys": [KEY_SPACE, KEY_Z, KEY_K], "pad": [JOY_BUTTON_A]},
	"attack": {"keys": [KEY_X, KEY_J], "pad": [JOY_BUTTON_X]},
	"block": {"keys": [KEY_C, KEY_L], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	"roll": {"keys": [KEY_V, KEY_SHIFT, KEY_SEMICOLON], "pad": [JOY_BUTTON_B]},
	"heal": {"keys": [KEY_Q, KEY_H], "pad": [JOY_BUTTON_LEFT_SHOULDER]},
	"cast": {"keys": [KEY_F, KEY_U], "pad": [JOY_BUTTON_Y]},
	"next_rune": {"keys": [KEY_E, KEY_O], "pad": [JOY_BUTTON_LEFT_STICK]},
	"inventory": {"keys": [KEY_I, KEY_TAB], "pad": [JOY_BUTTON_BACK]},
	"pause": {"keys": [KEY_ESCAPE, KEY_P], "pad": [JOY_BUTTON_START]},
	# меню
	"confirm": {"keys": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z], "pad": [JOY_BUTTON_A]},
	"back": {"keys": [KEY_ESCAPE, KEY_BACKSPACE, KEY_X], "pad": [JOY_BUTTON_B]},
	"drop": {"keys": [KEY_R, KEY_DELETE], "pad": [JOY_BUTTON_Y]},
	"toggle_music": {"keys": [KEY_M]},
}

## Подписи для экранов управления и отладки.
const NAMES := {
	"move_left": "Влево", "move_right": "Вправо", "move_up": "Вверх", "move_down": "Вниз",
	"jump": "Прыжок", "attack": "Удар", "block": "Блок", "roll": "Кувырок",
	"heal": "Лечение", "cast": "Чары", "next_rune": "Смена руны",
	"inventory": "Сума", "pause": "Пауза", "confirm": "Выбор", "back": "Назад",
	"drop": "Выбросить", "toggle_music": "Музыка",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in BINDINGS:
		_register(action, BINDINGS[action])


func _register(action: String, bind: Dictionary) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, STICK_DEADZONE)
	for code in bind.get("keys", []):
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)
	for index in bind.get("pad", []):
		var button := InputEventJoypadButton.new()
		button.button_index = index
		InputMap.action_add_event(action, button)
	if bind.has("axis"):
		var motion := InputEventJoypadMotion.new()
		motion.axis = bind["axis"][0]
		motion.axis_value = bind["axis"][1]
		InputMap.action_add_event(action, motion)


## Горизонталь -1..1 (стрелки, WASD, крестовина, стик).
func axis_x() -> float:
	return Input.get_axis("move_left", "move_right")
