extends Node3D
## 진검승부 — the whole game: a walled courtyard at sunset, three opponents in a row,
## and the cards between them (title, who you face next, how it went).
##
## Flow: TITLE -> INTRO (who you face) -> FIGHT -> OUTCOME (win: next opponent / lose:
## try again) -> ... -> FINAL -> TITLE. Everything is built in code.

const PlayerScript := preload("res://player.gd")
const OpponentScript := preload("res://opponent.gd")
const HudScript := preload("res://hud.gd")
const CombatScript := preload("res://combat.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")

enum Phase { TITLE, INTRO, FIGHT, OUTCOME, FINAL }

const ARENA_HALF := 8.0
const WALL_HEIGHT := 1.3
const WALL_THICK := 0.5
const SKY_HDRI := "res://assets/hdri/sky_1k.hdr"

const TIERS := [
	{
		"kicker": "첫 번째 상대",
		"name": "수련기사 도윤",
		"about": "기사단에 들어온 지 한 해 된 수련기사입니다. 동작이 크고 느려서 칼을 치켜드는 게 잘 보입니다. 치켜든 쪽을 보고, 내려오는 칼을 향해 휘둘러 맞받아 보세요.",
		"hp": 80.0, "windup": 0.55, "attack": 0.26, "recover": 0.7, "stagger": 0.85,
		"poise": Vector2(1.0, 1.8), "attack_prob": 0.6, "lines": ["diag"],
		"feint": 0.0, "combo": 0.0, "punish": 0.15, "riposte": 0.0, "damage": 0.7,
		"guard_track": 4.0, "speed": 2.2,
		"tabard": Color(0.20, 0.30, 0.55), "crest": false,
	},
	{
		"kicker": "두 번째 상대",
		"name": "기사 서혁",
		"about": "좌우로 번갈아 벱니다. 가끔 한쪽으로 치켜들었다가 반대쪽으로 바꿔 베니, 칼이 어느 쪽에서 내려오는지 끝까지 보고 맞받으세요.",
		"hp": 100.0, "windup": 0.42, "attack": 0.22, "recover": 0.55, "stagger": 0.65,
		"poise": Vector2(0.6, 1.3), "attack_prob": 0.7, "lines": ["diag", "horiz"],
		"feint": 0.3, "combo": 0.15, "punish": 0.45, "riposte": 0.35, "damage": 1.0,
		"guard_track": 7.0, "speed": 2.5,
		"tabard": Color(0.55, 0.12, 0.10), "crest": false,
	},
	{
		"kicker": "마지막 상대",
		"name": "검술사범 무진",
		"about": "기사단에 검술을 가르치는 사범입니다. 빠르고, 베기와 찌르기를 섞어 연달아 들어옵니다. 함부로 거리를 좁히면 먼저 칩니다. 한 번 휘두르고 물러나는 틈을 노리세요.",
		"hp": 130.0, "windup": 0.34, "attack": 0.19, "recover": 0.45, "stagger": 0.5,
		"poise": Vector2(0.45, 1.0), "attack_prob": 0.8, "lines": ["diag", "horiz", "thrust"],
		"feint": 0.35, "combo": 0.45, "punish": 0.8, "riposte": 0.6, "damage": 1.15,
		"guard_track": 12.0, "speed": 2.8,
		"tabard": Color(0.10, 0.10, 0.12), "crest": true,
	},
]

var hitstop_enabled := true   # the headless probe turns this off

var _phase: int = Phase.TITLE
var _tier := 0
var _player: CharacterBody3D
var _opponent: CharacterBody3D
var _combat: Node
var _hud
var _title_cam: Camera3D
var _title_angle := 0.8
var _hitstop_until := 0
var _click_ready_at := 0
var _stats := {}
var _totals := {}
var _hints_shown := {}
var _torches: Array[OmniLight3D] = []


func _ready() -> void:
	_register_inputs()
	_build_world()
	_hud = HudScript.new()
	add_child(_hud)
	_title_cam = Camera3D.new()
	_title_cam.fov = 55.0
	add_child(_title_cam)
	Sfx.start_ambience("wind_loop", -12.0)
	_totals = _new_stats()
	_to_title()


func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0

	for i in _torches.size():
		_torches[i].light_energy = 1.3 + sin(Time.get_ticks_msec() * 0.011 + i * 1.7) * 0.12 + randf_range(-0.08, 0.08)

	match _phase:
		Phase.TITLE:
			_title_angle += delta * 0.06
			_title_cam.position = Vector3(sin(_title_angle) * 7.0, 2.3, cos(_title_angle) * 7.0)
			_title_cam.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
		Phase.FIGHT, Phase.OUTCOME:
			if is_instance_valid(_player) and is_instance_valid(_opponent):
				_hud.set_enemy_hp(_opponent.hp / _opponent.max_hp)
				_hud.set_player(_player.hp / 100.0, _player.posture / 100.0, _player.hurt_flash)
				if _phase == Phase.FIGHT:
					_watch_for_hints()


func _input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var key: bool = event is InputEventKey and event.pressed and not event.is_echo() \
		and (event as InputEventKey).physical_keycode in [KEY_SPACE, KEY_ENTER]
	if click or key:
		_advance()


# --- flow ------------------------------------------------------------------------

func _advance() -> void:
	if Time.get_ticks_msec() < _click_ready_at:
		return
	match _phase:
		Phase.TITLE:
			_totals = _new_stats()
			_intro(0)
		Phase.INTRO:
			_start_fight()
		Phase.OUTCOME:
			if _stats.get("won", false):
				if _tier + 1 < TIERS.size():
					_intro(_tier + 1)
				else:
					_final()
			else:
				_intro(_tier)
		Phase.FINAL:
			_to_title()


func _to_title() -> void:
	_phase = Phase.TITLE
	_clear_duel()
	# A knight waiting in the courtyard while the camera circles.
	_opponent = OpponentScript.new()
	add_child(_opponent)
	_opponent.position = Vector3(0.0, 0.0, 0.0)
	_opponent.setup(null, TIERS[0])
	_title_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_fight_ui(false)
	_hud.clear_hint()
	_hud.show_card("1대1 검술 결투", "진검승부",
		"마우스로 칼을 움직입니다. 빠르게 그을수록 깊게 벱니다.\n"
		+ "W · S로 다가서거나 물러나고, A · D로 옆으로 움직입니다.\n"
		+ "상대가 베어 올 때 그 칼을 향해 휘두르면 쳐냅니다. 칼을 대고만 있으면 막기만 되고, 막을수록 자세가 무너집니다.\n"
		+ "세 사람을 차례로 이기면 끝납니다.",
		"클릭하면 시작합니다")
	_click_ready_at = Time.get_ticks_msec() + 300


func _intro(tier: int) -> void:
	_tier = tier
	_phase = Phase.INTRO
	_spawn_duel(tier)
	var t: Dictionary = TIERS[tier]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_fight_ui(false)
	_hud.clear_hint()
	_hud.show_card(t["kicker"], t["name"], t["about"], "클릭하면 겨룹니다")
	_click_ready_at = Time.get_ticks_msec() + 400


func _start_fight() -> void:
	_phase = Phase.FIGHT
	_hud.hide_card()
	_hud.show_fight_ui(true)
	_hud.set_enemy(_opponent.display_name)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.active = true
	_opponent.begin()
	Sfx.play_flat("draw", -2.0)
	if _tier == 0:
		_hint_once("start", "W로 한 걸음 다가서야 칼이 닿습니다. 상대가 칼을 치켜들면 그쪽을 잘 보세요.")


func _on_opponent_died() -> void:
	_stats["won"] = true
	_player.active = false
	get_tree().create_timer(1.6).timeout.connect(_outcome)


func _on_player_died() -> void:
	_stats["won"] = false
	get_tree().create_timer(1.8).timeout.connect(_outcome)


func _outcome() -> void:
	if _phase != Phase.FIGHT:
		return
	_phase = Phase.OUTCOME
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.clear_hint()
	for k in ["parries", "blocks", "cuts", "hits"]:
		_totals[k] += _stats[k]
	var t: Dictionary = TIERS[_tier]
	var name_: String = t["name"]
	if _stats["won"]:
		var last := _tier + 1 >= TIERS.size()
		_hud.show_card("승리", name_, name_ + _obj_particle(name_) + " 쓰러뜨렸습니다.\n\n" + _stats_line(_stats),
			"클릭하면 결과를 봅니다" if last else "클릭하면 다음 상대로 넘어갑니다")
	else:
		_hud.show_card("패배", name_, name_ + "에게 쓰러졌습니다.\n\n" + _stats_line(_stats) + "\n\n" + _advice(),
			"클릭하면 다시 겨룹니다")
	_click_ready_at = Time.get_ticks_msec() + 700


func _final() -> void:
	_phase = Phase.FINAL
	_hud.show_fight_ui(false)
	_hud.show_card("진검승부", "완승", "세 사람을 모두 이겼습니다.\n\n" + _stats_line(_totals),
		"클릭하면 처음 화면으로 돌아갑니다")
	_click_ready_at = Time.get_ticks_msec() + 700


## What to try next, based on how the lost duel went.
func _advice() -> String:
	if _stats["blocks"] > _stats["parries"] * 2 and _stats["blocks"] >= 3:
		return "막기만 하면 자세가 무너집니다. 내려오는 칼에 맞춰 휘둘러 쳐내 보세요."
	if _stats["parries"] == 0:
		return "상대가 칼을 치켜들면, 그 칼이 내려올 쪽으로 칼을 휘둘러 맞받으세요."
	if _stats["cuts"] == 0:
		return "쳐낸 뒤 상대가 흔들릴 때 W로 다가가 베세요."
	return "상대가 한 번 휘두르고 물러날 때 따라 들어가 베세요."


func _spawn_duel(tier: int) -> void:
	_clear_duel()
	_stats = _new_stats()

	_player = PlayerScript.new()
	_player.name = "Player"
	add_child(_player)
	_player.position = Vector3(0.0, 0.0, 2.0)

	_opponent = OpponentScript.new()
	_opponent.name = "Opponent"
	add_child(_opponent)
	_opponent.position = Vector3(0.0, 0.0, -2.0)
	_opponent.setup(_player, TIERS[tier])
	_player.target = _opponent

	_combat = CombatScript.new()
	_combat.player = _player
	_combat.opponent = _opponent
	add_child(_combat)

	_player.camera().current = true
	_player.sword.cut_registered.connect(_on_cut)
	_player.sword.clash_registered.connect(_on_clash)
	_player.hurt.connect(_on_player_hurt)
	_player.died.connect(_on_player_died)
	_opponent.died.connect(_on_opponent_died)


func _clear_duel() -> void:
	Engine.time_scale = 1.0
	for n in [_player, _opponent, _combat]:
		if is_instance_valid(n):
			n.queue_free()
	_player = null
	_opponent = null
	_combat = null


## Headless probe entry: straight into a fight, no cards.
func debug_start(tier: int) -> void:
	_intro(tier)
	_start_fight()


# --- combat feedback ------------------------------------------------------------------

func _on_clash(_pos: Vector3, result: String) -> void:
	match result:
		"PARRY!":
			_stats["parries"] += 1
			_hud.popup("쳐내기!", Color(0.98, 0.82, 0.35))
			_hitstop(0.09)
			if _tier == 0:
				_hint_once("parry", "쳐냈습니다! 상대가 흔들리는 동안 다가가 베세요.")
		"BLOCKED":
			_stats["blocks"] += 1
			_hud.popup("막음", Color(0.8, 0.8, 0.78))
			_hitstop(0.05)
			if _tier == 0:
				_hint_once("block", "칼을 대고만 있으면 막기입니다. 막을 때마다 아래쪽 자세 게이지가 찹니다.")
		"GUARD BROKEN":
			_stats["blocks"] += 1
			_hud.popup("자세 무너짐!", Color(0.95, 0.35, 0.25))
			_hitstop(0.08)
			_hint_once("broken", "자세가 무너졌습니다. S로 물러나 거리를 벌리세요.")
		_:
			_hud.popup("챙!", Color(0.95, 0.95, 0.92))
			_hitstop(0.04)


func _on_cut(strength: float, _pos: Vector3) -> void:
	_stats["cuts"] += 1
	_hitstop(0.07)
	if strength > 12.0:
		_hud.popup("깊게 베었다!", Color(0.95, 0.45, 0.35))
	if _tier == 0:
		_hint_once("cut", "베었습니다! 더 빠르게 그을수록 더 깊이 들어갑니다.")


func _on_player_hurt(_amount: float) -> void:
	_stats["hits"] += 1
	_hitstop(0.08)
	if _tier == 0 and _stats["parries"] == 0:
		_hint_once("hurt", "맞았습니다. 상대가 칼을 치켜들면 S로 물러나거나, 내려오는 칼을 향해 휘둘러 맞받으세요.")


func _watch_for_hints() -> void:
	if _tier != 0:
		return
	if _opponent.is_attacking():
		_hint_once("windup", "상대가 칼을 치켜들었습니다. 내려오는 칼을 향해 마우스를 휘둘러 맞받으세요!")
	if _player.sword.is_binding():
		_hint_once("bind", "칼이 맞물렸습니다. 마우스를 계속 밀어붙이면 상대 칼을 걷어냅니다.")


func _hint_once(key: String, text: String) -> void:
	if _hints_shown.has(key):
		return
	_hints_shown[key] = true
	_hud.hint(text)


func _hitstop(seconds: float) -> void:
	if not hitstop_enabled:
		return
	Engine.time_scale = 0.05
	_hitstop_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func _new_stats() -> Dictionary:
	return {"parries": 0, "blocks": 0, "cuts": 0, "hits": 0, "won": false}


func _stats_line(s: Dictionary) -> String:
	return "쳐내기 %d번 · 막기 %d번 · 벤 횟수 %d번 · 맞은 횟수 %d번" % [s["parries"], s["blocks"], s["cuts"], s["hits"]]


## 을/를 depending on whether the last syllable ends in a consonant (받침).
func _obj_particle(word: String) -> String:
	if word.is_empty():
		return "를"
	var code := word.unicode_at(word.length() - 1)
	if code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0:
		return "을"
	return "를"


# --- input actions (registered in code so we don't hand-edit project.godot) ---------

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


# --- the courtyard ---------------------------------------------------------------------

func _build_world() -> void:
	# Ground: one big paved plane (the courtyard and beyond the low walls).
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var gm := PlaneMesh.new()
	gm.size = Vector2(80.0, 80.0)
	Armor.part(ground, gm, Armor.floor_stone())
	var gcol := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(80.0, 0.2, 80.0)
	gcol.shape = gbox
	gcol.position = Vector3(0.0, -0.1, 0.0)
	ground.add_child(gcol)
	add_child(ground)

	# Walls: without them a retreating opponent walks the fight off the edge; with them,
	# pinning someone against the wall becomes part of the duel.
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var size: Vector3
		if side.z != 0.0:
			size = Vector3(ARENA_HALF * 2.0 + WALL_THICK, WALL_HEIGHT, WALL_THICK)
		else:
			size = Vector3(WALL_THICK, WALL_HEIGHT, ARENA_HALF * 2.0 + WALL_THICK)
		_solid_box(side * ARENA_HALF + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0), size, Armor.wall_stone())
		# Coping stones along the top.
		Armor.part(self, Armor.box(Vector3(size.x + 0.08, 0.1, size.z + 0.08)), Armor.wall_stone(),
			side * ARENA_HALF + Vector3(0.0, WALL_HEIGHT + 0.05, 0.0))

	# Corner pillars with torches.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var base := Vector3(cx * ARENA_HALF, 0.0, cz * ARENA_HALF)
			_solid_box(base + Vector3(0.0, 1.4, 0.0), Vector3(0.9, 2.8, 0.9), Armor.wall_stone())
			Armor.part(self, Armor.box(Vector3(1.05, 0.18, 1.05)), Armor.wall_stone(), base + Vector3(0.0, 2.89, 0.0))
			_torch(base + Vector3(-cx * 0.62, 2.2, -cz * 0.62))

	# Banners on the side walls, hung from wooden poles.
	for bx in [-1.0, 1.0]:
		for bz in [-3.0, 3.0]:
			var color := Color(0.50, 0.08, 0.07) if bz < 0.0 else Color(0.12, 0.18, 0.40)
			var at := Vector3(bx * (ARENA_HALF - 0.3), 0.0, bz)
			Armor.part(self, Armor.cylinder(0.035, 0.035, 2.9), Armor.wood(), at + Vector3(0.0, 1.45, 0.0))
			var banner := Armor.part(self, Armor.box(Vector3(0.03, 1.5, 0.8)), Armor.cloth(color), at + Vector3(-bx * 0.03, 2.0, 0.0))
			banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			Armor.part(self, Armor.cylinder(0.025, 0.025, 0.95), Armor.wood(), at + Vector3(-bx * 0.03, 2.77, 0.0)).rotation_degrees = Vector3(90, 0, 0)

	_weapon_rack(Vector3(6.6, 0.0, -6.6), deg_to_rad(45.0))
	_weapon_rack(Vector3(-6.6, 0.0, 6.6), deg_to_rad(-135.0))

	# Low sun from the side, sky and ambient from the HDRI.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, 128.0, 0.0)
	sun.light_color = Color(1.0, 0.80, 0.60)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)

	var env := Environment.new()
	var sky := Sky.new()
	if ResourceLoader.exists(SKY_HDRI):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(SKY_HDRI)
		sky.sky_material = pano
	else:
		sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.55, 0.50)
	env.fog_density = 0.008
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _solid_box(center: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	Armor.part(body, Armor.box(size), mat)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _torch(pos: Vector3) -> void:
	Armor.part(self, Armor.cylinder(0.04, 0.03, 0.45), Armor.wood(), pos)
	var flame := CPUParticles3D.new()
	flame.amount = 24
	flame.lifetime = 0.6
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.initial_velocity_min = 0.3
	flame.initial_velocity_max = 0.7
	flame.gravity = Vector3(0.0, 0.6, 0.0)
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.0
	var q := SphereMesh.new()
	q.radius = 0.05
	q.height = 0.1
	q.radial_segments = 6
	q.rings = 3
	flame.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame.material_override = fm
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	flame.color_ramp = ramp
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = pos + Vector3(0.0, 0.28, 0.0)
	add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.3
	light.omni_range = 7.0
	light.position = pos + Vector3(0.0, 0.45, 0.0)
	add_child(light)
	_torches.append(light)


func _weapon_rack(pos: Vector3, yaw: float) -> void:
	var rack := Node3D.new()
	rack.position = pos
	rack.rotation.y = yaw
	add_child(rack)
	for x in [-0.55, 0.55]:
		Armor.part(rack, Armor.box(Vector3(0.07, 1.1, 0.07)), Armor.wood(), Vector3(x, 0.55, 0.0))
	Armor.part(rack, Armor.box(Vector3(1.2, 0.06, 0.08)), Armor.wood(), Vector3(0.0, 1.0, 0.0))
	Armor.part(rack, Armor.box(Vector3(1.2, 0.06, 0.22)), Armor.wood(), Vector3(0.0, 0.08, 0.05))
	for i in 3:
		var s := SwordMesh.build(Armor.blade(), Armor.dark_steel(), Armor.leather())
		rack.add_child(s)
		# Resting point-up against the top rail, pommel on the bottom board.
		s.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-80.0), 0.0, 0.0)), Vector3(-0.3 + i * 0.3, 0.33, 0.1))
