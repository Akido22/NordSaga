class_name Icons
## Иконки предметов 16x16 из assets/sprites/icons.png (порядок — icons.json).
## У предмета может быть перекраска tint ({"4": "8"}) — такие иконки собираются один раз и кэшируются.

const SHEET: Texture2D = preload("res://assets/sprites/icons.png")

static var _order := []
static var _cache := {}


## Иконка по имени (icon у предмета: knife, coin, honey…).
static func texture(icon_name: String) -> Texture2D:
	if _order.is_empty():
		_order = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/icons.json")).order
	if not _cache.has(icon_name):
		var i := maxi(0, _order.find(icon_name))
		var t := AtlasTexture.new()
		t.atlas = SHEET
		t.region = Rect2(i * 16, 0, 16, 16)
		_cache[icon_name] = t
	return _cache[icon_name]


## Иконка предмета с его перекраской.
static func of(it: Dictionary) -> Texture2D:
	var tint: Dictionary = it.get("tint", {})
	if tint.is_empty():
		return texture(it.icon)
	var k: String = it.icon + JSON.stringify(tint)
	if not _cache.has(k):
		var img := (texture(it.icon) as AtlasTexture).get_image()
		var swap := {}
		for src in tint:
			swap[Pal.BY_INDEX[("0x" + str(src)).hex_to_int()].to_html(false)] = Pal.BY_INDEX[("0x" + str(tint[src])).hex_to_int()]
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0 and swap.has(c.to_html(false)):
					img.set_pixel(x, y, swap[c.to_html(false)])
		_cache[k] = ImageTexture.create_from_image(img)
	return _cache[k]
