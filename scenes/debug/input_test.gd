extends Node2D
## Проверка каркаса: экран 480x270, чёткие пиксели, все действия ввода.
## Нажатые действия подсвечиваются золотом.

const FONT_SIZE := 9

var _font: Font


func _ready() -> void:
	_font = preload("res://assets/fonts/nord_font.fnt")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Pal.NIGHT)
	draw_rect(Rect2(Vector2(0.5, 0.5), view - Vector2.ONE), Pal.GOLD, false, 1.0)
	_text(Vector2(8, 14), "Северная Сага — каркас (шаг 1)", Pal.GOLD)
	_text(Vector2(8, 26), "Экран %dx%d. Нажимайте клавиши или кнопки геймпада." % [view.x, view.y], Pal.LINEN)

	var actions := Controls.BINDINGS.keys()
	for i in actions.size():
		var action: String = actions[i]
		var at := Vector2(8 + (i / 9) * 120, 44 + (i % 9) * 13)
		var on := Input.is_action_pressed(action)
		draw_rect(Rect2(at + Vector2(0, -8), Vector2(112, 11)), Pal.FJORD if on else Pal.BLACK)
		_text(at + Vector2(3, 0), Controls.NAMES[action], Pal.GOLD if on else Pal.STEEL)

	# Тайлы 16 px и палитра: проверка чёткости пикселей.
	for i in Pal.BY_INDEX.size():
		draw_rect(Rect2(Vector2(256 + (i % 8) * 16, 44 + (i / 8) * 16), Vector2(16, 16)), Pal.BY_INDEX[i])
	for x in range(256, 384, 2):
		draw_rect(Rect2(Vector2(x, 84), Vector2(1, 16)), Pal.SNOW)

	var pads := Input.get_connected_joypads()
	var pad := "геймпад: %s" % Input.get_joy_name(pads[0]) if pads else "геймпад не подключён"
	_text(Vector2(256, 116), pad, Pal.LINEN)
	_text(Vector2(256, 128), "ось X: %+.2f" % Controls.axis_x(), Pal.LINEN)
	_text(Vector2(256, 140), "музыка: %s (M)" % ("вкл" if Audio.music_on else "выкл"), Pal.LINEN)
	_text(Vector2(8, view.y - 8), "Данные: %d табл.  Сохранение: %s" % [
		Data.tables.size(), "есть" if SaveSystem.exists() else "нет"], Pal.STONE)


func _text(at: Vector2, s: String, color: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
