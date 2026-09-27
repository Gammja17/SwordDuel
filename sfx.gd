extends Node
## Plays the recorded CC0 sound effects in assets/sfx. Files are grouped by name
## prefix (clash_1.ogg, clash_2.ogg -> "clash") and play() picks a random variant, so
## repeated hits don't sound identical. Missing groups are silently skipped.

const DIR := "res://assets/sfx/"

var _groups := {}  # prefix -> Array[AudioStream]
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _ambience: AudioStreamPlayer


## Volume channels, each 0..1 (linear). Effects and the wind ambience have their own
## buses under Master so the settings panel can set them separately.
const BUSES := ["Master", "SFX", "Ambience"]
const DEFAULT_VOLUME := {"Master": 0.5, "SFX": 0.8, "Ambience": 0.5}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	for bus in BUSES:
		set_volume(bus, DEFAULT_VOLUME[bus])
	_scan()
	for i in 16:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_distance = 40.0
		p.bus = "SFX"
		add_child(p)
		_pool3d.append(p)
	for i in 6:
		var q := AudioStreamPlayer.new()
		q.bus = "SFX"
		add_child(q)
		_pool2d.append(q)


func set_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func get_volume(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1 or AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func has(group: String) -> bool:
	return _groups.has(group)


## Positional sound at pos (world space).
func play(group: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var stream := _pick(group)
	if stream == null:
		return
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Non-positional sound (UI, the player's own body).
func play_flat(group: String, volume_db := 0.0, pitch_jitter := 0.05) -> void:
	var stream := _pick(group)
	if stream == null:
		return
	var q := _pool2d[_next2d]
	_next2d = (_next2d + 1) % _pool2d.size()
	q.stream = stream
	q.volume_db = volume_db
	q.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	q.play()


## Looping background ambience (restarts itself when it ends).
func start_ambience(group: String, volume_db := -14.0) -> void:
	var stream := _pick(group)
	if stream == null:
		return
	if _ambience == null:
		_ambience = AudioStreamPlayer.new()
		_ambience.bus = "Ambience"
		add_child(_ambience)
		_ambience.finished.connect(_ambience.play)
	if _ambience.playing and _ambience.stream == stream:
		return
	_ambience.stream = stream
	_ambience.volume_db = volume_db
	_ambience.play()


func _pick(group: String) -> AudioStream:
	var list: Array = _groups.get(group, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()]


func _scan() -> void:
	var names := PackedStringArray()
	if ResourceLoader.has_method("list_directory"):
		names = ResourceLoader.call("list_directory", DIR)
	else:
		var d := DirAccess.open(DIR)
		if d != null:
			for f in d.get_files():
				names.append(f.trim_suffix(".import").trim_suffix(".remap"))
	for file in names:
		if not (file.ends_with(".ogg") or file.ends_with(".wav") or file.ends_with(".mp3")):
			continue
		var path := DIR + file
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		var group := file.get_basename().rstrip("0123456789").trim_suffix("_")
		if not _groups.has(group):
			_groups[group] = []
		(_groups[group] as Array).append(stream)
