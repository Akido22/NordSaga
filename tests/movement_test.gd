extends Node
## Сверка движения героя с Pyxel-версией (эталон — tests/reference/movement.json).
## godot --headless --path . res://tests/movement_test.tscn
## Каждый кадр положение и скорость должны совпасть с эталоном x2.

const SCALE := 2.0
const EPS := 1e-6
const IDLE_FRAMES := [0, 1, 2, 3]  # кадр «стоит» зависит от общего счётчика, его не сверяем


func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/movement.json"))
	GameState.reset()
	var world: World = load("res://scenes/world/world.tscn").instantiate()
	world.level_name = "test_level"
	GameState.spawn = null
	world.set_physics_process(false)
	world.respawn_after_death = false
	world.spawn_enemies = false
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
			var got := [p.x, p.y, p.vx, p.vy, p.on_ground, p.facing, p.frame(), GameState.hp]
			var ok: bool = (absf(got[0] - r[0] * SCALE) < EPS and absf(got[1] - r[1] * SCALE) < EPS
					and absf(got[2] - r[2] * SCALE) < EPS and absf(got[3] - r[3] * SCALE) < EPS
					and got[4] == r[4] and got[5] == int(r[5]) and got[7] == int(r[7])
					and (got[6] == int(r[6]) or (int(r[6]) in IDLE_FRAMES and got[6] in IDLE_FRAMES)))
			if not ok:
				errors += 1
				if errors <= 5:
					printerr("кадр %d: ждём %s (x2), получили %s" % [i, str(r), str(got)])
			i += 1
	Controls.scripted = null
	if errors:
		printerr("MOVEMENT FAIL: расхождений %d из %d кадров" % [errors, i])
	else:
		print("MOVEMENT OK: %d кадров совпали с Pyxel-версией" % i)
	get_tree().quit(1 if errors else 0)
