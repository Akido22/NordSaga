class_name ControlsMenu
extends Overlay
## Список управления. Закрывается любой из кнопок «Назад» и «Выбор».

const LINES := [
	["Идти", "← →  /  A D"],
	["Прыжок", "ПРОБЕЛ / Z / K"],
	["Удар (держи — сильный)", "X / J"],
	["Удар сверху в прыжке", "↓ + удар"],
	["Щит, парирование", "C / L"],
	["Перекат", "V / SHIFT"],
	["Чары руны", "F / U"],
	["Сменить руну", "E / O"],
	["Спрыгнуть с доски", "↓ + прыжок"],
	["Говорить, торговать, открыть", "↑ / W"],
	["Подлечиться", "Q / H"],
	["Сума и снаряжение", "I / TAB"],
	["Пауза", "ESC / P"],
	["Музыка вкл/выкл", "M"],
]


func update() -> void:
	if Controls.pressed("back") or Controls.pressed("confirm"):
		Audio.sfx("select")
		close()


func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	dim(c, 0.7)
	UiKit.panel(c, Rect2(40, 22, view.x - 80, view.y - 30), Pal.NIGHT)
	title_plate(c, view.x / 2, 13, "УПРАВЛЕНИЕ")
	for i in LINES.size():
		var y := 42 + i * 14
		UiKit.text(c, 60, y, LINES[i][0], Pal.LINEN)
		UiKit.text(c, 270, y, LINES[i][1], Pal.GOLD)
	UiKit.text_center(c, view.x / 2, view.y - 24, "Геймпад тоже работает", Pal.STONE)
