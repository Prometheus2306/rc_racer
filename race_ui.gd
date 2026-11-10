class_name RaceUI
extends CanvasLayer

signal start_race_requested
signal restart_race_requested
signal open_menu_requested
signal car_class_changed(class_id: int)
signal paint_changed(paint_id: int)
signal track_changed(track_id: int)
signal laps_changed(laps: int)

var _sel_class: int = 0
var _sel_paint: int = 0
var _sel_track: int = 0
var _sel_laps: int = 3

var _menu_root: Control
var _hud_root: Control
var _finish_root: Control

# Menu dynamic widgets
var _class_title_lbl: Label
var _class_desc_lbl: Label
var _stat_bars: Array[ProgressBar] = []
var _paint_buttons: Array[Button] = []
var _track_buttons: Array[Button] = []
var _lap_buttons: Array[Button] = []

# HUD dynamic widgets
var _rank_lbl: Label
var _lap_lbl: Label
var _time_lbl: Label
var _best_lbl: Label
var _item_icon: TextureRect
var _item_name_lbl: Label
var _speed_bar: ProgressBar
var _speed_lbl: Label
var _center_banner: Label
var _toast_lbl: Label
var _toast_timer: float = 0.0

# Finish dynamic widgets
var _finish_title_lbl: Label
var _standings_box: VBoxContainer


func _ready() -> void:
	layer = 10
	_build_menu_ui()
	_build_hud_ui()
	_build_finish_ui()
	show_menu()
	_refresh_menu_state()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_lbl != null:
			_toast_lbl.visible = false


# --- Style Helpers (Paper Mario Cardstock + Hard Ink Shadow) ---
func _card_style(bg: Color, radius: int = 16, border_w: int = 4, shadow_off: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = PaperStyle.INK_DARK
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.10, 0.08, 0.07, 0.38)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(shadow_off, shadow_off)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _style_button(btn: Button, bg: Color, font_col: Color = PaperStyle.INK_DARK, font_sz: int = 18) -> void:
	btn.add_theme_stylebox_override("normal", _card_style(bg, 12, 3, 4))
	btn.add_theme_stylebox_override("hover", _card_style(bg.lightened(0.12), 12, 3, 5))
	btn.add_theme_stylebox_override("pressed", _card_style(bg.darkened(0.08), 12, 3, 2))
	btn.add_theme_stylebox_override("focus", _card_style(bg.lightened(0.08), 12, 4, 4))
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col)
	btn.add_theme_color_override("font_pressed_color", font_col)
	btn.add_theme_color_override("font_focus_color", font_col)
	btn.add_theme_font_size_override("font_size", font_sz)


func _make_label(txt: String, sz: int, col: Color = PaperStyle.INK_DARK, outline: int = 0, out_col: Color = PaperStyle.PAPER_WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", out_col)
	return l


# --- 1. Pre-Race Paper Mario Menu ---
func _build_menu_ui() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_menu_root.add_child(margin)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 14)
	margin.add_child(main_col)

	# Title Ribbon Card
	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header_panel.add_theme_stylebox_override("panel", _card_style(Color(0.93, 0.24, 0.20), 20, 4, 7))
	main_col.add_child(header_panel)

	var h_vbox := VBoxContainer.new()
	h_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_panel.add_child(h_vbox)

	var title := _make_label("★ FUNK-FLITZER ★", 36, Color(1.0, 0.93, 0.26), 8, PaperStyle.INK_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_vbox.add_child(title)

	var sub := _make_label("3-D Ultra Radio Control Racers · Papier-Diorama Edition", 15, PaperStyle.PAPER_WHITE, 4, PaperStyle.INK_DARK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_vbox.add_child(sub)

	# Left-docked Selection Card (leaves right side open to admire the live 3D RC Car & Track!)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(470, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _card_style(PaperStyle.PAPER_WHITE, 18, 4, 7))
	main_col.add_child(card)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 11)
	card.add_child(form)

	# --- Vehicle Class Picker ---
	form.add_child(_make_label("1. RC-Fahrzeugklasse", 18, PaperStyle.INK_DARK))
	var cls_row := HBoxContainer.new()
	cls_row.add_theme_constant_override("separation", 8)
	form.add_child(cls_row)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	_style_button(prev_btn, Color(1.0, 0.84, 0.24), PaperStyle.INK_DARK, 18)
	prev_btn.pressed.connect(func(): _set_class(_sel_class - 1))
	cls_row.add_child(prev_btn)

	var cls_info_box := VBoxContainer.new()
	cls_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cls_row.add_child(cls_info_box)

	_class_title_lbl = _make_label("Flitzer-Buggy", 20, Color(0.84, 0.18, 0.16))
	_class_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cls_info_box.add_child(_class_title_lbl)

	_class_desc_lbl = _make_label("Ausgewogen & wendig", 13, Color(0.32, 0.28, 0.26))
	_class_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cls_info_box.add_child(_class_desc_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶"
	_style_button(next_btn, Color(1.0, 0.84, 0.24), PaperStyle.INK_DARK, 18)
	next_btn.pressed.connect(func(): _set_class(_sel_class + 1))
	cls_row.add_child(next_btn)

	# Stat Bars (Tempo, Antritt, Kurven, Gelände)
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 10)
	stat_grid.add_theme_constant_override("v_separation", 4)
	form.add_child(stat_grid)

	for s_name: String in ["Tempo", "Antritt", "Handling", "Gelände"]:
		var sl := _make_label(s_name, 13, Color(0.28, 0.24, 0.22))
		stat_grid.add_child(sl)
		var pb := ProgressBar.new()
		pb.min_value = 0.0
		pb.max_value = 100.0
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(180, 12)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg_sb := _card_style(Color(0.88, 0.84, 0.76), 6, 2, 0)
		bg_sb.content_margin_top = 0; bg_sb.content_margin_bottom = 0
		var fg_sb := _card_style(Color(0.24, 0.76, 0.36), 6, 2, 0)
		fg_sb.content_margin_top = 0; fg_sb.content_margin_bottom = 0
		pb.add_theme_stylebox_override("background", bg_sb)
		pb.add_theme_stylebox_override("fill", fg_sb)
		stat_grid.add_child(pb)
		_stat_bars.append(pb)

	# --- Paint Picker ---
	form.add_child(_make_label("2. Papier-Lackierung", 18, PaperStyle.INK_DARK))
	var paint_row := HBoxContainer.new()
	paint_row.add_theme_constant_override("separation", 6)
	form.add_child(paint_row)

	for p_i in range(PaperStyle.CAR_PAINTS.size()):
		var p_btn := Button.new()
		p_btn.custom_minimum_size = Vector2(56, 34)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.text = ""
		var idx_capture := p_i
		p_btn.pressed.connect(func(): _set_paint(idx_capture))
		paint_row.add_child(p_btn)
		_paint_buttons.append(p_btn)

	# --- Track Picker ---
	form.add_child(_make_label("3. Miniatur-Strecke", 18, PaperStyle.INK_DARK))
	var trk_col := VBoxContainer.new()
	trk_col.add_theme_constant_override("separation", 6)
	form.add_child(trk_col)

	for t_i in range(TrackBuilder.TRACK_INFO.size()):
		var t_info: Dictionary = TrackBuilder.TRACK_INFO[t_i]
		var t_btn := Button.new()
		t_btn.text = "%s — %s" % [t_info["name"], t_info["subtitle"]]
		var t_cap := t_i
		t_btn.pressed.connect(func(): _set_track(t_cap))
		trk_col.add_child(t_btn)
		_track_buttons.append(t_btn)

	# --- Laps Picker ---
	var lap_row := HBoxContainer.new()
	lap_row.add_theme_constant_override("separation", 8)
	form.add_child(lap_row)
	lap_row.add_child(_make_label("Runden:", 17, PaperStyle.INK_DARK))
	for lp: int in [2, 3, 5]:
		var lb := Button.new()
		lb.text = "%d Runden" % lp
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lp_cap: int = lp
		lb.pressed.connect(func(): _set_laps(lp_cap))
		lap_row.add_child(lb)
		_lap_buttons.append(lb)

	# --- Start Button ---
	var start_btn := Button.new()
	start_btn.text = "🏁 RENNEN STARTEN!  [Enter]"
	start_btn.custom_minimum_size = Vector2(0, 52)
	_style_button(start_btn, Color(0.24, 0.78, 0.34), PaperStyle.PAPER_WHITE, 22)
	start_btn.pressed.connect(func(): start_race_requested.emit())
	form.add_child(start_btn)


func _set_class(c: int) -> void:
	_sel_class = posmod(c, CarVisuals.VEHICLE_CLASSES.size())
	_refresh_menu_state()
	car_class_changed.emit(_sel_class)


func _set_paint(p: int) -> void:
	_sel_paint = posmod(p, PaperStyle.CAR_PAINTS.size())
	_refresh_menu_state()
	paint_changed.emit(_sel_paint)


func _set_track(t: int) -> void:
	_sel_track = posmod(t, TrackBuilder.TRACK_INFO.size())
	_refresh_menu_state()
	track_changed.emit(_sel_track)


func _set_laps(l: int) -> void:
	_sel_laps = l
	_refresh_menu_state()
	laps_changed.emit(_sel_laps)


func _refresh_menu_state() -> void:
	var cls: Dictionary = CarVisuals.VEHICLE_CLASSES[_sel_class]
	_class_title_lbl.text = String(cls["name"])
	_class_desc_lbl.text = String(cls["tagline"])

	# Normalized visual stat bars
	if _stat_bars.size() >= 4:
		_stat_bars[0].value = clampf((float(cls["top_speed"]) - 19.0) / 6.5 * 100.0, 25.0, 100.0)
		_stat_bars[1].value = clampf((float(cls["accel"]) - 20.0) / 13.0 * 100.0, 25.0, 100.0)
		_stat_bars[2].value = clampf((float(cls["turn_speed"]) - 2.3) / 1.3 * 100.0, 25.0, 100.0)
		_stat_bars[3].value = clampf((float(cls["offroad_grip"]) - 0.65) / 0.35 * 100.0, 25.0, 100.0)

	for i in range(_paint_buttons.size()):
		var col: Color = PaperStyle.CAR_PAINTS[i]["color"]
		var selected := (i == _sel_paint)
		_paint_buttons[i].text = "✓" if selected else ""
		_style_button(_paint_buttons[i], col, PaperStyle.PAPER_WHITE, 18)

	for i in range(_track_buttons.size()):
		var selected := (i == _sel_track)
		var bg := Color(1.0, 0.86, 0.28) if selected else Color(0.95, 0.92, 0.84)
		_style_button(_track_buttons[i], bg, PaperStyle.INK_DARK, 14)

	var lap_opts: Array[int] = [2, 3, 5]
	for i in range(_lap_buttons.size()):
		var selected := (lap_opts[i] == _sel_laps)
		var bg := Color(0.32, 0.78, 0.98) if selected else Color(0.95, 0.92, 0.84)
		_style_button(_lap_buttons[i], bg, PaperStyle.INK_DARK, 14)


# --- 2. In-Race Paper Mario HUD ---
func _build_hud_ui() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	var hud_margin := MarginContainer.new()
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_margin.add_theme_constant_override("margin_left", 22)
	hud_margin.add_theme_constant_override("margin_right", 22)
	hud_margin.add_theme_constant_override("margin_top", 18)
	hud_margin.add_theme_constant_override("margin_bottom", 18)
	_hud_root.add_child(hud_margin)

	var hud_vbox := VBoxContainer.new()
	hud_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_margin.add_child(hud_vbox)

	# --- Top Row: Position/Lap Card (Left) + Toast (Center) + Power-Up Card (Right) ---
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vbox.add_child(top_row)

	var tl_card := PanelContainer.new()
	tl_card.custom_minimum_size = Vector2(240, 0)
	tl_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tl_card.add_theme_stylebox_override("panel", _card_style(PaperStyle.PAPER_WHITE, 16, 4, 5))
	top_row.add_child(tl_card)

	var tl_vbox := VBoxContainer.new()
	tl_vbox.add_theme_constant_override("separation", 3)
	tl_card.add_child(tl_vbox)

	_rank_lbl = _make_label("1. PLATZ", 30, Color(0.92, 0.24, 0.18), 6, PaperStyle.PAPER_WHITE)
	tl_vbox.add_child(_rank_lbl)

	_lap_lbl = _make_label("Runde 1 / 3", 20, PaperStyle.INK_DARK)
	tl_vbox.add_child(_lap_lbl)

	_time_lbl = _make_label("Zeit: 00:00.0", 15, Color(0.28, 0.25, 0.22))
	tl_vbox.add_child(_time_lbl)

	_best_lbl = _make_label("Beste: --:--.-", 14, Color(0.18, 0.56, 0.28))
	tl_vbox.add_child(_best_lbl)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	_toast_lbl = _make_label("", 20, PaperStyle.PAPER_WHITE, 6, PaperStyle.INK_DARK)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toast_lbl.visible = false
	top_row.add_child(_toast_lbl)

	var top_spacer_r := Control.new()
	top_spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer_r)

	var tr_card := PanelContainer.new()
	tr_card.custom_minimum_size = Vector2(220, 92)
	tr_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr_card.add_theme_stylebox_override("panel", _card_style(Color(1.0, 0.94, 0.74), 16, 4, 5))
	top_row.add_child(tr_card)

	var tr_hbox := HBoxContainer.new()
	tr_hbox.add_theme_constant_override("separation", 12)
	tr_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tr_card.add_child(tr_hbox)

	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(58, 58)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_hbox.add_child(_item_icon)

	var item_vbox := VBoxContainer.new()
	item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tr_hbox.add_child(item_vbox)

	_item_name_lbl = _make_label("Leer", 18, PaperStyle.INK_DARK)
	item_vbox.add_child(_item_name_lbl)
	item_vbox.add_child(_make_label("[Shift / E] Item", 12, Color(0.35, 0.30, 0.25)))

	# --- Middle Expanding Area: Big Countdown / Callout Banner ---
	var mid_center := CenterContainer.new()
	mid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vbox.add_child(mid_center)

	_center_banner = _make_label("", 68, Color(1.0, 0.88, 0.18), 14, PaperStyle.INK_DARK)
	_center_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid_center.add_child(_center_banner)

	# --- Bottom Row: Controls Legend (Left) + Speedometer (Right) ---
	var bot_row := HBoxContainer.new()
	bot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vbox.add_child(bot_row)

	var bl_card := PanelContainer.new()
	bl_card.size_flags_vertical = Control.SIZE_SHRINK_END
	bl_card.add_theme_stylebox_override("panel", _card_style(Color(0.99, 0.96, 0.89, 0.92), 12, 3, 3))
	bot_row.add_child(bl_card)
	bl_card.add_child(_make_label("WASD/Pfeile: Fahren  |  Space: Drift  |  Shift/E: Item  |  C: Kamera  |  R: Reset  |  M: Ton  |  Esc: Menü", 13, PaperStyle.INK_DARK))

	var bot_spacer := Control.new()
	bot_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_row.add_child(bot_spacer)

	var br_card := PanelContainer.new()
	br_card.custom_minimum_size = Vector2(205, 0)
	br_card.size_flags_vertical = Control.SIZE_SHRINK_END
	br_card.add_theme_stylebox_override("panel", _card_style(PaperStyle.PAPER_WHITE, 14, 3, 4))
	bot_row.add_child(br_card)

	var br_vbox := VBoxContainer.new()
	br_vbox.add_theme_constant_override("separation", 4)
	br_card.add_child(br_vbox)

	_speed_lbl = _make_label("0 km/h", 18, PaperStyle.INK_DARK)
	_speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br_vbox.add_child(_speed_lbl)

	_speed_bar = ProgressBar.new()
	_speed_bar.min_value = 0.0
	_speed_bar.max_value = 100.0
	_speed_bar.show_percentage = false
	_speed_bar.custom_minimum_size = Vector2(170, 14)
	var sp_bg := _card_style(Color(0.86, 0.82, 0.75), 6, 2, 0)
	sp_bg.content_margin_top = 0; sp_bg.content_margin_bottom = 0
	var sp_fg := _card_style(Color(0.95, 0.38, 0.16), 6, 2, 0)
	sp_fg.content_margin_top = 0; sp_fg.content_margin_bottom = 0
	_speed_bar.add_theme_stylebox_override("background", sp_bg)
	_speed_bar.add_theme_stylebox_override("fill", sp_fg)
	br_vbox.add_child(_speed_bar)


# --- 3. Post-Race Podium Card ---
func _build_finish_ui() -> void:
	_finish_root = Control.new()
	_finish_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_finish_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finish_root.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_stylebox_override("panel", _card_style(PaperStyle.PAPER_WHITE, 20, 4, 8))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_finish_title_lbl = _make_label("🏆 ZIEL ERREICHT!", 34, Color(0.92, 0.24, 0.18), 6, PaperStyle.PAPER_WHITE)
	_finish_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_finish_title_lbl)

	_standings_box = VBoxContainer.new()
	_standings_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_standings_box)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var retry_btn := Button.new()
	retry_btn.text = "🔄 Nochmal fahren [Enter]"
	retry_btn.custom_minimum_size = Vector2(0, 46)
	retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(retry_btn, Color(0.24, 0.78, 0.34), PaperStyle.PAPER_WHITE, 18)
	retry_btn.pressed.connect(func(): restart_race_requested.emit())
	btn_row.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "🎨 Fahrzeug & Strecke"
	menu_btn.custom_minimum_size = Vector2(0, 46)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(menu_btn, Color(1.0, 0.82, 0.22), PaperStyle.INK_DARK, 18)
	menu_btn.pressed.connect(func(): open_menu_requested.emit())
	btn_row.add_child(menu_btn)


# --- Public UI State Transitions & Updates ---
func show_menu() -> void:
	_menu_root.visible = true
	_hud_root.visible = false
	_finish_root.visible = false


func show_hud() -> void:
	_menu_root.visible = false
	_hud_root.visible = true
	_finish_root.visible = false


func show_finish(ranked_racers: Array[RCCar], player_best_lap: float) -> void:
	_menu_root.visible = false
	_hud_root.visible = false
	_finish_root.visible = true

	for c in _standings_box.get_children():
		c.queue_free()

	var player_rank := 1
	for i in range(ranked_racers.size()):
		var r := ranked_racers[i]
		if not r.is_ai:
			player_rank = i + 1

		var row_panel := PanelContainer.new()
		var row_bg := Color(1.0, 0.92, 0.58) if not r.is_ai else Color(0.95, 0.92, 0.85)
		row_panel.add_theme_stylebox_override("panel", _card_style(row_bg, 10, 2, 2))
		_standings_box.add_child(row_panel)

		var h := HBoxContainer.new()
		row_panel.add_child(h)

		var cls_name: String = CarVisuals.VEHICLE_CLASSES[r.vehicle_class]["name"]
		var left_txt := "%d. %s (%s)" % [i + 1, r.racer_name, cls_name]
		var l_lbl := _make_label(left_txt, 17, PaperStyle.INK_DARK)
		l_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l_lbl)

		var t_str := _fmt_time(r.finish_time) if r.finished else "Auf Strecke"
		h.add_child(_make_label(t_str, 17, PaperStyle.INK_DARK))

	if player_best_lap < 9000.0:
		var best_line := _make_label("Beste Runde: %s" % _fmt_time(player_best_lap), 16, Color(0.18, 0.55, 0.28))
		best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_standings_box.add_child(best_line)

	if player_rank == 1:
		_finish_title_lbl.text = "🏆 1. PLATZ — SIEG!"
	else:
		_finish_title_lbl.text = "🏁 %d. PLATZ IM ZIEL!" % player_rank


func set_center_banner(txt: String, col: Color = Color(1.0, 0.88, 0.18)) -> void:
	if _center_banner == null:
		return
	_center_banner.text = txt
	_center_banner.add_theme_color_override("font_color", col)


func show_toast(txt: String, duration: float = 2.0) -> void:
	if _toast_lbl == null:
		return
	_toast_lbl.text = txt
	_toast_lbl.visible = true
	_toast_timer = duration


func update_hud(player: RCCar, total_laps: int, race_elapsed: float) -> void:
	if player == null or not _hud_root.visible:
		return

	var rank_colors: Array[Color] = [
		Color(0.95, 0.72, 0.08),
		Color(0.55, 0.60, 0.68),
		Color(0.78, 0.46, 0.22),
		Color(0.52, 0.48, 0.46),
	]
	var r_idx := clampi(player.race_rank - 1, 0, 3)
	_rank_lbl.text = "%d. PLATZ" % player.race_rank
	_rank_lbl.add_theme_color_override("font_color", rank_colors[r_idx])

	var shown_lap := mini(player.current_lap, total_laps)
	_lap_lbl.text = "Runde %d / %d" % [shown_lap, total_laps]
	_time_lbl.text = "Zeit: %s" % _fmt_time(race_elapsed)
	if player.best_lap_time < 9000.0:
		_best_lbl.text = "Beste: %s" % _fmt_time(player.best_lap_time)
	else:
		_best_lbl.text = "Beste: --:--.-"

	# Power-up display
	match player.held_powerup:
		RCCar.Powerup.NONE:
			_item_icon.texture = PaperStyle.get_sticker_texture("power_mystery", Color(0.76, 0.74, 0.70))
			_item_name_lbl.text = "Leer"
		RCCar.Powerup.TURBO:
			_item_icon.texture = PaperStyle.get_sticker_texture("power_turbo", Color(1.0, 0.80, 0.14))
			_item_name_lbl.text = "Blitz-Turbo!"
		RCCar.Powerup.SHOCK:
			_item_icon.texture = PaperStyle.get_sticker_texture("power_shock", Color(0.28, 0.82, 1.0))
			_item_name_lbl.text = "Funk-Schock!"
		RCCar.Powerup.SPRING:
			_item_icon.texture = PaperStyle.get_sticker_texture("power_spring", Color(0.32, 0.88, 0.42))
			_item_name_lbl.text = "Papier-Feder!"
		RCCar.Powerup.OIL:
			_item_icon.texture = PaperStyle.get_sticker_texture("power_oil", Color(0.56, 0.22, 0.78))
			_item_name_lbl.text = "Farbklecks!"

	# Toy RC Speedometer (scaled to fun RC km/h!)
	var horiz_spd := Vector2(player.velocity.x, player.velocity.z).length()
	var kmh := int(round(horiz_spd * 3.2))
	_speed_lbl.text = "%d km/h" % kmh
	_speed_bar.value = clampf((horiz_spd / 32.0) * 100.0, 0.0, 100.0)


func _fmt_time(sec: float) -> String:
	var mins := int(sec) / 60
	var rem := sec - float(mins * 60)
	return "%02d:%04.1f" % [mins, rem]
