class_name MenuList
extends RefCounted
## Вертикальное меню: options — [[текст, доступно], ...], как ui.Menu в Pyxel-версии.

var options: Array
var index := 0


func _init(opts: Array, start := 0) -> void:
	options = opts
	index = start
	if not options[index][1]:
		move(1, true)


func move(step: int, silent := false) -> void:
	for i in options.size():
		index = posmod(index + step, options.size())
		if options[index][1]:
			break
	if not silent:
		Audio.sfx("move")


## Индекс выбранного пункта или -1.
func update() -> int:
	if Controls.pressed_repeat("move_up"):
		move(-1)
	elif Controls.pressed_repeat("move_down"):
		move(1)
	elif Controls.pressed("confirm"):
		Audio.sfx("select")
		return index
	return -1


func label() -> String:
	return options[index][0]


func draw(c: CanvasItem, cx: float, y: float, spacing := 16, t := 0) -> void:
	for i in options.size():
		var yy := y + i * spacing
		var selected := i == index
		var col: Color = Pal.GOLD if selected else (Pal.LINEN if options[i][1] else Pal.STONE)
		UiKit.text_center(c, cx, yy, options[i][0], col, Pal.NIGHT)
		if selected:
			var half := UiKit.width(options[i][0]) / 2
			var bob := (t / 10) % 2
			UiKit.rhombus(c, cx - half - 10 - bob, yy + 4, 2, Pal.RED)
			UiKit.rhombus(c, cx + half + 9 + bob, yy + 4, 2, Pal.RED)
