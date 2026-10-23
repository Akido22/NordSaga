class_name Icons
## Иконки предметов 16x16 из assets/sprites/icons.png (порядок — icons.json).

const SHEET: Texture2D = preload("res://assets/sprites/icons.png")

static var _order := []
static var _cache := {}


static func cell() -> int:
	return 16


## Иконка по имени (icon у предмета: knife, coin, honey…).
static func texture(icon_name: String) -> AtlasTexture:
	if _order.is_empty():
		_order = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/icons.json")).order
	if not _cache.has(icon_name):
		var i := maxi(0, _order.find(icon_name))
		var t := AtlasTexture.new()
		t.atlas = SHEET
		t.region = Rect2(i * 16, 0, 16, 16)
		_cache[icon_name] = t
	return _cache[icon_name]
