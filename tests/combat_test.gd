extends Node
## Сверка боя героя с Pyxel-версией (эталон — tests/reference/combat.json).
## godot --headless --path . res://tests/combat_test.tscn
## Целый мир на «Ристалище»: удары по чучелам, стоп-кадры, перекаты, блок,
## выносливость — каждый кадр должен совпасть с эталоном (расстояния x2).

const SCALE := 2.0
const EPS := 1e-6
const IDLE_FRAMES := [0, 1, 2, 3]  # кадр «стоит» зависит от общего счётчика, его не сверяем
const FIELDS := ["x", "y", "vx", "vy", "состояние", "выносливость", "кадр", "серия", "стоп-кадр", "жизнь"]


func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/combat.json"))
	GameState.reset()
	GameState.spawn = null
	var world: World = load("res://scenes/world/world.tscn").instantiate()
	world.level_name = "arena"
	world.set_physics_process(false)
	world.respawn_after_death = false
	add_child(world)
	var p := world.player

	var i := 0
	var prev := {}
	var errors := 0
	for step in ref.scenario:
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
			var r: Array = ref.trace[i]
			var got := [p.x, p.y, p.vx, p.vy, p.state, snappedf(p.stamina, 0.000001), p.frame(), p.combo,
					world.hitstop, GameState.hp]
			var bad := []
			for k in 4:
				if absf(got[k] - r[k] * SCALE) > EPS:
					bad.append(FIELDS[k])
			if got[4] != r[4]:
				bad.append(FIELDS[4])
			if absf(got[5] - r[5]) > 1e-5:
				bad.append(FIELDS[5])
			if got[6] != int(r[6]) and not (int(r[6]) in IDLE_FRAMES and got[6] in IDLE_FRAMES):
				bad.append(FIELDS[6])
			for k in [7, 8, 9]:
				if got[k] != int(r[k]):
					bad.append(FIELDS[k])
			if bad:
				errors += 1
				if errors <= 5:
					printerr("кадр %d (%s): ждём %s (x2), получили %s" % [i, ", ".join(bad), str(r), str(got)])
			i += 1
	Controls.scripted = null
	if errors:
		printerr("COMBAT FAIL: расхождений %d из %d кадров" % [errors, i])
	else:
		print("COMBAT OK: %d кадров совпали с Pyxel-версией" % i)
	get_tree().quit(1 if errors else 0)
