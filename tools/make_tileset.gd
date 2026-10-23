extends SceneTree
## Собирает assets/tiles/tiles.tres из tiles.png и tiles.json.
## godot --headless --path . --script res://tools/make_tileset.gd
## Пользовательские данные тайла «kind»: solid, platform, spikes, decor или пусто.

const JSON_PATH := "res://assets/tiles/tiles.json"
const OUT := "res://assets/tiles/tiles.tres"


func _init() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	var size := int(info.tile)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/tiles.png")
	src.texture_region_size = Vector2i(size, size)
	ts.add_source(src, 0)
	var order: Array = info.order
	for i in order.size():
		var name: String = order[i]
		src.create_tile(Vector2i(i, 0))
		var kind := ""
		if name in info.solid: kind = "solid"
		elif name in info.one_way: kind = "platform"
		elif name in info.hazard: kind = "spikes"
		elif name in info.decor: kind = "decor"
		src.get_tile_data(Vector2i(i, 0), 0).set_custom_data("kind", kind)
	var err := ResourceSaver.save(ts, OUT)
	print("tileset: ", OUT, " ", error_string(err))
	quit(0 if err == OK else 1)
