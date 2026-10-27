extends Node
## Проверка шага 8 настоящими кадрами и нажатиями: главное меню -> новая игра -> сума
## (надеть меч) -> пауза (сохранить) -> гибель (серебро на месте гибели) -> к месту
## сохранения -> подобрать серебро -> конец пути -> Велеград -> пауза -> главное меню.
## godot --headless --path . res://tests/ui_test.tscn

var failures: Array[String] = []
var game: Node


func _ready() -> void:
	SaveSystem.path = "user://ui_test_save.json"
	SaveSystem.delete()
	Controls.scripted = {"held": {}, "pressed": {}}
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _idle(5)

	# Главное меню: сохранения нет — «Продолжить» недоступно, выбор стоит на «Новая игра».
	var title := game.overlay as TitleMenu
	_expect(title != null and game.world == null, "нет главного меню")
	if title == null:
		return _finish()
	_expect(not title.menu.options[0][1] and title.menu.index == 1, "«Продолжить» доступно без сохранения")
	await _press("confirm")
	_expect(game.world != null and game.world.level_name == "town" and game.overlay == null, "новая игра не началась")
	await _idle(20)  # проявление

	# Сума: надеть меч из сумы.
	GameState.inv.add("sword")
	await _press("inventory")
	var inv_menu := game.overlay as InventoryMenu
	_expect(inv_menu != null, "сума не открылась")
	_expect(not game.world.is_physics_processing(), "мир идёт под окном сумы")
	var idx := GameState.inv.bag.find(GameState.inv.bag.filter(func(c): return c and c[0] == "sword")[0])
	for i in idx % Inventory.BAG_COLS:
		await _press("move_right")
	for i in idx / Inventory.BAG_COLS:
		await _press("move_down")
	_expect(inv_menu.selected() == ["bag", idx], "выбор в суме: %s, ждём ячейку %d" % [inv_menu.selected(), idx])
	await _press("confirm")
	_expect(GameState.equipped("weapon") == "sword", "меч не надет")
	await _press("inventory")
	_expect(game.overlay == null and game.world.is_physics_processing(), "сума не закрылась")

	# Пауза -> «Сохранить игру».
	await _press("pause")
	_expect(game.overlay is PauseMenu, "пауза не открылась")
	await _press("move_down")
	await _press("move_down")
	await _press("confirm")
	var saved = SaveSystem.load_data()
	_expect(saved != null and saved.inventory.equipment.weapon == "sword", "пауза не сохранила игру")
	_expect(game.overlay == null, "пауза не закрылась после сохранения")

	# Гибель: серебро остаётся лежать, в сохранении его больше нет.
	var w: World = game.world
	GameState.inv.silver = 37
	w.player.place(Vector2(w.player.x + 200, w.player.y + w.player.h))  # подальше от места сохранения
	var at := Vector2(w.player.safe_x, w.player.safe_y)
	GameState.hp = 1
	w.player.hurt_by_hazard(w)
	_expect(w.player.dead, "герой не погиб")
	await _idle(Game.DEATH_DELAY + 5)
	_expect(game.overlay is DeathMenu, "нет экрана смерти")
	saved = SaveSystem.load_data()
	_expect(int(saved.inventory.silver) == 0, "серебро не пропало из сохранения")
	_expect(saved.lost_silver is Dictionary and int(saved.lost_silver.amount) == 37
			and Vector2(saved.lost_silver.x, saved.lost_silver.y) == at, "место гибели не записано: %s" % str(saved.lost_silver))
	await _idle(30)
	await _press("confirm")  # «К месту сохранения»
	w = game.world
	_expect(w != null and GameState.inv.silver == 0 and w.lost_pile != null, "после загрузки нет кучки серебра")
	_expect(GameState.equipped("weapon") == "sword", "после загрузки меч не надет")
	await _idle(20)
	if w.lost_pile:
		w.player.x = w.lost_pile.x
		w.player.y = w.lost_pile.y + LostSilver.H - w.player.h
		await _idle(2)
	_expect(GameState.inv.silver == 37 and w.lost_pile == null and GameState.lost_silver == null, "серебро не вернулось")

	# Конец пути -> экран победы -> Велеград.
	w.leave("end", "")
	await _idle(5)
	_expect(game.overlay is VictoryMenu, "нет экрана победы")
	await _idle(40)
	await _press("confirm")
	await _idle(5)
	_expect(game.world != w and game.world.level_name == "town" and game.overlay == null, "не вернулись в Велеград")

	# Переход между локациями — через затемнение.
	w = game.world
	await _idle(20)
	w.leave("test_level", "")
	await _idle(1)
	_expect(game.fade_out > 0 and game.world == w and not w.is_physics_processing(), "переход без затемнения")
	await _idle(Game.FADE + 2)
	_expect(game.world != w and game.world.level_name == "test_level" and game.fade_in > 0, "переход не состоялся")

	# Пауза -> «В главное меню» -> «Да, выйти».
	await _idle(20)
	await _press("pause")
	for i in 4:
		await _press("move_down")
	await _press("confirm")
	await _press("move_up")
	await _press("confirm")
	_expect(game.world == null and game.overlay is TitleMenu, "не вышли в главное меню")
	_expect((game.overlay as TitleMenu).menu.options[0][1], "«Продолжить» недоступно при сохранении")
	_finish()


func _finish() -> void:
	Controls.scripted = null
	SaveSystem.delete()
	if failures.is_empty():
		print("UI OK")
	else:
		for f in failures:
			printerr("FAIL: ", f)
	get_tree().quit(1 if failures else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


## n кадров без нажатий.
func _idle(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		Controls.scripted = {"held": {}, "pressed": {}}


## Нажать действие на один кадр и подождать, пока окна отработают.
func _press(action: String) -> void:
	await get_tree().physics_frame
	Controls.scripted = {"held": {action: true}, "pressed": {action: true}}
	await _idle(3)
