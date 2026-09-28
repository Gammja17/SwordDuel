extends Node3D
## 진검승부: a walled courtyard at sunset, three opponents in a row, and the cards
## between them.
##
## Flow: TITLE -> (first time: PRACTICE, a hands-on drill with the squire) -> INTRO
## (who you face) -> FIGHT -> OUTCOME (win: next opponent / lose: try again) -> ...
## -> FINAL -> TITLE. Everything is built in code.

const PlayerScript := preload("res://player.gd")
const OpponentScript := preload("res://opponent.gd")
const HudScript := preload("res://hud.gd")
const CombatScript := preload("res://combat.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")

enum Phase { TITLE, INTRO, FIGHT, OUTCOME, FINAL, PRACTICE, PRACTICE_DONE }

const ARENA_HALF := 8.0
const WALL_HEIGHT := 1.3
const WALL_THICK := 0.5
const SKY_HDRI := "res://assets/hdri/sky_1k.hdr"
const SAVE_PATH := "user://progress.cfg"
const GOLD := Color(0.98, 0.82, 0.35)
const RED := Color(0.95, 0.35, 0.25)

const TIERS := [
	{
		"kicker": "첫 번째 상대",
		"name": "수련기사 도윤",
		"about": "기사단에 들어온 지 한 해 된 수련기사입니다. 동작이 크고 느려서 칼을 치켜드는 게 잘 보입니다.",
		"hp": 70.0, "windup": 0.55, "attack": 0.26, "recover": 0.7, "stagger": 0.85,
		"poise": Vector2(1.0, 1.8), "attack_prob": 0.6, "lines": ["c"], "dodge": 0.0, "parry_window": 0.25, "windup_jitter": 0.0,
		"feint": 0.0, "combo": 0.0, "punish": 0.15, "riposte": 0.0, "damage": 0.5,
		"armor": 0.5, "flinch_speed": 6.0,
		"parry": 0.1, "bind_press": 0.25, "bind_strength": 0.5, "bind_switch": Vector2(2.2, 3.2), "exit_cut": 0.2,
		"guard_track": 4.0, "speed": 2.2,
		"tabard": Color(0.20, 0.30, 0.55), "crest": false,
	},
	{
		"kicker": "두 번째 상대",
		"name": "기사 서혁",
		"about": "좌우로 번갈아 베고, 가끔 치켜든 쪽을 바꿔 속입니다. 함부로 휘두르면 받아칩니다.",
		"hp": 90.0, "windup": 0.46, "attack": 0.23, "recover": 0.6, "stagger": 0.7,
		"poise": Vector2(0.6, 1.3), "attack_prob": 0.7, "lines": ["a", "b", "c"], "dodge": 0.15, "parry_window": 0.18, "windup_jitter": 0.15,
		"feint": 0.25, "combo": 0.15, "punish": 0.4, "riposte": 0.3, "damage": 0.65,
		"armor": 2.0, "flinch_speed": 9.0,
		"parry": 0.3, "bind_press": 0.35, "bind_strength": 0.6, "bind_switch": Vector2(1.7, 2.7), "exit_cut": 0.45,
		"guard_track": 7.0, "speed": 2.5,
		"tabard": Color(0.55, 0.12, 0.10), "crest": false,
	},
	{
		"kicker": "마지막 상대",
		"name": "검술사범 무진",
		"about": "기사단에 검술을 가르치는 사범입니다. 빠르고, 달려들며 베기와 연속 베기를 섞습니다. 칼이 맞물리면 힘이 셉니다.",
		"hp": 120.0, "windup": 0.36, "attack": 0.19, "recover": 0.45, "stagger": 0.55,
		"poise": Vector2(0.45, 1.0), "attack_prob": 0.8, "lines": ["a", "b", "c", "lunge"], "dodge": 0.25, "parry_window": 0.14, "windup_jitter": 0.3,
		"feint": 0.35, "combo": 0.35, "punish": 0.7, "riposte": 0.5, "damage": 0.85,
		"armor": 3.0, "flinch_speed": 11.0,
		"parry": 0.55, "bind_press": 0.5, "bind_strength": 0.8, "bind_switch": Vector2(1.3, 2.2), "exit_cut": 0.7,
		"guard_track": 12.0, "speed": 2.8,
		"tabard": Color(0.10, 0.10, 0.12), "crest": true,
	},
]

# The squire as a patient sparring partner: slow, harmless, never parries or feints.
const PRACTICE_TIER := {
	"name": "수련기사 도윤", "hp": 99999.0, "windup": 0.9, "attack": 0.34, "recover": 0.9, "stagger": 0.9,
	"poise": Vector2(1.2, 1.8), "attack_prob": 1.0, "lines": ["c"], "parry_window": 0.3,
	"feint": 0.0, "combo": 0.0, "punish": 0.0, "riposte": 0.0, "damage": 0.0,
	"armor": 0.0, "flinch_speed": 3.0,
	"parry": 0.0, "bind_press": 0.0, "bind_strength": 0.4, "bind_switch": Vector2(1.8, 2.6), "exit_cut": 0.0,
	"guard_track": 3.0, "speed": 2.0,
	"tabard": Color(0.20, 0.30, 0.55), "crest": false,
}
const PRACTICE_STEPS := [
	{"id": "swing", "drill": "idle", "task": "마우스를 크게 휘둘러 보세요"},
	{"id": "cut", "drill": "open", "task": "W로 다가가서 베어 보세요"},
	{"id": "parry", "drill": "attack", "task": "내려오는 칼을 향해 휘두르거나\n닿기 직전에 우클릭해서 쳐내세요"},
	{"id": "dodge", "drill": "attack", "task": "칼이 내려오면 스페이스로 피하세요"},
	{"id": "bind", "drill": "bind", "task": "칼이 맞물리면 화살표 쪽으로 마우스를 미세요"},
]

var hitstop_enabled := true   # the headless probe turns this off
var auto_pause := true        # losing the mouse mid-fight opens the settings (off in headless tests)

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
var _practice_done := false
var _practice_step := -1
var _step_done_at := 0
var _rebind_at := 0
var _visibility_cb: JavaScriptObject
var _menu_open := false
var _captured_at := 0
var _volumes := {"Master": 0.5, "SFX": 0.8, "Ambience": 0.5}


func _ready() -> void:
	_register_inputs()
	_load_progress()
	_build_world()
	_hud = HudScript.new()
	add_child(_hud)
	_hud.settings_requested.connect(func(): _open_menu(false))
	_hud.settings_closed.connect(_close_menu)
	_hud.volume_changed.connect(_on_volume_changed)
	for bus in _volumes:
		Sfx.set_volume(bus, _volumes[bus])
	_title_cam = Camera3D.new()
	_title_cam.fov = 55.0
	add_child(_title_cam)
	Sfx.start_ambience("wind_loop", -12.0)
	_setup_web()
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
		Phase.FIGHT, Phase.OUTCOME, Phase.PRACTICE:
			if is_instance_valid(_player) and is_instance_valid(_opponent):
				_hud.set_enemy_hp(_opponent.hp / _opponent.max_hp)
				_hud.set_player(_player.hp / 100.0, _player.posture / 100.0, _player.hurt_flash, _player.breath / 100.0)
				if is_instance_valid(_combat) and _combat.is_bound():
					var b: Dictionary = _combat.bind
					_hud.show_bind(b.a, -float(b.ai_dir), b.tell > 0.0)
				else:
					_hud.hide_bind()
				if _phase == Phase.PRACTICE:
					_run_practice()
				# ESC (or the browser dropping the mouse lock) mid-fight opens the settings.
				if auto_pause and _player.active and not _menu_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
						and Time.get_ticks_msec() - _captured_at > 400:
					_open_menu(true)


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		return
	var click: bool = event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var key: bool = event is InputEventKey and event.pressed and not event.is_echo() \
		and (event as InputEventKey).physical_keycode in [KEY_SPACE, KEY_ENTER]
	if _phase == Phase.TITLE and event is InputEventKey and event.pressed \
			and (event as InputEventKey).physical_keycode == KEY_P:
		_start_practice()
		return
	if click or key:
		_advance()


# --- flow ------------------------------------------------------------------------

func _advance() -> void:
	if Time.get_ticks_msec() < _click_ready_at:
		return
	match _phase:
		Phase.TITLE:
			_totals = _new_stats()
			if _practice_done:
				_intro(0)
			else:
				_start_practice()
		Phase.PRACTICE_DONE:
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
	_opponent.setup(null, TIERS[0])
	_title_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_fight_ui(false)
	_hud.clear_hint()
	_hud.clear_task()
	_hud.hide_bind()
	_hud.show_card("1대1 검술 결투", "진검승부",
		"마우스로 칼을 휘둘러 싸웁니다.\nW 다가서기, S 물러나기, A와 D 옆걸음\n스페이스 회피, 우클릭 막기와 쳐내기\n휠 클릭 락온 켜고 끄기\n세 사람을 차례로 이기면 끝납니다.",
		"클릭하면 시작합니다\nP를 누르면 연습을 다시 합니다" if _practice_done else "클릭하면 연습부터 시작합니다")
	_click_ready_at = Time.get_ticks_msec() + 300
	_set_fps()


func _intro(tier: int) -> void:
	_tier = tier
	_phase = Phase.INTRO
	_spawn_duel(TIERS[tier])
	var t: Dictionary = TIERS[tier]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_fight_ui(false)
	_hud.clear_hint()
	_hud.clear_task()
	_hud.show_card(t["kicker"], t["name"], t["about"], "클릭하면 겨룹니다")
	_click_ready_at = Time.get_ticks_msec() + 400
	_set_fps()


func _start_fight() -> void:
	_phase = Phase.FIGHT
	_hud.hide_card()
	_hud.show_fight_ui(true)
	_hud.set_enemy(_opponent.display_name)
	_capture_mouse()
	_player.active = true
	_opponent.begin()
	Sfx.play_flat("draw", -2.0)
	_set_fps()


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
	_hud.hide_bind()
	for k in ["parries", "blocks", "cuts", "hits", "binds_won", "binds_lost", "parried_me"]:
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
	_set_fps()


func _final() -> void:
	_phase = Phase.FINAL
	_hud.show_fight_ui(false)
	_hud.show_card("진검승부", "완승", "세 사람을 모두 이겼습니다.\n\n" + _stats_line(_totals),
		"클릭하면 처음 화면으로 돌아갑니다")
	_click_ready_at = Time.get_ticks_msec() + 700
	_set_fps()


## What to try next, based on how the lost duel went.
func _advice() -> String:
	if _stats["blocks"] > _stats["parries"] * 2 and _stats["blocks"] >= 3:
		return "막기만 하면 자세가 무너집니다. 내려오는 칼을 향해 휘둘러 쳐내 보세요."
	if _stats["parried_me"] >= 3:
		return "막 휘두르면 상대가 받아칩니다. 쳐낸 뒤나 상대가 물러날 때 베세요."
	if _stats["binds_lost"] >= 2:
		return "힘싸움에서는 화살표 쪽으로 계속 미세요. 화살표가 바뀌면 바로 따라 바꾸세요."
	if _stats["parries"] == 0:
		return "상대가 칼을 치켜들면 그 칼이 내려올 쪽으로 휘둘러 맞받으세요."
	if _stats["cuts"] == 0:
		return "쳐낸 뒤 상대가 흔들릴 때 W로 다가가 베세요."
	return "상대가 한 번 휘두르고 물러날 때 따라 들어가 베세요."


func _spawn_duel(tier: Dictionary) -> void:
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
	_opponent.setup(_player, tier)
	_player.target = _opponent

	_combat = CombatScript.new()
	_combat.player = _player
	_combat.opponent = _opponent
	_combat.tier = tier
	add_child(_combat)
	_combat.bind_ended.connect(_on_bind_ended)

	_player.camera().current = true
	_player.sword.cut_registered.connect(_on_cut)
	_player.sword.clash_registered.connect(_on_clash)
	_player.sword.weak_touch.connect(_on_weak_touch)
	_player.hurt.connect(_on_player_hurt)
	_player.lock_changed.connect(_on_lock_changed)
	_player.died.connect(_on_player_died)
	_opponent.died.connect(_on_opponent_died)
	_opponent.attack_whiffed.connect(_on_attack_whiffed)


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


# --- hands-on practice ----------------------------------------------------------------

func _start_practice() -> void:
	_phase = Phase.PRACTICE
	_spawn_duel(PRACTICE_TIER)
	_player.practice = true
	_player.active = true
	_hud.hide_card()
	_hud.show_fight_ui(true, false)
	_capture_mouse()
	Sfx.play_flat("draw", -2.0)
	_set_practice_step(0)
	_set_fps()


func _set_practice_step(i: int) -> void:
	_practice_step = i
	_step_done_at = 0
	_rebind_at = 0
	var st: Dictionary = PRACTICE_STEPS[i]
	_opponent.set_drill(st["drill"])
	_combat.set("allow_binds", st["drill"] == "bind")
	_hud.task("연습 %d/%d\n%s" % [i + 1, PRACTICE_STEPS.size(), st["task"]])


func _step_id() -> String:
	if _phase != Phase.PRACTICE or _practice_step < 0:
		return ""
	return PRACTICE_STEPS[_practice_step]["id"]


func _practice_success() -> void:
	if _step_done_at > 0:
		return
	_hud.popup("좋아요!", GOLD)
	_step_done_at = Time.get_ticks_msec() + 900


func _run_practice() -> void:
	var now := Time.get_ticks_msec()
	if _step_done_at > 0 and now >= _step_done_at:
		if _practice_step + 1 < PRACTICE_STEPS.size():
			_set_practice_step(_practice_step + 1)
		else:
			_finish_practice()
		return
	var sword = _player.sword
	match _step_id():
		"swing":
			if sword.can_cut():
				_practice_success()
			elif sword.swing_speed >= 3.0:
				_hint_once("p_bigger", "더 크게 휘둘러 보세요")
		"bind":
			var dist: float = _opponent.call("_horizontal_dist", _player.global_position)
			if not _combat.is_bound() and now >= _rebind_at and dist < 2.4 and _step_done_at == 0:
				_combat.begin_bind((sword.base + sword.tip + _opponent.blade_base + _opponent.blade_tip) * 0.25)


func _finish_practice() -> void:
	_practice_done = true
	_save_progress()
	_phase = Phase.PRACTICE_DONE
	_player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.clear_task()
	_hud.clear_hint()
	_hud.hide_bind()
	_hud.show_fight_ui(false)
	_hud.show_card("연습 끝", "잘했어요",
		"이제 진짜로 겨룹니다.\n연습은 처음 화면에서 P를 누르면 다시 할 수 있어요.",
		"클릭하면 첫 상대를 만납니다")
	_click_ready_at = Time.get_ticks_msec() + 500
	_set_fps()


# --- combat feedback ------------------------------------------------------------------

func _on_clash(_pos: Vector3, result: String) -> void:
	match result:
		"PARRY!":
			_stats["parries"] += 1
			_hud.popup("쳐내기!", GOLD)
			_hitstop(0.09)
			if _step_id() == "parry":
				_practice_success()
		"PARRIED":
			_stats["parried_me"] += 1
			_hud.popup("상대가 쳐냈다!", RED)
			_hitstop(0.07)
		"BLOCKED":
			_stats["blocks"] += 1
			_hud.popup("막음", Color(0.8, 0.8, 0.78))
			_hitstop(0.05)
			if _step_id() == "parry":
				_hud.hint("막기만 했어요. 칼을 향해 휘두르거나 더 늦게 우클릭하세요", 3.0)
		"GUARD BROKEN":
			_stats["blocks"] += 1
			_hud.popup("자세 무너짐!", RED)
			_hitstop(0.08)
			_hint_once("broken", "자세가 무너졌어요. S로 물러나세요")
		_:
			_hud.popup("챙!", Color(0.95, 0.95, 0.92))
			_hitstop(0.04)


func _on_cut(strength: float, _pos: Vector3) -> void:
	_stats["cuts"] += 1
	_player.add_trauma(0.14)   # the blow jolts back through the hands
	var armor := float(_opponent.tier_value("armor", 1.5)) if is_instance_valid(_opponent) else 0.0
	if strength - armor < 3.5:
		_hud.popup("얕다", Color(0.75, 0.75, 0.72))   # the plate took it
		_hitstop(0.03)
	elif strength - armor > 9.0:
		_hud.popup("깊게 베었다!", Color(0.95, 0.45, 0.35))
		_hitstop(0.09)
	else:
		_hitstop(0.07)
	if _step_id() == "cut":
		_practice_success()


func _on_weak_touch(_pos: Vector3) -> void:
	_hud.popup("약하다", Color(0.75, 0.75, 0.72))
	if _step_id() == "cut":
		_hint_once("p_weak", "닿기만 했어요. 더 크고 빠르게 휘두르세요")


func _on_player_hurt(_amount: float) -> void:
	_stats["hits"] += 1
	_hitstop(0.08)
	if _step_id() == "parry":
		_hud.hint("맞았어요. 칼을 치켜든 쪽을 보세요", 3.0)
	elif _step_id() == "dodge":
		_hud.hint("맞았어요. 칼이 내려오기 직전에 스페이스를 누르세요", 3.0)


func _on_lock_changed(locked: bool) -> void:
	_hud.hint("락온 켬" if locked else "락온 끔\n칼을 화면 끝까지 밀면 몸이 돌아갑니다", 2.5)


func _on_attack_whiffed() -> void:
	if _step_id() == "dodge" and _player.dodged_within(900):
		_practice_success()


func _on_bind_ended(result: String) -> void:
	match result:
		"won":
			_stats["binds_won"] += 1
			_hud.popup("걷어냈다!", GOLD)
			_hitstop(0.08)
			if _step_id() == "bind":
				_practice_success()
		"lost":
			_stats["binds_lost"] += 1
			_hud.popup("밀렸다!", RED)
			_hitstop(0.06)
			if _phase == Phase.PRACTICE:
				_hud.hint("밀렸어요. 화살표 쪽으로 계속 미세요", 3.0)
		"pulled_out":
			if _phase == Phase.PRACTICE:
				_hud.hint("S를 누르면 칼을 뺍니다. 다시 해 봐요", 3.0)
	_rebind_at = Time.get_ticks_msec() + 1500


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
	return {"parries": 0, "blocks": 0, "cuts": 0, "hits": 0, "binds_won": 0, "binds_lost": 0,
		"parried_me": 0, "won": false}


func _stats_line(s: Dictionary) -> String:
	return "쳐내기 %d번, 막기 %d번, 벤 횟수 %d번\n힘싸움 %d승 %d패, 맞은 횟수 %d번" % [
		s["parries"], s["blocks"], s["cuts"], s["binds_won"], s["binds_lost"], s["hits"]]


## 을/를 depending on whether the last syllable ends in a consonant (받침).
func _obj_particle(word: String) -> String:
	if word.is_empty():
		return "를"
	var code := word.unicode_at(word.length() - 1)
	if code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0:
		return "을"
	return "를"


# --- saving, web and frame rate ------------------------------------------------------

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_practice_done = bool(cfg.get_value("progress", "practice_done", false))
		for bus in _volumes:
			_volumes[bus] = float(cfg.get_value("volume", bus, _volumes[bus]))


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "practice_done", _practice_done)
	for bus in _volumes:
		cfg.set_value("volume", bus, _volumes[bus])
	cfg.save(SAVE_PATH)


## 60 fps while fighting, 30 on the cards between fights. (Called on every phase
## change, so it also shows the settings button on card screens.)
func _set_fps() -> void:
	var fighting := _phase == Phase.FIGHT or _phase == Phase.PRACTICE
	Engine.max_fps = 60 if fighting else 30
	_hud.show_settings_button(not fighting and not _menu_open)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_captured_at = Time.get_ticks_msec()


# --- settings ---------------------------------------------------------------------

## in_game: opened mid-fight, which pauses it.
func _open_menu(in_game: bool) -> void:
	_menu_open = true
	if in_game:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_settings(_volumes, in_game)


func _close_menu(to_title: bool) -> void:
	_menu_open = false
	_hud.hide_settings()
	_save_progress()
	var fighting := _phase == Phase.FIGHT or _phase == Phase.PRACTICE
	get_tree().paused = false
	if to_title:
		_to_title()
	elif fighting:
		_capture_mouse()   # the button click is the user gesture browsers require
	_set_fps()


func _on_volume_changed(bus: String, value: float) -> void:
	_volumes[bus] = value
	Sfx.set_volume(bus, value)


## In the browser: stop everything while the tab is hidden, and keep the 3D resolution
## reasonable on very high pixel-density screens.
func _setup_web() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(_on_visibility_change)
	var document := JavaScriptBridge.get_interface("document")
	document.addEventListener("visibilitychange", _visibility_cb)
	var dpr := float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true))
	if dpr > 2.0:
		get_viewport().scaling_3d_scale = 2.0 / dpr


func _on_visibility_change(_args: Array) -> void:
	var hidden := bool(JavaScriptBridge.eval("document.hidden", true))
	if hidden:
		get_tree().paused = true
		AudioServer.set_bus_mute(0, true)
		Engine.max_fps = 5
		if (_phase == Phase.FIGHT or _phase == Phase.PRACTICE) and not _menu_open:
			_open_menu(true)   # come back to a paused game, not a fight already under way
	else:
		Sfx.set_volume("Master", _volumes["Master"])
		get_tree().paused = _menu_open and (_phase == Phase.FIGHT or _phase == Phase.PRACTICE)
		_set_fps()


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
			Armor.part(self, Armor.box(Vector3(0.03, 1.5, 0.8)), Armor.cloth(color), at + Vector3(-bx * 0.03, 2.0, 0.0))
			Armor.part(self, Armor.cylinder(0.025, 0.025, 0.95), Armor.wood(), at + Vector3(-bx * 0.03, 2.77, 0.0)).rotation_degrees = Vector3(90, 0, 0)

	_weapon_rack(Vector3(6.6, 0.0, -6.6), deg_to_rad(45.0))
	_weapon_rack(Vector3(-6.6, 0.0, 6.6), deg_to_rad(-135.0))
	_props()

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
	env.fog_sky_affect = 0.15   # a haze on the horizon; the sunset sky shows through
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


## Photoscanned CC0 props from Poly Haven (assets/props, see CREDITS.md).
func _props() -> void:
	# The gate at the far end: the castle door between two pillars under a lintel.
	_prop("castle_door/large_castle_door_1k.gltf", Vector3(0.0, 0.0, -7.55), 0.0)
	for gx in [-1.35, 1.35]:
		_solid_box(Vector3(gx, 1.7, -7.7), Vector3(0.7, 3.4, 0.7), Armor.wall_stone())
	_solid_box(Vector3(0.0, 3.6, -7.7), Vector3(3.4, 0.45, 0.8), Armor.wall_stone())

	_prop("barrel/wine_barrel_01_1k.gltf", Vector3(6.85, 0.0, -3.6), 20.0, Vector3(0.75, 0.9, 0.75))
	_prop("barrel/wine_barrel_01_1k.gltf", Vector3(6.9, 0.0, -2.75), -35.0, Vector3(0.75, 0.9, 0.75))
	_prop("barrel/wine_barrel_01_1k.gltf", Vector3(6.1, 0.0, -3.2), 70.0, Vector3(0.75, 0.9, 0.75))
	_prop("bucket/wooden_bucket_01_1k.gltf", Vector3(6.4, 0.0, 2.3), 15.0)
	_prop("crate/wooden_crate_01_1k.gltf", Vector3(-6.9, 0.0, -3.0), 90.0, Vector3(0.45, 0.72, 0.85))
	_prop("crate/wooden_crate_01_1k.gltf", Vector3(-6.9, 0.36, -3.0), 84.0)
	_prop("lantern/wooden_lantern_01_1k.gltf", Vector3(-6.9, 0.71, -3.2), 10.0)
	_prop("stool/wooden_stool_01_1k.gltf", Vector3(-6.5, 0.0, 2.6), 30.0)
	var shield := _prop("kite_shield/kite_shield_1k.gltf", Vector3(5.75, 0.0, -7.1), 45.0)
	if shield:
		shield.rotation_degrees.x = -12.0

	# A fire pit in the far corner: real fire light on the stones.
	var pit := _prop("fire_pit/stone_fire_pit_1k.gltf", Vector3(-5.6, 0.0, -5.6), 0.0, Vector3(1.3, 0.4, 1.3))
	if pit:
		_torch_fire(Vector3(-5.6, 0.1, -5.6), 2.5)


## Loads a glTF prop (skipped if the file is missing). collider = box size, if solid.
func _prop(path: String, pos: Vector3, yaw_deg: float, collider := Vector3.ZERO) -> Node3D:
	var full := "res://assets/props/" + path
	if not ResourceLoader.exists(full):
		return null
	var scene := load(full) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	if collider != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos + Vector3(0.0, collider.y * 0.5, 0.0)
		body.rotation_degrees.y = yaw_deg
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = collider
		col.shape = box
		body.add_child(col)
		add_child(body)
	return node


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
	_torch_fire(pos + Vector3(0.0, 0.28, 0.0), 1.0)


## Flickering flame particles and a warm light. size scales both (a fire pit is bigger).
func _torch_fire(at: Vector3, size: float) -> void:
	var flame := CPUParticles3D.new()
	flame.amount = int(24 * size)
	flame.lifetime = 0.6
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.initial_velocity_min = 0.3
	flame.initial_velocity_max = 0.7
	flame.gravity = Vector3(0.0, 0.6, 0.0)
	flame.scale_amount_min = 0.6 * size
	flame.scale_amount_max = 1.0 * size
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.04 * size
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
	flame.position = at
	add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.3
	light.omni_range = 7.0 * sqrt(size)
	light.position = at + Vector3(0.0, 0.17 * size, 0.0)
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
