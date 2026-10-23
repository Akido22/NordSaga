extends Node
## Сверка шага 7 с Pyxel-версией.
## godot --headless --path . res://tests/progress_test.tscn
## 1) tests/reference/inventory.json — 600 операций с сумой, лавками, кузней, опытом и
##    очками: после каждой сума и показатели должны совпасть.
## 2) tests/reference/magic.json — бой чарами и припасами: каждый кадр герой (мана,
##    щит Перуна), враги и снаряды (расстояния x2).

const SCALE := 2.0
const EPS := 1e-6

var failures: Array[String] = []


func _ready() -> void:
	SaveSystem.path = "user://progress_test_save.json"
	_inventory()
	_magic()
	SaveSystem.delete()
	if failures.is_empty():
		print("PROGRESS OK")
	else:
		for f in failures.slice(0, 8):
			printerr("FAIL: ", f)
		printerr("PROGRESS FAIL: расхождений %d" % failures.size())
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------ сума, лавки, кузня
func _inventory() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/inventory.json"))
	GameState.reset()
	var inv := Inventory.starting()
	GameState.inv = inv
	for i in ref.ops.size():
		var op: Array = ref.ops[i]
		match op[0]:
			"add": inv.add(op[1], int(op[2]))
			"equip": inv.equip_from_bag(int(op[1]))
			"unequip": inv.unequip(op[1])
			"take": inv.take(op[1], int(op[2]))
			"xp": inv.add_xp(int(op[1]))
			"spend": inv.spend_point(op[1])
			"silver": inv.silver += int(op[1])
			"next_spell": inv.next_spell()
			"trade":
				var tm := TradeMenu.new(op[1], int(op[2]))
				var rows := tm.entries()
				if not rows.is_empty():
					tm.act(rows[int(op[3]) % rows.size()])
				tm.free()
		var snap: Array = ref.snaps[i]
		var got := [inv.max_hp(), inv.attack(), inv.defense(), inv.max_stamina(), inv.max_mana(),
				inv.spell(), inv.first_consumable()]
		if not _same(inv.to_dict(), snap[0]) or not _same(got, snap[1]):
			failures.append("сума, операция %d %s: ждём %s %s, получили %s %s" % [
					i, str(op), JSON.stringify(snap[0]), str(snap[1]), JSON.stringify(inv.to_dict()), str(got)])
			return


## Равенство с эталоном из JSON (числа сравниваются как числа).
func _same(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < EPS
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	return a == b


# ------------------------------------------------------------ чары и припасы
func _magic() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/magic.json"))
	GameState.reset()
	GameState.spawn = null
	var inv := GameState.inv
	inv.spells = ["rune_fire", "rune_shield", "rune_heal"]
	inv.stats.spi = int(ref.spirit)
	inv.stats.vit = int(ref.vit)
	inv.add("honey", 2)
	GameState.hp = inv.max_hp()
	var world: World = load("res://scenes/world/world.tscn").instantiate()
	world.level_name = "res://tests/levels/duel_draugr.tscn"
	world.respawn_after_death = false
	world.set_physics_process(false)
	add_child(world)
	GameState.hp = int(ref.hp)  # чтобы было что лечить
	var p := world.player
	var i := 0
	var prev := {}
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
			var diff := _compare_magic(world, p, ref.trace[i])
			if diff:
				failures.append("чары, кадр %d: %s" % [i, diff])
				if failures.size() > 6:
					Controls.scripted = null
					return
			i += 1
	Controls.scripted = null
	world.queue_free()


func _near(a: float, b: float) -> bool:
	return absf(a - b * SCALE) <= EPS


func _compare_magic(world: World, p: Player, r: Array) -> String:
	var rp: Array = r[0]
	var got := [p.x, p.y, p.vx, p.vy, p.state, snappedf(p.stamina, 0.000001), GameState.hp,
			snappedf(p.mana, 0.000001), p.shield_t, world.hitstop, GameState.inv.active_spell]
	for k in 4:
		if not _near(got[k], rp[k]):
			return "герой %s: ждём %s, получили %s" % [["x", "y", "vx", "vy"][k], rp[k] * SCALE, got[k]]
	for k in range(4, got.size()):
		if not _same(got[k], rp[k]):
			return "герой: ждём %s, получили %s" % [str(rp.slice(4)), str(got.slice(4))]
	var foes: Array = r[1]
	if foes.size() != world.enemies.size():
		return "врагов: ждём %d, получили %d" % [foes.size(), world.enemies.size()]
	for j in foes.size():
		var e: Enemy = world.enemies[j]
		var re: Array = foes[j]
		if not (_near(e.x, re[0]) and _near(e.y, re[1]) and _near(e.vx, re[2]) and _near(e.vy, re[3])
				and e.hp == int(re[4]) and e.stun_t == int(re[5]) and str(e.get("state")) == re[6]):
			return "враг %d: ждём %s (x2), получили %s" % [j, str(re), str([e.x, e.y, e.vx, e.vy, e.hp, e.stun_t, e.get("state")])]
	var shots: Array = r[2]
	if shots.size() != world.projectiles.size():
		return "снарядов: ждём %d, получили %d" % [shots.size(), world.projectiles.size()]
	for j in shots.size():
		var s = world.projectiles[j]
		var name: String = s.get_script().get_global_name()
		if name != shots[j][0] or not (_near(s.x, shots[j][1]) and _near(s.y, shots[j][2]) and _near(s.vx, shots[j][3])):
			return "снаряд %d: ждём %s (x2), получили %s" % [j, str(shots[j]), str([name, s.x, s.y, s.vx])]
	return ""
