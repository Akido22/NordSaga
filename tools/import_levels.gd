extends Node
## Собирает сцены локаций scenes/levels/<имя>.tscn из карт Pyxel-версии data/levels/*.txt.
## godot --headless --path . res://tools/import_levels.tscn
## (Сцена, а не --script: скриптам объектов нужны глобальные Data и Audio.)
## Внимание: перезаписывает сцены — правки, сделанные в редакторе, пропадут.

## Откуда и куда: карты игры и площадки автотестов.
const DIRS := [["res://data/levels", "res://scenes/levels"], ["res://tests/levels", "res://tests/levels"]]
const T := 16

const TILE_CHARS := {"S": "stone", "L": "log", "=": "plank", "^": "spikes", "_": "boardwalk", "%": "flagstone"}
const DECOR_TILES := {"g": "tuft", "m": "mushroom"}
const DECOR := {"B": "birch", "I": "idol", "F": "fire"}
const ENEMIES := {"W": "wolf", "D": "draugr", "K": "shield_draugr", "A": "archer", "U": "dummy", "J": "jarl"}
const MUSIC := ["forest", "town", "boss"]
const ARROWS := {"{UP}": "↑", "{DOWN}": "↓", "{LEFT}": "←", "{RIGHT}": "→"}
## Ширина построек по умолчанию (в тайлах), как в Pyxel-версии.
const PROP_W := {"izba": 8, "longhouse": 14, "forge": 7, "well": 3, "stall": 6, "fence": 4,
		"banner": 1, "lantern": 1, "oak": 2, "barrels": 2, "wall": 2, "torch": 1, "bones": 2,
		"urn": 2, "throne": 5}

var _order: Array


func _ready() -> void:
	_order = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/tiles.json")).order
	var failed := false
	for pair in DIRS:
		var src: String = pair[0]
		var dst: String = pair[1]
		DirAccess.make_dir_recursive_absolute(dst)
		for file in DirAccess.get_files_at(src):
			if file.get_extension() != "txt":
				continue
			var root := _build(src.path_join(file))
			var packed := PackedScene.new()
			var err := packed.pack(root)
			if err == OK:
				err = ResourceSaver.save(packed, dst.path_join(file.get_basename() + ".tscn"))
			print("%s -> %s: %s" % [file, dst.path_join(file.get_basename() + ".tscn"), error_string(err)])
			failed = failed or err != OK
			root.free()
	get_tree().quit(1 if failed else 0)


func _parse(path: String) -> Dictionary:
	var d := {"meta": {}, "rows": [], "spawns": {}, "chests": {}, "signs": {}, "exits": {}, "props": [], "npcs": []}
	var section := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.trim_suffix("\r")
		if section != "map" and (line.strip_edges() == "" or line.strip_edges().begins_with("#")):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		if section == "map":
			if line.strip_edges() != "":
				d.rows.append(line)
		elif section == "props":
			var parts := line.split(" ", false)
			d.props.append([parts[0], _pos(parts[1]), int(parts[2]) if parts.size() > 2 else 0])
		elif "=" in line:
			var key := line.get_slice("=", 0).strip_edges()
			var value := _text(line.substr(line.find("=") + 1))
			match section:
				"meta": d.meta[key] = value
				"spawns": d.spawns[key] = _pos(value)
				"chests":
					var loot := PackedStringArray()
					for v in value.split(","):
						if v.strip_edges():
							loot.append(v.strip_edges())
					d.chests[_pos(key)] = loot
				"signs": d.signs[_pos(key)] = value
				"npcs": d.npcs.append([_pos(key), value])
				"exits":
					var parts := value.split(" ", false)
					d.exits[_pos(key)] = [parts[0], parts[1] if parts.size() > 1 else "",
							parts[2] if parts.size() > 2 else "forest"]
	return d


func _pos(s: String) -> Vector2i:
	return Vector2i(int(s.get_slice(",", 0)), int(s.get_slice(",", 1)))


func _text(s: String) -> String:
	s = s.strip_edges()
	for token in ARROWS:
		s = s.replace(token, ARROWS[token])
	return s


## Точка привязки тайла (столбец, строка): его левый нижний угол.
func _at(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * T, (tile.y + 1) * T)


func _build(path: String) -> Level:
	var d := _parse(path)
	var rows: Array = d.rows
	var width := 0
	for r in rows:
		width = maxi(width, r.length())
	var root := Level.new()
	root.name = path.get_file().get_basename().to_pascal_case()
	root.title = d.meta.get("title", "")
	root.subtitle = d.meta.get("subtitle", "")
	root.sky = d.meta.get("sky", "forest")
	root.music = MUSIC[clampi(int(d.meta.get("music", "0")), 0, 2)]
	root.size_tiles = Vector2i(width, rows.size())
	if d.meta.has("boss"):
		var door: PackedStringArray = str(d.meta.get("arena_door", "")).split(" ", false)
		root.boss = {
			"boss": d.meta.boss,
			"arena_trigger": int(d.meta.get("arena_trigger", "0")),
			"arena_door": [int(door[0]), int(door[1]), int(door[2])] if door.size() == 3 else [],
			"boss_chest": d.meta.get("boss_chest", ""),
		}

	var tiles: TileMapLayer = _child(root, TileMapLayer.new(), "Tiles")
	tiles.tile_set = Level.TILESET
	var decor_tiles: TileMapLayer = _child(root, TileMapLayer.new(), "Decor")
	decor_tiles.tile_set = Level.TILESET
	var props: Node2D = _child(root, Node2D.new(), "Props")
	var objects: Node2D = _child(root, Node2D.new(), "Objects")
	var npcs: Node2D = _child(root, Node2D.new(), "Npcs")
	var enemies: Node2D = _child(root, Node2D.new(), "Enemies")
	var spawns: Node2D = _child(root, Node2D.new(), "Spawns")

	for ty in rows.size():
		var row: String = rows[ty].rpad(width, ".")
		for tx in width:
			var ch := row[tx]
			var cell := Vector2i(tx, ty)
			if ch == "#":
				var above: String = rows[ty - 1][tx] if ty > 0 and tx < rows[ty - 1].length() else "."
				tiles.set_cell(cell, 0, Vector2i(_order.find("dirt" if above in "#S_%L" else "grass"), 0))
			elif TILE_CHARS.has(ch):
				tiles.set_cell(cell, 0, Vector2i(_order.find(TILE_CHARS[ch]), 0))
			elif DECOR_TILES.has(ch):
				decor_tiles.set_cell(cell, 0, Vector2i(_order.find(DECOR_TILES[ch]), 0))
			elif ch == "P":
				_child(spawns, Marker2D.new(), "Start").position = _at(cell)
			elif ENEMIES.has(ch):
				var m := EnemyMarker.new()
				m.kind = ENEMIES[ch]
				_child(enemies, m, "%s_%d_%d" % [m.kind, tx, ty]).position = _at(cell)
			elif ch in "oh":
				var p := Pickup.new()
				p.kind = "coin" if ch == "o" else "honey"
				_child(objects, p, "Pickup_%d_%d" % [tx, ty]).position = _at(cell)
			elif ch != "." and ch != " ":
				var obj := _object(ch, cell, d)
				if obj:
					_child(objects, obj, "%s_%d_%d" % [obj.get_script().get_global_name(), tx, ty]).position = _at(cell)
				else:
					push_warning("%s: неизвестный символ «%s» в %d,%d" % [path, ch, tx, ty])

	for name in d.spawns:
		_child(spawns, Marker2D.new(), name).position = _at(d.spawns[name])
	for pr in d.props:
		var p := Prop.new()
		p.kind = pr[0]
		p.width = pr[2] if pr[2] else PROP_W.get(pr[0], 2)
		_child(props, p, "%s_%d_%d" % [p.kind, pr[1].x, pr[1].y]).position = _at(pr[1])
	for n in d.npcs:
		var npc := Npc.new()
		npc.npc_id = n[1]
		_child(npcs, npc, n[1]).position = _at(n[0])
	return root


func _object(ch: String, cell: Vector2i, d: Dictionary) -> Node2D:
	match ch:
		"C":
			var c := Chest.new()
			c.loot = d.chests.get(cell, PackedStringArray())
			return c
		"R", "T":
			var s := SavePoint.new()
			s.kind = "runestone" if ch == "R" else "stela"
			return s
		"Y":
			var s := Sign.new()
			s.text = d.signs.get(cell, "...")
			return s
		"E":
			var g := Gate.new()
			var ex: Array = d.exits.get(cell, ["end", "", "forest"])
			g.target = ex[0]
			g.spawn = ex[1]
			g.style = ex[2]
			return g
		"X":
			var e := EdgeExit.new()
			var ex: Array = d.exits.get(cell, ["end", "", ""])
			e.target = ex[0]
			e.spawn = ex[1]
			return e
	if DECOR.has(ch):
		var dc := Decor.new()
		dc.kind = DECOR[ch]
		return dc
	return null


func _child(parent: Node, node: Node, node_name: String):
	node.name = node_name
	parent.add_child(node)
	var root := parent
	while root.get_parent():
		root = root.get_parent()
	node.owner = root
	return node
