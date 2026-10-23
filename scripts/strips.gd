class_name Strips
## Анимации из лент кадров (PNG + JSON-описание из tools/export_for_godot.py).
## Описание кадра: frame_w, frame_h, frames, fps, anchor — точка привязки в уровне
## (низ-левый угол тайла, на котором стоит объект).

static var _meta_cache := {}


## Описание ленты name из каталога dir (objects.json / props.json лежат рядом с PNG).
static func meta(dir: String, name: String) -> Dictionary:
	var json_path := "%s/%s.json" % [dir, dir.get_file()]
	if not _meta_cache.has(json_path):
		_meta_cache[json_path] = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	return _meta_cache[json_path].get(name, {})


static func names(dir: String) -> Array:
	meta(dir, "")
	return _meta_cache["%s/%s.json" % [dir, dir.get_file()]].keys()


## SpriteFrames с одной зацикленной анимацией «default».
static func frames(dir: String, name: String) -> SpriteFrames:
	var m := meta(dir, name)
	var sheet: Texture2D = load("%s/%s.png" % [dir, name])
	var sf := SpriteFrames.new()
	sf.set_animation_speed(&"default", m.fps)
	for i in int(m.frames):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * m.frame_w, 0, m.frame_w, m.frame_h)
		sf.add_frame(&"default", atlas)
	return sf


## Готовый узел: точка (0, 0) узла — точка привязки объекта.
static func sprite(dir: String, name: String) -> AnimatedSprite2D:
	var m := meta(dir, name)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(dir, name)
	s.centered = false
	s.offset = -Vector2(m.anchor[0], m.anchor[1])
	if int(m.frames) > 1:
		s.play()
	return s
