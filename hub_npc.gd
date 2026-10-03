extends Node3D
## Someone standing about in the dormitory yard: a body at ease, a name floating over
## their head, turning to face you when you come near.

const BodyScript := preload("res://knight_body.gd")
const SwordPoses := preload("res://sword_poses.gd")
const FONT_TITLE := "res://assets/fonts/NanumMyeongjo-ExtraBold.ttf"
const NOTICE := 5.0   # they turn toward you within this distance (m)

var who := ""           # id, e.g. "doyun"
var display_name := ""
var target: Node3D      # who to turn toward (the player)
var _body
var _clip_t := 0.0


func setup(id: String, name_: String, outfit: String, look_at_target: Node3D) -> void:
	who = id
	display_name = name_
	target = look_at_target
	_body = BodyScript.new()
	add_child(_body)
	_body.build(Color(), false, outfit)
	_body._two_hands = 0.0
	_body._grip_hands.open_left = true
	var label := Label3D.new()
	label.text = name_
	label.font = load(FONT_TITLE)
	label.font_size = 56
	label.pixel_size = 0.0045
	label.outline_size = 14
	label.modulate = Color(0.98, 0.9, 0.62)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 2.15, 0.0)
	add_child(label)
	_play()


func _play() -> void:
	var len: float = _body.clip_length("Idle_Loop")
	if len > 0.0:
		_body.act("Idle_Loop", 0.0, len, len, 0.2)


func _process(delta: float) -> void:
	if _body == null:
		return
	_clip_t += delta
	if _clip_t >= _body.clip_length("Idle_Loop"):
		_clip_t = 0.0
		_play()
	_body.update_body(delta)
	_body.pose(SwordPoses.make("relaxed"))
	if is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() < NOTICE and to.length() > 0.1:
			look_at(global_position + to, Vector3.UP)
