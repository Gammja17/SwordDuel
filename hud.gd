extends CanvasLayer
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
var _fade: ColorRect
var _hint_tween: Tween
var _popup_tween: Tween
var _bind_box: Control
var _bind_marker: ColorRect
var _bind_fill: ColorRect
var _bind_label: Label
var _task_panel: PanelContainer
var _task: Label

const BAR_W := 420.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	var shade := _vignette(Color(0, 0, 0, 0.65))
	_root.add_child(shade)
	_hurt = _vignette(Color(0.55, 0.0, 0.0, 1.0))
	_hurt.modulate.a = 0.0
	_root.add_child(_hurt)

	_build_enemy_box()
	_build_player_box()

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
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_root.add_child(_hint_panel)

	_build_bind_box()
	_build_task_panel()
	_build_card()

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


func show_card(kicker: String, title: String, body: String, footer: String) -> void:
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

	_breath_fill = _bar(_player_box, Vector2(0, 8), Vector2(300, 6), Color(0.55, 0.75, 0.9))
	_guard_fill = _bar(_player_box, Vector2(0, 26), Vector2(300, 7), GOLD)
	_hp_fill = _bar(_player_box, Vector2(0, 44), Vector2(300, 9), Color(0.72, 0.14, 0.12))
	_side_label(_player_box, "숨", Vector2(-54, 0))
	_side_label(_player_box, "자세", Vector2(-54, 18))
	_side_label(_player_box, "체력", Vector2(-54, 37))


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

	_card_footer = Label.new()
	_card_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_footer.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	_card_footer.add_theme_font_size_override("font_size", 18)
	box.add_child(_card_footer)
	_card.visible = false


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


func _side_label(parent: Control, text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 15)
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
	tex.fill_to = Vector2(1.0, 0.5)
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
