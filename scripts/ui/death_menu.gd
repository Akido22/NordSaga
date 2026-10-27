class_name DeathMenu
extends Overlay
## «Ты пал в бою»: к месту сохранения, начать сначала, в главное меню.
## Серебро осталось лежать там, где герой пал (world.on_player_died).

var menu: MenuList


func _init() -> void:
	menu = MenuList.new([["К месту сохранения", SaveSystem.exists()], ["Начать сначала", true],
			["В главное меню", true]])


func update() -> void:
	if t < 30:
		return
	match menu.update():
		0: game.load_game()
		1: game.new_game()
		2: game.show_title()


func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	var cx := view.x / 2
	dim(c, minf(0.7, t / 40.0))
	if t > 15:
		UiKit.backdrop(c, 64, 150, Pal.RED)
		UiKit.ornament_band(c, 70, 84, view.x - 140, Pal.RED, Pal.DARK_WOOD)
		UiKit.text_center(c, cx, 98, "ТЫ ПАЛ В БОЮ", Pal.RED, Pal.DARK_WOOD, 18)
		UiKit.text_center(c, cx, 126, "Но сага ещё не окончена...", Pal.STEEL)
	if t >= 30:
		menu.draw(c, cx, 152, 18, t)
