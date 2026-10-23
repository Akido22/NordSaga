extends Node
## Проверка локаций: карты тайлов совпадают с data/levels/*.txt, объекты работают,
## переходы ведут куда нужно: город -> тропа -> курган -> тропа -> город.
## godot --headless --path . res://tests/levels_test.tscn

const SOLID := "#SL_%"

var failures: Array[String] = []
var game: Node
var world: World


func _ready() -> void:
	SaveSystem.path = "user://levels_test_save.json"
	SaveSystem.delete()
	for lvl in ["town", "test_level", "barrow"]:
		_check_tiles(lvl)

	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	_grab_world()
	_expect(world.level_name == "town", "старт не в городе")
	_expect(world.npcs.size() == 6, "в городе жителей %d, ждём 6" % world.npcs.size())

	# Сундук у избы: руна огня и мёд.
	var chest := _find(world.chests, "29,19") as Chest
	_use(chest)
	_expect(chest.opened, "сундук не открылся")
	_expect("rune_fire" in GameState.inv.spells, "руна огня не выучена")
	_expect(_bag_count("honey") == 1, "мёд не в суме")

	# Стела: сохранение.
	var stela: SavePoint = world.save_points[0]
	_use(stela)
	_expect(stela.active and SaveSystem.exists(), "стела не сохранила игру")
	_expect(GameState.save_point == "town:" + stela.uid, "точка сохранения не запомнилась")

	# Табличка и разговор.
	var sign: Sign = world.signs[0]
	_stand_at(sign)
	_tick(2)
	_expect(world.near == sign, "табличка не читается рядом")
	var elder: Npc = world.npcs.filter(func(n): return n.npc_id == "elder")[0]
	_use(elder)
	_expect(world.talk_npc == elder and elder.line == 0, "старейшина не заговорил")
	for i in elder.lines().size():
		_tick(1, {"move_up": true})
		_tick(1)
	_expect(world.talk_npc == null, "разговор не закончился")

	# Ворота города -> Лесная тропа.
	await _go(world.gates[0], "test_level", Vector2i(3, 19))
	var coin := world.pickups.filter(func(p): return p.kind == "coin")[0] as Pickup
	var coin_key := world.key(coin.uid)
	_tick(21)  # подбирается не раньше, чем через 20 кадров
	world.player.x = coin.x
	world.player.y = coin.y
	world.player.vy = 0
	_tick(1)
	_expect(GameState.inv.silver == 1 and GameState.collected.has(coin_key), "монета не подобрана")

	# Врата тропы -> курган (ярл не побеждён: выход заперт, награда скрыта).
	var to_barrow := world.gates.filter(func(g): return g.target == "barrow")[0] as Gate
	await _go(to_barrow, "barrow", Vector2i(3, 19))
	_expect(world.gates.all(func(g): return g.locked), "врата кургана открыты до победы над ярлом")
	_expect(world.hidden_chest != null and not world.hidden_chest.visible, "сундук ярла виден заранее")
	_use(world.gates[0])
	_expect(world.exit_to == null, "запертые врата выпустили героя")

	# Курган -> тропа (край карты) -> город (край карты).
	await _go(world.edge_exits[0], "test_level", Vector2i(164, 19))
	_expect(not world.pickups.any(func(p): return world.key(p.uid) == coin_key), "подобранная монета вернулась")
	await _go(world.edge_exits[0], "town", Vector2i(101, 19))
	_expect((_find(world.chests, "29,19") as Chest).opened, "сундук в городе снова закрыт")

	SaveSystem.delete()
	if failures.is_empty():
		print("LEVELS OK")
	else:
		for f in failures:
			printerr("FAIL: ", f)
	get_tree().quit(1 if failures else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _grab_world() -> void:
	world = game.world
	world.set_physics_process(false)


func _tick(n: int, held := {}) -> void:
	for i in n:
		Controls.scripted = {"held": held, "pressed": held}
		world.tick()
	Controls.scripted = null


func _stand_at(o: LevelObject) -> void:
	var p := world.player
	p.x = o.center_x() - p.w / 2
	p.y = o.by + o.bh - p.h
	p.vx = 0
	p.vy = 0


func _use(o: LevelObject) -> void:
	_stand_at(o)
	_tick(2)
	_tick(1, {"move_up": true})
	_tick(1)


## Войти в выход и дождаться новой локации; spawn — где должен оказаться герой (тайл).
func _go(exit: LevelObject, level_name: String, spawn: Vector2i) -> void:
	if exit is EdgeExit:
		var p := world.player
		p.x = exit.bx
		p.y = exit.by + exit.bh - p.h
		_tick(1)
	else:
		_use(exit)
	await get_tree().process_frame
	await get_tree().process_frame
	_grab_world()
	_expect(world.level_name == level_name, "ждали «%s», попали в «%s»" % [level_name, world.level_name])
	var p := world.player
	var at := Vector2i(roundi(p.x / Level.TILE), roundi((p.y + p.h) / Level.TILE) - 1)
	_expect(at == spawn, "%s: герой в %s, ждём %s" % [level_name, at, spawn])


func _find(list: Array, uid: String) -> LevelObject:
	for o in list:
		if o.uid == uid:
			return o
	failures.append("нет объекта " + uid)
	return null


func _bag_count(id: String) -> int:
	var n := 0
	for cell in GameState.inv.bag:
		if cell and cell[0] == id:
			n += int(cell[1])
	return n


## Тайлы сцены совпадают с картой из .txt (твёрдые, доски, колья, пусто).
func _check_tiles(lvl: String) -> void:
	var rows: Array[String] = []
	var in_map := false
	for raw in FileAccess.get_file_as_string("res://data/levels/%s.txt" % lvl).split("\n"):
		var line := raw.trim_suffix("\r")
		if line.begins_with("["):
			in_map = line == "[map]"
			continue
		if in_map and line.strip_edges() != "":
			rows.append(line)
	var level: Level = load("res://scenes/levels/%s.tscn" % lvl).instantiate()
	add_child(level)
	var bad := 0
	for ty in rows.size():
		for tx in level.w:
			var ch := rows[ty][tx] if tx < rows[ty].length() else "."
			var want := Level.Kind.EMPTY
			if ch in SOLID: want = Level.Kind.SOLID
			elif ch == "=": want = Level.Kind.PLATFORM
			elif ch == "^": want = Level.Kind.SPIKES
			if level.kind_at(tx, ty) != want:
				bad += 1
	_expect(level.h == rows.size(), "%s: высота %d, ждём %d" % [lvl, level.h, rows.size()])
	_expect(bad == 0, "%s: не совпало тайлов: %d" % [lvl, bad])
	level.queue_free()
