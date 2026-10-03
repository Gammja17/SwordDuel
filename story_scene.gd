extends Node3D
## A scripted 3D cutscene: a few bodies (knight_body.gd) in the arena, a camera that
## cuts and drifts, and lines of dialogue you click through. It plays a script, which is
## plain data (see scenes.gd for examples):
##
##   {
##     "actors": {id: {"outfit": "squire", "at": Vector3, "look": id or Vector3, "pose": "open"}},
##     "beats": [
##       {"cam": {"pos": Vector3, "look": Vector3 or actor id, "fov": 50.0, "drift": Vector3},
##        "walk": {id: Vector3}, "speed": 1.2,       # actors walk to a point (and stay there)
##        "face": {id: id or Vector3},               # turn toward
##        "clip": {id: "Idle_Talking_Loop"},         # a full-body clip, looped
##        "line": ["name", "what they say"],         # waits for a click
##        "dur": 2.0},                               # a beat with no line lasts this long
##     ],
##   }
##
## A beat with a line ends on a click (the first click finishes the typing). Escape skips
## the whole scene. `finished` is emitted once, when it ends either way.

signal finished

const BodyScript := preload("res://knight_body.gd")
const SwordPoses := preload("res://sword_poses.gd")
const FONT_BODY := "res://assets/fonts/NanumMyeongjo-Regular.ttf"
const FONT_TITLE := "res://assets/fonts/NanumMyeongjo-ExtraBold.ttf"
const TYPE_SPEED := 45.0     # characters per second
const MIN_BEAT := 0.3        # a click right after a line appears is ignored for this long
const WALK_SPEED := 1.2

var _cam: Camera3D
var _actors := {}            # id -> {"body", "goal", "clip", "clip_t", "pose"}
var _beats: Array = []
var _i := -1
var _t := 0.0                # time into the current beat
var _dur := 0.0
var _has_line := false
var _speed := WALK_SPEED
var _drift := Vector3.ZERO
var _look: Variant = null    # where the camera looks: a point, or an actor id
var speed := 1.0              # the text speed setting
var _done := false
var flags := {}              # choices made in scenes (main.gd keeps and saves it)
var _choice := {}            # the choice beat waiting for 1 / 2, if any
var _layer: CanvasLayer
var _name: Label
var _text: Label
var _hint: Label
var _panel: PanelContainer
var _fade: ColorRect


func play(script: Dictionary) -> void:
	_beats = script.get("beats", [])
	for id in script.get("actors", {}):
		_add_actor(id, script["actors"][id])
	for id in script.get("actors", {}):
		if script["actors"][id].has("look"):
			_face(id, script["actors"][id]["look"])   # (once everyone is standing there)
	_cam = Camera3D.new()
	_cam.near = 0.05
	add_child(_cam)
	_cam.current = true
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
	_next()


func is_done() -> bool:
	return _done


## A click (or space / enter): finish the typing, or go on to the next beat.
func advance() -> void:
	if _done or not _has_line or _t < MIN_BEAT:
		return
	if _text.visible_characters < _text.text.length():
		_text.visible_characters = _text.text.length()
	else:
		_next()


func skip() -> void:
	_end()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		var k := (event as InputEventKey).physical_keycode
		if not _choice.is_empty() and (k == KEY_1 or k == KEY_2):
			_pick(0 if k == KEY_1 else 1)
		elif k == KEY_ESCAPE:
			skip()
		elif k == KEY_SPACE or k == KEY_ENTER:
			advance()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	for id in _actors:
		_update_actor(id, delta)
	_update_camera(delta)
	if _has_line:
		_text.visible_characters = mini(int(_t * TYPE_SPEED * speed), _text.text.length())
	elif _t >= _dur:
		_next()


# --- beats ------------------------------------------------------------------------------

func _next() -> void:
	_i += 1
	if _i >= _beats.size():
		_end()
		return
	var b: Dictionary = _beats[_i]
	_t = 0.0
	_panel.visible = false
	_dur = float(b.get("dur", 2.0))
	_speed = float(b.get("speed", WALK_SPEED))
	if b.has("cam"):
		_set_camera(b["cam"])
	for id in b.get("walk", {}):
		_actors[id].goal = b["walk"][id]
	for id in b.get("face", {}):
		_face(id, b["face"][id])
	for id in b.get("clip", {}):
		_actors[id].clip = b["clip"][id]
		_actors[id].clip_t = 0.0
		if _actors[id].clip == "":
			_actors[id].clip = "Idle_Loop"   # back to standing easy
		_play_clip(id)
	if b.has("choice"):
		_start_choice(b["choice"])
		return
	if b.has("line_if"):
		b["line"] = b["line_if"]["lines"][int(flags.get(b["line_if"]["key"], 0))]
	_has_line = b.has("line")
	_panel.visible = _has_line
	if _has_line:
		_name.text = b["line"][0]
		_text.text = b["line"][1]
		_text.visible_characters = 0


func _end() -> void:
	if _done:
		return
	if not _choice.is_empty():
		flags[_choice["key"]] = 0   # skipped past a choice: the kinder answer
	_done = true
	_layer.queue_free()
	finished.emit()
	queue_free()


# --- choices --------------------------------------------------------------------------------

## A beat {"choice": {"key": flag name, "prompt": text, "options": [a, b]}}: wait for 1 / 2 and
## store the pick (0 or 1) in flags[key].
func _start_choice(c: Dictionary) -> void:
	_choice = c
	_has_line = false
	_dur = 1.0e9
	_panel.visible = true
	_name.text = ""
	var lines: String = c["prompt"] + "\n"
	for i in c["options"].size():
		lines += "\n%d  %s" % [i + 1, c["options"][i]]
	_text.text = lines
	_text.visible_characters = -1
	_hint.text = "1 / 2 키로 고르세요"


func _pick(i: int) -> void:
	if _choice.is_empty() or i >= _choice["options"].size():
		return
	flags[_choice["key"]] = i
	_choice = {}
	_hint.text = "클릭: 다음   Esc: 건너뛰기"
	_next()


# --- actors -----------------------------------------------------------------------------

func _add_actor(id: String, spec: Dictionary) -> void:
	var body = BodyScript.new()
	add_child(body)
	body.build(spec.get("tabard", Color()), spec.get("crest", false), spec.get("outfit", "squire"))
	body.position = spec.get("at", Vector3.ZERO)
	body._two_hands = 0.0   # the left hand hangs free
	body._grip_hands.open_left = true
	var a := {"body": body, "goal": null, "clip": "Idle_Loop", "clip_t": 0.0, "walking": false, "pose": spec.get("pose", "relaxed")}
	_actors[id] = a


func _point_of(target: Variant) -> Vector3:
	if target is Vector3:
		return target
	return (_actors[target].body as Node3D).global_position


func _face(id: String, target: Variant) -> void:
	var body: Node3D = _actors[id].body
	var p := _point_of(target)
	p.y = body.global_position.y
	if body.global_position.distance_to(p) > 0.05:
		body.look_at(p, Vector3.UP)


func _play_clip(id: String) -> void:
	var a: Dictionary = _actors[id]
	var len: float = a.body.clip_length(a.clip)
	if len > 0.0:
		a.body.act(a.clip, 0.0, len, len, 0.3)


func _update_actor(id: String, delta: float) -> void:
	var a: Dictionary = _actors[id]
	var body: Node3D = a.body
	if a.goal != null and not a.walking:
		a.walking = true
		body.release(0.12)   # the legs walk (an action clip would freeze them)
	if a.goal != null:
		var to: Vector3 = a.goal - body.global_position
		to.y = 0.0
		if to.length() < 0.06:
			a.goal = null
			a.walking = false
			a.clip_t = 0.0
			_play_clip(id)
			body.move(Vector2.ZERO)
		else:
			_face(id, a.goal)
			body.global_position += to.normalized() * minf(_speed * delta, to.length())
			body.move(Vector2(0.0, _speed))
	else:
		body.move(Vector2.ZERO)
	if a.clip != "" and not a.walking:
		a.clip_t += delta
		if a.clip_t >= body.clip_length(a.clip):
			a.clip_t = 0.0
			_play_clip(id)
	body.update_body(delta)
	body.pose(SwordPoses.make(a.pose))


# --- camera -----------------------------------------------------------------------------

func _set_camera(c: Dictionary) -> void:
	_cam.global_position = c.get("pos", _cam.global_position)
	_look = c.get("look", _look)
	_cam.fov = float(c.get("fov", 50.0))
	_drift = c.get("drift", Vector3.ZERO)
	_aim_camera()


func _update_camera(delta: float) -> void:
	_cam.global_position += _drift * delta
	_aim_camera()


func _aim_camera() -> void:
	if _look == null:
		return
	var p := _point_of(_look)
	if _look is String:
		p.y += 0.95   # below the head, so the figure sits in the upper part of the frame
	if _cam.global_position.distance_to(p) > 0.05:
		_cam.look_at(p, Vector3.UP)


# --- dialogue box -------------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 220.0
	_panel.offset_right = -220.0
	_panel.offset_top = -138.0
	_panel.offset_bottom = -26.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.03, 0.82)
	sb.border_color = Color(0.98, 0.82, 0.35, 0.7)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_override("font", load(FONT_TITLE))
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	box.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_override("font", load(FONT_BODY))
	_text.add_theme_font_size_override("font_size", 23)
	_text.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_hint = Label.new()
	_hint.text = "클릭: 다음   Esc: 건너뛰기"
	_hint.add_theme_font_override("font", load(FONT_BODY))
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)
	_panel.visible = false
