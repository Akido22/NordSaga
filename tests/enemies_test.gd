extends Node
## Сверка врагов и ярла с Pyxel-версией (эталон — tests/reference/enemies.json).
## godot --headless --path . res://tests/enemies_test.tscn
## Дуэли с волком, драугром, драугром со щитом, лучником, стаей и бой с ярлом:
## каждый кадр герой, все враги и снаряды должны совпасть с эталоном (расстояния x2).

const SCALE := 2.0
const EPS := 1e-6
const MAX_REPORTS := 4


func _ready() -> void:
	SaveSystem.path = "user://enemies_test_save.json"
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/enemies.json"))
	var failed := 0
	for c in cases:
		if not _run(c):
			failed += 1
	SaveSystem.delete()
	if failed:
		printerr("ENEMIES FAIL: не сошлось сценариев %d из %d" % [failed, cases.size()])
	else:
		print("ENEMIES OK: %d сценариев совпали с Pyxel-версией" % cases.size())
	get_tree().quit(1 if failed else 0)


func _run(c: Dictionary) -> bool:
	GameState.reset()
	GameState.spawn = null
	for slot in c.equip:
		GameState.inv.equipment[slot] = c.equip[slot]
	GameState.inv.stats.vit = int(c.vit)
	GameState.hp = GameState.max_hp()
	var world: World = load("res://scenes/world/world.tscn").instantiate()
	var path: String = c.level
	world.level_name = path.get_file().get_basename() if path.begins_with("data/") else "res://" + path.get_basename() + ".tscn"
	world.spawn = c.spawn
	world.scripted_rng = int(c.seed)
	world.respawn_after_death = false
	world.set_physics_process(false)
	add_child(world)

	var i := 0
	var prev := {}
	var reports := 0
	var bad_frames := 0
	for step in c.scenario:
		for f in int(step[0]):
			var held := {}
			for a in step[1]:
				held[a] = true
			var pressed := {}
			for a in held:
				if not prev.has(a):
					pressed[a] = true
			prev = held
			Controls.scripted = {"held": held, "pressed": pressed}
			world.tick()
			var diff := _compare(world, c.trace[i])
			if diff:
				bad_frames += 1
				if reports < MAX_REPORTS:
					reports += 1
					printerr("%s, кадр %d: %s" % [c.name, i, diff])
			i += 1
	Controls.scripted = null
	world.queue_free()
	if bad_frames:
		printerr("%s: расхождений %d из %d кадров" % [c.name, bad_frames, i])
	else:
		print("%s: %d кадров совпали" % [c.name, i])
	return bad_frames == 0


func _near(a: float, b: float) -> bool:
	return absf(a - b * SCALE) <= EPS


func _compare(world: World, r: Array) -> String:
	var p := world.player
	var rp: Array = r[0]
	var got := [p.x, p.y, p.vx, p.vy, p.state, snappedf(p.stamina, 0.000001), GameState.hp, world.hitstop]
	for k in 4:
		if not _near(got[k], rp[k]):
			return "герой %s: ждём %s, получили %s" % [["x", "y", "vx", "vy"][k], rp[k] * SCALE, got[k]]
	if got[4] != rp[4] or absf(got[5] - rp[5]) > 1e-5 or got[6] != int(rp[6]) or got[7] != int(rp[7]):
		return "герой: ждём %s, получили %s" % [str(rp.slice(4)), str(got.slice(4))]
	var foes: Array = r[1]
	if foes.size() != world.enemies.size():
		return "врагов: ждём %d, получили %d" % [foes.size(), world.enemies.size()]
	for j in foes.size():
		var e: Enemy = world.enemies[j]
		var re: Array = foes[j]
		var g := [_kind(e), e.x, e.y, e.vx, e.vy, e.hp, e.facing, e.stun_t, _state(e)]
		var ok: bool = (g[0] == re[0] and _near(g[1], re[1]) and _near(g[2], re[2]) and _near(g[3], re[3])
				and _near(g[4], re[4]) and g[5] == int(re[5]) and g[6] == int(re[6]) and g[7] == int(re[7])
				and g[8] == re[8])
		if not ok:
			return "враг %d: ждём %s (x2), получили %s" % [j, str(re), str(g)]
	var shots: Array = r[2]
	if shots.size() != world.projectiles.size():
		return "снарядов: ждём %d, получили %d" % [shots.size(), world.projectiles.size()]
	for j in shots.size():
		var s = world.projectiles[j]
		if not (_near(s.x, shots[j][0]) and _near(s.y, shots[j][1]) and _near(s.vx, shots[j][2])):
			return "снаряд %d: ждём %s (x2), получили %s" % [j, str(shots[j]), str([s.x, s.y, s.vx])]
	return ""


func _kind(e: Enemy) -> String:
	return e.kind


## Состояние в той же записи, что в эталоне.
func _state(e: Enemy) -> String:
	if e is Wolf:
		return "c%dl%dt%d" % [e.crouch_t, int(e.lunging), e.lunge_cd]
	if e is ShieldDraugr:
		return "%s%dg%d" % [e.state, e.state_t, e.guard]
	if e is Draugr:
		return "%s%d" % [e.state, e.state_t]
	if e is Archer:
		return "%s%dc%d" % [e.state, e.state_t, e.cooldown]
	if e is JarlBoss:
		return "%s%dp%d" % [e.state, e.state_t, e.phase]
	return ""
