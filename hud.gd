extends CanvasLayer

signal settings_requested            # the gear button on the cards
signal settings_closed(to_title: bool)
signal volume_changed(bus: String, value: float)
signal pref_changed(key: String, value: float)   # quality, difficulty (index), sens, text (share), fullscreen
signal reset_requested
signal choice_picked(index: int)   # a card clicked on a choice screen
signal title_choice(id: String)   # a choice on the main screen
## Everything drawn on screen: the opponent's name and health (top), our health and
## guard (bottom), popups for parries/blocks, one-line hints, a hurt vignette, and the
## full-screen cards used for the title, duel intros and results.

const FONT_BODY := "res://assets/fonts/NanumMyeongjo-Regular.ttf"
const FONT_TITLE := "res://assets/fonts/NanumMyeongjo-ExtraBold.ttf"
const GOLD := Color(0.93, 0.78, 0.42)

var _root: Control
var _enemy_box: Control
var _enemy_name: Label
var _enemy_fill: ColorRect
var _player_box: Control
var _hp_fill: ColorRect
var _guard_fill: ColorRect
var _breath_fill: ColorRect
var _popup: Label
var _hint_panel: PanelContainer
var _hint: Label
var _hurt: TextureRect
var _card: CenterContainer
var _card_kicker: Label
var _card_title: Label
var _card_body: Label
var _card_footer: Label
var _choices: HBoxContainer
var _skip: Button
var _choice_count := 0
var _choices_ready_at := 0
var _fade: ColorRect
var _hint_tween: Tween
var _popup_tween: Tween
var _bind_box: Control
var _bind_marker: ColorRect
var _bind_fill: ColorRect
var _bind_label: Label
var _task_panel: PanelContainer
var _task: Label
var _settings: CenterContainer
var _settings_button: Button
var _resume_button: Button
var _title_button: Button
var _sliders := {}
var _title_root: Control
var _title_menu: VBoxContainer
var _title_status: Label
var _pref_controls := {}
var _reset_button: Button
var _reset_armed := false
var _status: Label
var _ability: Label

const BAR_W := 420.0

var _prompt: Label
var _bars: Array[ColorRect] = []   # letterbox, for the execution shot


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	var shade := _vignette(Color(0, 0, 0, 0.4))
	_root.add_child(shade)
	_hurt = _vignette(Color(0.55, 0.0, 0.0, 1.0))
	_hurt.modulate.a = 0.0
	_root.add_child(_hurt)

	_build_enemy_box()
	_build_player_box()

	_prompt = Label.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.anchor_top = 0.56
	_prompt.anchor_bottom = 0.56
	_prompt.offset_left = -200
	_prompt.offset_right = 200
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_font_override("font", _title_font())
	_prompt.add_theme_color_override("font_color", GOLD)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)

	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		_root.add_child(bar)
		_bars.append(bar)

	_popup = Label.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_popup.anchor_top = 0.64
	_popup.anchor_bottom = 0.64
	_popup.offset_left = -300
	_popup.offset_right = 300
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.add_theme_font_size_override("font_size", 34)
	_popup.add_theme_font_override("font", _title_font())
	_popup.pivot_offset = Vector2(300, 20)
	_popup.modulate.a = 0.0
	_root.add_child(_popup)

	_hint_panel = PanelContainer.new()
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.offset_top = -150
	_hint_panel.offset_bottom = -104
	_hint_panel.offset_left = -400
	_hint_panel.offset_right = 400
	_hint_panel.add_theme_stylebox_override("panel", _panel_style(0.55, 10))
	_hint_panel.modulate.a = 0.0
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_root.add_child(_hint_panel)

	_build_bind_box()
	_build_task_panel()
	_build_card()
	_build_settings()
	_build_status()
	_build_title()

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	show_fight_ui(false)


# --- public API ---------------------------------------------------------------

func show_fight_ui(on: bool, show_enemy := true) -> void:
	_enemy_box.visible = on and show_enemy
	_player_box.visible = on
	_status.visible = on and _status.text != ""
	_ability.visible = on and _ability.text != ""


## Bind contest: balance -1 (losing) .. +1 (winning); push_dir is the way the player
## should push the mouse (-1 left, +1 right); warn while the opponent is about to switch.
func show_bind(balance: float, push_dir: float, warn: bool) -> void:
	_bind_box.visible = true
	var w := 360.0
	var x := (clampf(balance, -1.0, 1.0) + 1.0) * 0.5 * w
	_bind_marker.position.x = x - 4.0
	if balance >= 0.0:
		_bind_fill.position.x = w * 0.5
		_bind_fill.size.x = x - w * 0.5
		_bind_fill.color = GOLD
	else:
		_bind_fill.position.x = x
		_bind_fill.size.x = w * 0.5 - x
		_bind_fill.color = Color(0.85, 0.2, 0.15)
	_bind_label.text = "◀ 밀어라 ◀" if push_dir < 0.0 else "▶ 밀어라 ▶"
	_bind_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if warn else Color(0.97, 0.95, 0.88))


func hide_bind() -> void:
	_bind_box.visible = false


## Persistent practice instruction (stays until changed or cleared).
func task(text: String) -> void:
	_task.text = text
	_task_panel.visible = true


func clear_task() -> void:
	_task_panel.visible = false


## The small button in the corner that opens the settings from a card screen.
func show_settings_button(on: bool) -> void:
	_settings_button.visible = on


## in_game: opened from a fight (Resume / back-to-title) rather than from a card.
func show_settings(volumes: Dictionary, in_game: bool, prefs := {}) -> void:
	for bus in _sliders:
		(_sliders[bus] as HSlider).set_value_no_signal(float(volumes.get(bus, prefs.get(bus, 1.0))) * 100.0)
		_update_pct(bus)
	for key in ["quality", "difficulty", "hero"]:
		(_pref_controls[key] as OptionButton).select(int(prefs.get(key, 1)))
	if _pref_controls.has("fullscreen"):
		(_pref_controls["fullscreen"] as CheckButton).set_pressed_no_signal(bool(prefs.get("fullscreen", false)))
	_reset_armed = false
	_reset_button.text = "저장 지우기"
	_resume_button.text = "계속하기" if in_game else "닫기"
	_title_button.visible = in_game
	_settings.visible = true
	_settings_button.visible = false


func hide_settings() -> void:
	_settings.visible = false


func is_settings_open() -> bool:
	return _settings.visible


func set_enemy(enemy_name: String) -> void:
	_enemy_name.text = enemy_name


func set_enemy_hp(frac: float) -> void:
	_enemy_fill.size.x = BAR_W * clampf(frac, 0.0, 1.0)


func set_player(hp_frac: float, guard_frac: float, hurt: float, breath_frac := 1.0) -> void:
	_breath_fill.size.x = 300.0 * clampf(breath_frac, 0.0, 1.0)
	_breath_fill.color = Color(0.95, 0.5, 0.3) if breath_frac < 0.35 else Color(0.55, 0.75, 0.9)
	_hp_fill.size.x = 300.0 * clampf(hp_frac, 0.0, 1.0)
	_guard_fill.size.x = 300.0 * clampf(guard_frac, 0.0, 1.0)
	_guard_fill.color = Color(0.95, 0.35, 0.2) if guard_frac > 0.66 else GOLD
	_hurt.modulate.a = clampf(hurt, 0.0, 1.0) * 0.8


## Black bars slide in top and bottom (a film shot) or back out.
func set_letterbox(on: bool) -> void:
	var h := get_viewport().get_visible_rect().size.y * 0.12
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bars[0], "offset_bottom", h if on else 0.0, 0.18)
	tw.tween_property(_bars[1], "offset_top", -h if on else 0.0, 0.18)
	_enemy_box.visible = not on
	_player_box.visible = not on


## The key prompt for a special move ("" hides it); it pulses while shown.
func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""
	if _prompt.visible:
		_prompt.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)


func popup(text: String, color: Color) -> void:
	_popup.text = text
	_popup.add_theme_color_override("font_color", color)
	if _popup_tween:
		_popup_tween.kill()
	_popup.modulate.a = 1.0
	_popup.scale = Vector2(1.3, 1.3)
	_popup_tween = create_tween().set_ignore_time_scale(true)
	_popup_tween.tween_property(_popup, "scale", Vector2.ONE, 0.12)
	_popup_tween.tween_interval(0.45)
	_popup_tween.tween_property(_popup, "modulate:a", 0.0, 0.35)


func hint(text: String, seconds := 4.5) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_ignore_time_scale(true)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.6)


func clear_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_panel.modulate.a = 0.0


## A row of cards to pick from, by click or by number key (main.gd answers choice_picked).
## Each option: {"title", "tag", "text", "note"}; skip_label adds a plain button after the cards.
func show_choices(kicker: String, title: String, options: Array, footer: String, skip_label := "") -> void:
	show_card(kicker, title, "", footer)
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	_choice_count = options.size()
	_choices_ready_at = Time.get_ticks_msec() + 350
	for i in options.size():
		_choices.add_child(_choice_card(i, options[i], 250.0 if options.size() <= 3 else 188.0))
	_choices.visible = true
	_skip.text = skip_label
	_skip.visible = skip_label != ""


func _choice_card(i: int, o: Dictionary, width := 250.0) -> PanelContainer:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.10, 0.09, 0.94)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.42, 0.36, 0.24, 0.9)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(18)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.14, 0.10, 0.97)
	hover.border_color = GOLD
	hover.set_border_width_all(3)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 250)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.add_theme_stylebox_override("panel", normal)
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", hover))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", normal))
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			p.accept_event()
			if Time.get_ticks_msec() >= _choices_ready_at:
				choice_picked.emit(i))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(_card_label(str(i + 1), 22, GOLD, false, width))
	v.add_child(_card_label(String(o.get("title", "")), 28 if width > 200.0 else 23, Color(1, 1, 1), false, width))
	if String(o.get("tag", "")) != "":
		v.add_child(_card_label(String(o["tag"]), 17, GOLD, false, width))
	var line := HSeparator.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var body := _card_label(String(o.get("text", "")), 18 if width > 200.0 else 16, Color(0.92, 0.9, 0.85), true, width)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	if String(o.get("note", "")) != "":
		v.add_child(_card_label(String(o["note"]), 16, Color(0.98, 0.86, 0.5), true, width))
	return p


func _card_label(text: String, size: int, color: Color, left: bool, width := 250.0) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width - 36.0, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func show_card(kicker: String, title: String, body: String, footer: String) -> void:
	_choices.visible = false
	_skip.visible = false
	_card_kicker.text = kicker
	_card_kicker.visible = kicker != ""
	_card_title.text = title
	_card_body.text = body
	_card_body.visible = body != ""
	_card_footer.text = footer
	_card.visible = true
	_card.modulate.a = 0.0
	create_tween().set_ignore_time_scale(true).tween_property(_card, "modulate:a", 1.0, 0.35)


func hide_card() -> void:
	_card.visible = false
	_choices.visible = false
	_skip.visible = false


func is_card_visible() -> bool:
	return _card.visible


func fade(to_alpha: float, seconds: float) -> Tween:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_fade, "color:a", to_alpha, seconds)
	return tw


# --- building -------------------------------------------------------------------

func _build_enemy_box() -> void:
	_enemy_box = Control.new()
	_enemy_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_enemy_box.offset_left = -BAR_W / 2.0
	_enemy_box.offset_right = BAR_W / 2.0
	_enemy_box.offset_top = 18
	_enemy_box.offset_bottom = 70
	_enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_enemy_box)

	_enemy_name = Label.new()
	_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name.size = Vector2(BAR_W, 30)
	_enemy_name.add_theme_font_size_override("font_size", 24)
	_enemy_name.add_theme_font_override("font", _title_font())
	_enemy_box.add_child(_enemy_name)
	_enemy_fill = _bar(_enemy_box, Vector2(0, 36), Vector2(BAR_W, 9), Color(0.78, 0.16, 0.12))


func _build_player_box() -> void:
	_player_box = Control.new()
	_player_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_player_box.offset_left = -150
	_player_box.offset_right = 150
	_player_box.offset_top = -82
	_player_box.offset_bottom = -20
	_player_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_player_box)

	_breath_fill = _bar(_player_box, Vector2(0, 4), Vector2(300, 6), Color(0.55, 0.75, 0.9))
	_guard_fill = _bar(_player_box, Vector2(0, 24), Vector2(300, 7), GOLD)
	_hp_fill = _bar(_player_box, Vector2(0, 44), Vector2(300, 9), Color(0.72, 0.14, 0.12))
	_side_label(_player_box, "숨", 7.0)
	_side_label(_player_box, "자세", 27.5)
	_side_label(_player_box, "체력", 48.5)


func _build_bind_box() -> void:
	_bind_box = Control.new()
	_bind_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_bind_box.anchor_top = 0.74
	_bind_box.anchor_bottom = 0.74
	_bind_box.offset_left = -180
	_bind_box.offset_right = 180
	_bind_box.offset_top = -40
	_bind_box.offset_bottom = 20
	_bind_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bind_box)

	_bind_label = Label.new()
	_bind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bind_label.size = Vector2(360, 34)
	_bind_label.add_theme_font_size_override("font_size", 28)
	_bind_label.add_theme_font_override("font", _title_font())
	_bind_box.add_child(_bind_label)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06, 0.8)
	bg.position = Vector2(-2, 38)
	bg.size = Vector2(364, 16)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_box.add_child(bg)
	_bind_fill = ColorRect.new()
	_bind_fill.position = Vector2(180, 40)
	_bind_fill.size = Vector2(0, 12)
	_bind_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_box.add_child(_bind_fill)
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.5)
	mid.position = Vector2(179, 36)
	mid.size = Vector2(2, 20)
	_bind_box.add_child(mid)
	_bind_marker = ColorRect.new()
	_bind_marker.color = Color(1, 1, 1)
	_bind_marker.position = Vector2(176, 34)
	_bind_marker.size = Vector2(8, 24)
	_bind_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_box.add_child(_bind_marker)
	_bind_box.visible = false


func _build_task_panel() -> void:
	_task_panel = PanelContainer.new()
	_task_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_task_panel.offset_top = 90
	_task_panel.offset_bottom = 140
	_task_panel.offset_left = -330
	_task_panel.offset_right = 330
	_task_panel.add_theme_stylebox_override("panel", _panel_style(0.6, 12))
	_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task = Label.new()
	_task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_task.add_theme_font_size_override("font_size", 24)
	_task.add_theme_font_override("font", _title_font())
	_task_panel.add_child(_task)
	_root.add_child(_task_panel)
	_task_panel.visible = false


func _build_card() -> void:
	_card = CenterContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.8, 40))
	panel.custom_minimum_size = Vector2(700, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # a click anywhere advances the card
	_card.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_card_kicker = Label.new()
	_card_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_kicker.add_theme_color_override("font_color", GOLD)
	_card_kicker.add_theme_font_size_override("font_size", 20)
	box.add_child(_card_kicker)

	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 52)
	_card_title.add_theme_font_override("font", _title_font())
	box.add_child(_card_title)

	_card_body = Label.new()
	_card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_body.custom_minimum_size = Vector2(620, 0)
	_card_body.add_theme_font_size_override("font_size", 20)
	_card_body.add_theme_constant_override("line_spacing", 6)
	box.add_child(_card_body)

	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 14)
	_choices.visible = false
	box.add_child(_choices)

	_skip = Button.new()
	_skip.visible = false
	_skip.pressed.connect(func():
		if Time.get_ticks_msec() >= _choices_ready_at:
			choice_picked.emit(_choice_count))
	box.add_child(_skip)

	_card_footer = Label.new()
	_card_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_footer.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	_card_footer.add_theme_font_size_override("font_size", 18)
	box.add_child(_card_footer)
	_card.visible = false


func _build_settings() -> void:
	_settings_button = Button.new()
	_settings_button.text = "설정"
	_settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_settings_button.offset_left = -110
	_settings_button.offset_right = -20
	_settings_button.offset_top = 20
	_settings_button.offset_bottom = 60
	_settings_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_button.pressed.connect(func(): settings_requested.emit())
	_root.add_child(_settings_button)
	_settings_button.visible = false

	_settings = CenterContainer.new()
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.9, 32))
	panel.custom_minimum_size = Vector2(520, 0)
	_settings.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "설정"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_font_override("font", _title_font())
	box.add_child(title)

	for row in [["Master", "전체 소리"], ["Music", "음악"], ["SFX", "효과음"], ["Ambience", "바람 소리"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size = Vector2(110, 0)
		line.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(260, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bus: String = row[0]
		slider.value_changed.connect(func(v: float):
			_update_pct(bus)
			volume_changed.emit(bus, v / 100.0))
		line.add_child(slider)
		var pct := Label.new()
		pct.name = "Pct"
		pct.custom_minimum_size = Vector2(56, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(pct)
		box.add_child(line)
		_sliders[bus] = slider

	for row in [["quality", "그래픽", ["낮음", "보통", "높음"]], ["difficulty", "난이도", ["쉬움", "보통", "어려움"]], ["hero", "주인공", ["남", "여"]]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size = Vector2(110, 0)
		line.add_child(name_label)
		var ob := OptionButton.new()
		for item in row[2]:
			ob.add_item(item)
		ob.custom_minimum_size = Vector2(160, 36)
		var key: String = row[0]
		ob.item_selected.connect(func(i: int): pref_changed.emit(key, float(i)))
		line.add_child(ob)
		box.add_child(line)
		_pref_controls[key] = ob
	for row in [["sens", "마우스 감도", 30, 200], ["text", "대사 속도", 50, 300]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size = Vector2(110, 0)
		line.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = 5
		slider.custom_minimum_size = Vector2(260, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = row[0]
		slider.value_changed.connect(func(v: float):
			_update_pct(key)
			pref_changed.emit(key, v / 100.0))
		line.add_child(slider)
		var pct := Label.new()
		pct.name = "Pct"
		pct.custom_minimum_size = Vector2(56, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(pct)
		box.add_child(line)
		_sliders[key] = slider
	if not OS.has_feature("web"):
		var full := CheckButton.new()
		full.text = "전체 화면"
		full.toggled.connect(func(on: bool): pref_changed.emit("fullscreen", 1.0 if on else 0.0))
		box.add_child(full)
		_pref_controls["fullscreen"] = full

	var hint := Label.new()
	hint.text = "싸우는 중에는 ESC로 이 창을 엽니다"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68))
	box.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_resume_button = Button.new()
	_resume_button.text = "계속하기"
	_resume_button.custom_minimum_size = Vector2(150, 44)
	_resume_button.pressed.connect(func(): settings_closed.emit(false))
	buttons.add_child(_resume_button)
	_title_button = Button.new()
	_title_button.text = "처음 화면으로"
	_title_button.custom_minimum_size = Vector2(150, 44)
	_title_button.pressed.connect(func(): settings_closed.emit(true))
	buttons.add_child(_title_button)
	_reset_button = Button.new()
	_reset_button.text = "저장 지우기"
	_reset_button.custom_minimum_size = Vector2(150, 44)
	_reset_button.pressed.connect(func():
		if _reset_armed:
			_reset_armed = false
			_reset_button.text = "저장 지우기"
			reset_requested.emit()
		else:
			_reset_armed = true
			_reset_button.text = "정말? 한 번 더")
	buttons.add_child(_reset_button)

	_root.add_child(_settings)
	_settings.visible = false


## The main screen: the logo, and a column of choices over the slowly turning courtyard.
## items: [[id, text], ...]; `title_choice(id)` is emitted when one is picked.
func show_title(items: Array, status: String) -> void:
	for c in _title_menu.get_children():
		c.queue_free()
	for it in items:
		var b := Button.new()
		b.text = it[1]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", _title_font())
		b.add_theme_font_size_override("font_size", 34)
		b.add_theme_color_override("font_color", Color(0.93, 0.89, 0.78))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.38))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.6))
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var id: String = it[0]
		b.pressed.connect(func(): title_choice.emit(id))
		_title_menu.add_child(b)
	_title_status.text = status
	_title_root.visible = true
	_title_root.modulate.a = 0.0
	create_tween().set_ignore_time_scale(true).tween_property(_title_root, "modulate:a", 1.0, 0.8)


func hide_title() -> void:
	_title_root.visible = false


func _build_title() -> void:
	_title_root = Control.new()
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.visible = false
	_root.add_child(_title_root)
	# A dark band down the left so the writing reads over any background.
	var band := ColorRect.new()
	band.color = Color(0.03, 0.02, 0.02, 0.62)
	band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 620.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(band)
	var edge := ColorRect.new()
	edge.color = Color(0.98, 0.82, 0.35, 0.55)
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 618.0
	edge.offset_right = 620.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(edge)
	var box := VBoxContainer.new()
	box.position = Vector2(84, 96)
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(box)
	var kicker := Label.new()
	kicker.text = "왕립 철검관"
	kicker.add_theme_font_override("font", _title_font())
	kicker.add_theme_font_size_override("font_size", 26)
	kicker.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	box.add_child(kicker)
	var logo := Label.new()
	logo.text = "진검승부"
	logo.add_theme_font_override("font", _title_font())
	logo.add_theme_font_size_override("font_size", 112)
	logo.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	logo.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	logo.add_theme_constant_override("outline_size", 10)
	box.add_child(logo)
	var tag := Label.new()
	tag.text = "검 한 자루로 오르는 학교"
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.80, 0.76, 0.68))
	box.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 42)
	box.add_child(gap)
	_title_menu = VBoxContainer.new()
	_title_menu.add_theme_constant_override("separation", 4)
	box.add_child(_title_menu)
	_title_status = Label.new()
	_title_status.position = Vector2(84, 640)
	_title_status.add_theme_font_size_override("font_size", 18)
	_title_status.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	_title_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(_title_status)


func set_ability(text: String) -> void:
	_ability.text = text
	_ability.visible = text != "" and _player_box.visible
	_ability.modulate.a = 1.0 if text.length() < 12 or not ("." in text) else 0.55


func _build_status() -> void:
	_ability = Label.new()
	_ability.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ability.offset_left = -330.0
	_ability.offset_top = -60.0
	_ability.offset_right = -28.0
	_ability.offset_bottom = -22.0
	_ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ability.add_theme_font_size_override("font_size", 22)
	_ability.add_theme_color_override("font_color", Color(0.98, 0.86, 0.5))
	_ability.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_ability.add_theme_constant_override("outline_size", 6)
	_ability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability.visible = false
	_root.add_child(_ability)
	_status = Label.new()
	_status.position = Vector2(24, 20)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.visible = false
	_root.add_child(_status)


## The standing and the learned techniques, small in the corner of a fight.
func set_status(text: String) -> void:
	_status.text = text


func _update_pct(bus: String) -> void:
	var slider: HSlider = _sliders[bus]
	(slider.get_parent().get_node("Pct") as Label).text = "%d%%" % int(slider.value)


func _bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06, 0.75)
	bg.position = pos - Vector2(2, 2)
	bg.size = size + Vector2(4, 4)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos
	fill.size = size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return fill


## A small name to the left of a bar, centred on it (centre_y: the bar's middle).
func _side_label(parent: Control, text: String, centre_y: float) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_constant_override("outline_size", 4)
	l.size = Vector2(44, 20)
	l.position = Vector2(-52, centre_y - 10.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


func _vignette(color: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))
	g.set_color(1, color)
	g.add_point(0.55, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)   # full strength only in the very corners
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _panel_style(alpha: float, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.035, 0.03, alpha)
	s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(pad)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(FONT_BODY):
		t.default_font = load(FONT_BODY)
	t.default_font_size = 20
	t.set_color("font_color", "Label", Color(0.93, 0.91, 0.86))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 5)
	return t


func _title_font() -> Font:
	if ResourceLoader.exists(FONT_TITLE):
		return load(FONT_TITLE)
	return ThemeDB.fallback_font
