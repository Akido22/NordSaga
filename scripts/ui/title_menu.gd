class_name TitleMenu
extends Overlay
## Главное меню поверх медленно плывущего Велеграда (фон — game.gd).

const GAME_TITLE := "Северная Сага"

var menu: MenuList


func _init() -> void:
	menu = MenuList.new([["Продолжить", SaveSystem.exists()], ["Новая игра", true], ["Управление", true],
			["Выход", true]])


func update() -> void:
	match menu.update():
		0: game.load_game()
		1: game.new_game()
		2: game.push_overlay(ControlsMenu.new())
		3: get_tree().quit()


func draw_ui(c: CanvasItem) -> void:
	var view := c.get_viewport_rect().size
	var cx := view.x / 2
	dim(c, 0.25)
	UiKit.ornament_band(c, 52, 46, view.x - 104)
	UiKit.text_center(c, cx, 58, GAME_TITLE.to_upper(), Pal.GOLD, Pal.RED, 27)
	UiKit.text_center(c, cx, 92, "Глава I. Велеград", Pal.LINEN, Pal.NIGHT)
	UiKit.ornament_band(c, 52, 110, view.x - 104)
	UiKit.panel(c, Rect2(cx - 70, 124, 140, 92), Pal.NIGHT)
	menu.draw(c, cx, 136, 18, t)
	UiKit.text_center(c, cx, view.y - 18, "M — музыка   F11 — во весь экран", Pal.STEEL, Pal.NIGHT)
