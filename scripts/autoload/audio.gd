extends Node
## Звуки и музыка. Файлы: assets/audio/sfx/<имя>.wav|.ogg, assets/audio/music/<имя>.ogg|.wav.
## Отсутствующий звук молча пропускается (до шага 2 файлов нет).

const SFX_VOICES := 8  # сколько эффектов звучит одновременно

var music_on := true
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_music"):
		toggle_music()


func sfx(id: String) -> void:
	var stream := _stream("sfx", id)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream
	p.play()


func music(id: String) -> void:
	if id == _music_name and _music.playing:
		return
	_music_name = id
	_music.stream = _stream("music", id)
	if music_on and _music.stream:
		_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func toggle_music() -> void:
	music_on = not music_on
	if music_on and _music.stream:
		_music.play()
	else:
		_music.stop()


func _stream(kind: String, id: String) -> AudioStream:
	var key := kind + "/" + id
	if not _cache.has(key):
		_cache[key] = null
		for ext in ["ogg", "wav"]:
			var path := "res://assets/audio/%s/%s.%s" % [kind, id, ext]
			if ResourceLoader.exists(path):
				_cache[key] = load(path)
				break
	return _cache[key]
