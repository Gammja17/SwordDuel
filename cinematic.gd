extends Node3D
## An execution, seen from outside. A body stands in for the first-person player (it has
## none of its own) and mirrors the player's sword and grab exactly; the camera cuts to a
## low shot from the side and pushes in as the blade goes home. main.gd starts it when an
## execution begins; it ends itself when the move is over.

signal finished

const BodyScript := preload("res://knight_body.gd")
const PUSH_IN := 0.35    # seconds for the camera to close in once the blade is in

var _player
var _opponent
var _body
var _cam: Camera3D
var _side := 1.0


func start(player: Node3D, opponent: Node3D) -> void:
	_player = player
	_opponent = opponent
	_body = BodyScript.new()
	add_child(_body)
	_body.build(Color(), false, "player")
	_cam = Camera3D.new()
	_cam.near = 0.05
	add_child(_cam)
	_side = _shady_side()
	player.set_first_person_visible(false)
	_follow(0.0)
	_cam.current = true


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if not is_instance_valid(_player) or not _player.in_special():
		_end()
		return
	_follow(delta)


func _follow(delta: float) -> void:
	# The stand-in body: same feet and facing as the player, the same sword, its left
	# hand on the opponent while the player's has hold of them.
	_body.global_transform = _player.global_transform
	var v: Vector3 = _player.global_transform.basis.inverse() * _player.velocity
	_body.move(Vector2(v.x, -v.z))
	_body.update_body(delta)
	var clock: Vector2 = _player.special_clock()   # (time into it, when the blade goes in)
	var lean := 0.25 if clock.x >= clock.y else 0.05
	_body.hold_at(_player.sword.global_transform, 0.0, lean)
	_body.grab(_player.grab_point() if _player.grab_active() else null)

	# The camera: low and side-on to the pair, closing in and narrowing once it strikes,
	# and looking down a little as the opponent sinks.
	var p: Vector3 = _player.global_position
	var o: Vector3 = _opponent.global_position if is_instance_valid(_opponent) else p + Vector3(0, 0, -1)
	var mid := (p + o) * 0.5
	var along := o - p
	along.y = 0.0
	along = along.normalized() if along.length() > 0.01 else Vector3.FORWARD
	var side := along.cross(Vector3.UP).normalized() * _side
	var k := clampf((clock.x - clock.y) / PUSH_IN, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	# Set off toward the opponent's side, so the shot looks at them and the blade going
	# in, past the player's shoulder rather than at the player's back.
	# A little above head height, looking down: more ground, less bright sky.
	var dist := lerpf(2.6, 1.8, k)
	var height := lerpf(1.8, 1.55, k)
	_cam.global_position = mid + side * dist + along * lerpf(0.5, 1.0, k) + Vector3(0.0, height, 0.0)
	_cam.look_at(mid + along * lerpf(0.1, 0.35, k) + Vector3(0.0, lerpf(1.1, 0.85, k), 0.0), Vector3.UP)
	_cam.fov = lerpf(52.0, 42.0, k)


## The side of the pair to film from with the sun behind the camera, not in the shot.
func _shady_side() -> float:
	var sun_dir := Vector3.ZERO
	for l in get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false):
		sun_dir = -(l as DirectionalLight3D).global_transform.basis.z   # the way its light travels
		break
	var along: Vector3 = _opponent.global_position - _player.global_position
	along.y = 0.0
	var side := along.normalized().cross(Vector3.UP)
	# From +side the camera looks along -side: that should run with the light.
	return 1.0 if (-side).dot(sun_dir) >= 0.0 else -1.0


func _end() -> void:
	if is_instance_valid(_player):
		_player.set_first_person_visible(true)
		_player.camera().current = true
	_player = null
	finished.emit()
	queue_free()
