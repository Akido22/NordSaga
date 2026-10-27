class_name PauseMenu
extends Overlay
## Привал (пауза): продолжить, сума, сохранить, управление, выйти в главное меню.

var menu := MenuList.new([["Продолжить", true], ["Сума и снаряжение", true], ["Сохранить игру", true],
		["Управление", true], ["В главное меню", true]])
var confirm := MenuList.new([["Да, выйти", true], ["Нет", true]], 1)
var confirm_exit := false


func update() -> void:
	if confirm_exit:
		if Controls.pressed("back"):
			confirm_exit = false
			return
		match confirm.update():
			0: game.show_title()
			1: confirm_exit = false
		return
	if Controls.pressed("back") or Controls.pressed("pause"):
		Audio.sfx("select")
		close()
		return
	match menu.update():
		0: close()
		1: game.push_overlay(InventoryMenu.new())
		2:
			world.save_game()
			close()
		3: game.push_overlay(ControlsMenu.new())
		4:
			confirm_exit = true
			confirm.index = 1


func draw_ui(c: CanvasItem) -> void:
	var cx := c.get_viewport_rect().size.x / 2
	dim(c, 0.6)
	UiKit.panel(c, Rect2(cx - 100, 66, 200, 128), Pal.NIGHT)
	title_plate(c, cx, 57, "ПРИВАЛ")
	if confirm_exit:
		UiKit.text_center(c, cx, 88, "Выйти в главное меню?", Pal.LINEN, Pal.NIGHT)
		UiKit.text_center(c, cx, 106, "Несохранённый путь", Pal.STEEL)
		UiKit.text_center(c, cx, 118, "будет потерян.", Pal.STEEL)
		confirm.draw(c, cx, 146, 16, t)
	else:
		menu.draw(c, cx, 86, 20, t)
