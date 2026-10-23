extends Node
## Проверка каркаса без участия человека.
## Запуск: godot --headless --path . res://tests/smoke_test.tscn
## Снимок экрана (без --headless): ... res://tests/smoke_test.tscn -- --shot=C:/путь/shot.png
##   [--scene=res://scenes/debug/asset_gallery.tscn]  (по умолчанию — проверка ввода)
##   [--hold=move_left,jump] [--frames=40]  — держать действия столько кадров перед снимком

var failures: Array[String] = []


func _ready() -> void:
	_check_settings()
	_check_actions()
	await _check_key_mapping()
	_check_save()
	_check_assets()
	var shot := _arg("shot")
	if shot:
		await _screenshot(shot)
	if failures.is_empty():
		print("SMOKE OK")
	else:
		for f in failures:
			printerr("FAIL: ", f)
	get_tree().quit(1 if failures else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _check_settings() -> void:
	_expect(get_viewport().get_visible_rect().size == Vector2(480, 270), "экран не 480x270")
	_expect(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0,
			"фильтр текстур не Nearest")
	_expect(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer",
			"масштаб не целочисленный")


func _check_actions() -> void:
	for action in Controls.BINDINGS:
		_expect(InputMap.has_action(action), "нет действия " + action)
		_expect(Controls.NAMES.has(action), "нет подписи для " + action)
	_expect(InputMap.action_get_events("move_left").size() == 4, "move_left: ждём 2 клавиши, кнопку и стик")


func _check_key_mapping() -> void:
	# Физическая клавиша X — удар; A — влево; стик влево — тоже влево.
	await _press_key(KEY_X)
	_expect(Input.is_action_pressed("attack"), "X не даёт удар")
	await _release_key(KEY_X)
	_expect(not Input.is_action_pressed("attack"), "удар не отпускается")
	await _press_key(KEY_A)
	_expect(Controls.axis_x() < -0.9, "A не даёт движение влево")
	await _release_key(KEY_A)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.8
	Input.parse_input_event(stick)
	await get_tree().process_frame
	_expect(Input.is_action_pressed("move_right"), "стик не даёт движение вправо")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await get_tree().process_frame


func _press_key(code: Key) -> void:
	await _key(code, true)


func _release_key(code: Key) -> void:
	await _key(code, false)


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	await get_tree().process_frame


func _check_save() -> void:
	var real_path := SaveSystem.path
	SaveSystem.path = "user://smoke_test_save.json"
	GameState.reset()
	GameState.hp = 7
	GameState.flags["boss:jarl"] = true
	GameState.collected[GameState.key("town", "c1")] = true
	_expect(SaveSystem.write(GameState.to_save("barrow", Vector2(40, 96))), "сохранение не записалось")
	GameState.reset()
	var data = SaveSystem.load_data()
	_expect(data != null, "сохранение не читается")
	if data != null:
		GameState.from_save(data)
		_expect(GameState.hp == 7, "hp не восстановилось")
		_expect(GameState.level == "barrow", "локация не восстановилась")
		_expect(GameState.pos == Vector2(40, 96), "позиция не восстановилась")
		_expect(GameState.flags.has("boss:jarl"), "флаг не восстановился")
		_expect(GameState.collected.has("town:c1"), "находка не восстановилась")
	SaveSystem.delete()
	_expect(not SaveSystem.exists(), "сохранение не удалилось")
	SaveSystem.path = real_path
	GameState.reset()


func _check_assets() -> void:
	_expect(Data.tables.size() == 8, "таблиц данных %d, ждём 8" % Data.tables.size())
	_expect(Data.table("items").has("knife"), "в items нет ножа")
	_expect(load("res://assets/fonts/nord_font.fnt") is FontFile, "шрифт не загрузился")
	for id in ["jump", "swing", "hit", "parry", "roar", "fire"]:
		_expect(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % id), "нет звука " + id)
	for id in ["forest", "town", "boss"]:
		var m: AudioStreamWAV = load("res://assets/audio/music/%s.wav" % id)
		_expect(m != null and m.loop_mode == AudioStreamWAV.LOOP_FORWARD, "музыка не зациклена: " + id)
	for dir in ["res://assets/sprites/objects", "res://assets/sprites/props"]:
		for name in Strips.names(dir):
			var m := Strips.meta(dir, name)
			var tex: Texture2D = load("%s/%s.png" % [dir, name])
			_expect(tex.get_width() == m.frame_w * m.frames and tex.get_height() == m.frame_h,
					"размер ленты не совпадает: " + name)
	var bgs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/backgrounds/backgrounds.json"))
	for st in ["forest", "town", "barrow"]:
		_expect(bgs.has(st), "нет фона " + st)
		for l in bgs.get(st, []):
			_expect(ResourceLoader.exists("res://assets/backgrounds/%s/%s.png" % [st, l.layer]), "нет слоя %s/%s" % [st, l.layer])


func _screenshot(path: String) -> void:
	var scene := _arg("scene")
	var packed: PackedScene = load(scene if scene else "res://scenes/debug/input_test.tscn")
	_expect(packed != null, "сцена не загрузилась: " + scene)
	if packed == null:
		return
	add_child(packed.instantiate())
	var hold := {}
	for a in _arg("hold").split(",", false):
		hold[a] = true
	var frames := int(_arg("frames")) if _arg("frames") else 30
	for i in frames:
		# physics_frame приходит до обработки кадра — ввод задаётся для этого же кадра
		await get_tree().physics_frame
		Controls.scripted = {"held": hold, "pressed": hold if i == 0 else {}}
	await get_tree().physics_frame
	Controls.scripted = null
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	_expect(err == OK, "снимок не сохранился: " + path)


func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return ""
