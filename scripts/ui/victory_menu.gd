class_name VictoryMenu
extends Overlay
## «Путь пройден» — выход из кургана: вернуться в Велеград или в главное меню.

var menu := MenuList.new([["Вернуться в Велеград", true], ["В главное меню", true]])


func update() -> void:
	if t < 40:
		return
	match menu.update():
		0: game.enter_level("town", "start")
		1: game.show_title()


func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	var cx := view.x / 2
	dim(c, minf(0.6, t / 50.0))
	UiKit.backdrop(c, 52, 170)
	UiKit.ornament_band(c, 70, 72, view.x - 140)
	UiKit.text_center(c, cx, 84, "ПУТЬ ПРОЙДЕН", Pal.GOLD, Pal.RED, 18)
	UiKit.ornament_band(c, 70, 116, view.x - 140)
	UiKit.text_center(c, cx, 132, "Собрано серебра: %d" % inv.silver, Pal.LINEN)
	var done := GameState.flags.has("boss:jarl")
	UiKit.text_center(c, cx, 148, "Ярл повержен. Глава I пройдена." if done else "Пробный путь завершён.", Pal.STEEL)
	if t >= 40:
		menu.draw(c, cx, 176, 18, t)
