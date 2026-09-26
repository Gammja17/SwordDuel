extends Node3D
## MVP-2 arena: floor, light, the player, a reactive AI opponent, HP bars and a HUD.
## Everything is built in code so the whole prototype lives in a few scripts; once the
## feel is settled we can split Player/Sword/Opponent into their own scenes.

const PlayerScript := preload("res://player.gd")
const OpponentScript := preload("res://opponent.gd")

var _player: CharacterBody3D
var _opponent: CharacterBody3D

var _speed_label: Label
var _cut_label: Label
var _status_label: Label
var _result_label: Label
var _player_hp_fill: ColorRect
var _opp_hp_fill: ColorRect
var _hurt_overlay: ColorRect

const HP_BAR_W := 280.0
const ARENA_HALF := 8.0    # walled arena is 16 x 16 m
const WALL_THICK := 0.4
const WALL_HEIGHT := 1.0
var _posture_fill: ColorRect
var _clash_flash := 0.0
var _clash_text := ""
var _over := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running (for R to reset) while paused
	_register_inputs()
	_build_environment()

	_player = PlayerScript.new()
	_player.name = "Player"
	add_child(_player)

	_opponent = OpponentScript.new()
	_opponent.name = "Opponent"
	_opponent.position = Vector3(0.0, 0.0, -3.2)
	add_child(_opponent)
	_opponent.setup(_player)
	_player.target = _opponent

	_build_hud()
	_player.sword.cut_registered.connect(_on_cut)
	_player.sword.clash_registered.connect(_on_clash)


func _process(delta: float) -> void:
	if not (_player and _player.sword):
		return

	_speed_label.text = "Tip speed: %5.1f m/s" % _player.sword.get_tip_speed()
	_player_hp_fill.size.x = HP_BAR_W * (_player.hp / 100.0)
	_opp_hp_fill.size.x = HP_BAR_W * (_opponent.hp / 100.0)
	_posture_fill.size.x = HP_BAR_W * (_player.posture / 100.0)
	_hurt_overlay.color.a = _player.hurt_flash * 0.35

	if _clash_flash > 0.0:
		_clash_flash -= delta
	if _clash_flash > 0.0:
		_status_label.text = _clash_text
	elif _player.sword.is_binding():
		_status_label.text = "BIND  —  push into it to force the guard aside"
	else:
		_status_label.text = ""

	if not _over and (_player.hp <= 0.0 or _opponent.hp <= 0.0):
		_over = true
		var won: bool = _opponent.hp <= 0.0
		_result_label.text = ("YOU WIN" if won else "YOU DIED") + "\npress R to reset"
		_result_label.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # the player (paused) can't release it
		get_tree().paused = true


func _input(event: InputEvent) -> void:
	if _over and event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()


# --- input actions (registered in code so we don't hand-edit project.godot) ---
func _register_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)


func _add_key_action(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


# --- world ---
func _build_environment() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.17, 0.18, 0.21)
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30.0, 0.2, 30.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(floor_col)
	add_child(floor_body)

	# Arena walls. Without them a retreating opponent walks the fight off the floor
	# edge; with them, pinning someone against the wall becomes part of the duel.
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.34, 0.31, 0.28)
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var size: Vector3
		if side.z != 0.0:
			size = Vector3(ARENA_HALF * 2.0 + WALL_THICK, WALL_HEIGHT, WALL_THICK)
		else:
			size = Vector3(WALL_THICK, WALL_HEIGHT, ARENA_HALF * 2.0 + WALL_THICK)
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = side * ARENA_HALF + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0)
		var wall_mesh := MeshInstance3D.new()
		var wall_bm := BoxMesh.new()
		wall_bm.size = size
		wall_mesh.mesh = wall_bm
		wall_mesh.material_override = wall_mat
		wall.add_child(wall_mesh)
		var wall_col := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = size
		wall_col.shape = wall_box
		wall.add_child(wall_col)
		add_child(wall)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -40.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.33, 0.40)
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)


# --- HUD (English text: the built-in font has no Hangul glyphs; add a Korean font
#     later if we want Korean on screen) ---
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hurt_overlay = ColorRect.new()
	_hurt_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	_hurt_overlay.anchor_right = 1.0
	_hurt_overlay.anchor_bottom = 1.0
	_hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hurt_overlay)

	var info := Label.new()
	info.text = "WASD move (locked on)    |    Mouse = swing    |    swing INTO an attack = PARRY, just holding = BLOCK (fills GUARD)    |    click to grab the mouse, ESC frees it"
	info.position = Vector2(16.0, 12.0)
	layer.add_child(info)

	_speed_label = Label.new()
	_speed_label.position = Vector2(16.0, 40.0)
	_speed_label.text = "Tip speed: 0.0 m/s"
	layer.add_child(_speed_label)

	_cut_label = Label.new()
	_cut_label.position = Vector2(16.0, 64.0)
	_cut_label.text = "Last cut: -"
	layer.add_child(_cut_label)

	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 96.0)
	_status_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_status_label)

	_player_hp_fill = _build_hp_bar(layer, Vector2(16.0, 140.0), Color(0.35, 0.7, 0.95), "YOU")
	_posture_fill = _build_posture_bar(layer, Vector2(16.0, 164.0))
	_opp_hp_fill = _build_hp_bar(layer, Vector2(16.0, 204.0), Color(0.95, 0.4, 0.35), "FOE")

	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 48)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.anchor_left = 0.5
	_result_label.anchor_top = 0.4
	_result_label.position = Vector2(-160.0, 0.0)
	_result_label.custom_minimum_size = Vector2(320.0, 0.0)
	_result_label.visible = false
	layer.add_child(_result_label)


func _build_hp_bar(parent: Node, pos: Vector2, color: Color, tag: String) -> ColorRect:
	var label := Label.new()
	label.text = tag
	label.position = pos + Vector2(-2.0, -20.0)
	parent.add_child(label)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.8)
	bg.position = pos
	bg.size = Vector2(HP_BAR_W, 20.0)
	parent.add_child(bg)

	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos
	fill.size = Vector2(HP_BAR_W, 20.0)
	parent.add_child(fill)
	return fill


## Thin guard (posture) bar under our HP: fills as we block, breaks the guard when full.
func _build_posture_bar(parent: Node, pos: Vector2) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.8)
	bg.position = pos
	bg.size = Vector2(HP_BAR_W, 8.0)
	parent.add_child(bg)

	var fill := ColorRect.new()
	fill.color = Color(0.95, 0.78, 0.25)
	fill.position = pos
	fill.size = Vector2(0.0, 8.0)
	parent.add_child(fill)

	var label := Label.new()
	label.text = "GUARD"
	label.position = pos + Vector2(HP_BAR_W + 8.0, -8.0)
	parent.add_child(label)
	return fill


func _on_cut(strength: float, _pos: Vector3) -> void:
	_cut_label.text = "Last cut: %.1f  (%s)" % [strength, _rate(strength)]


func _on_clash(_pos: Vector3, result: String) -> void:
	_clash_text = result
	_clash_flash = 0.45


func _rate(s: float) -> String:
	if s > 12.0:
		return "DEEP!"
	elif s > 6.0:
		return "clean cut"
	return "graze"
