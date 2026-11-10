extends Node

enum State {
	MENU,
	COUNTDOWN,
	RACING,
	FINISHED,
}

const AI_NAMES: Array[String] = ["Maxi", "Fritzi", "Rocco"]

var state: State = State.MENU
var selected_class: int = 0
var selected_paint: int = 0
var selected_track: int = 0
var total_laps: int = 3

var _initialized: bool = false
var _player: RCCar
var _ai_cars: Array[RCCar] = []
var _all_racers: Array[RCCar] = []
var _checkpoints: Array[RaceCheckpoint] = []
var _start_transforms: Array[Transform3D] = []
var _waypoints: PackedVector3Array = PackedVector3Array()
var _sway_nodes: Array[Node3D] = []

var _track_container: Node3D
var _racers_container: Node3D
var _camera_gimbal: Node3D
var _world_env: WorldEnvironment
var _sfx: SFXManager
var _ui: RaceUI

var _countdown_timer: float = 0.0
var _last_countdown_int: int = -1
var _race_elapsed: float = 0.0
var _banner_clear_timer: float = 0.0
var _breeze_time: float = 0.0

var _car_scene: PackedScene = preload("res://rc_car.tscn")
var _checkpoint_scene: PackedScene = preload("res://checkpoint.tscn")


func _ready() -> void:
	_ensure_input_bindings()

	var world := get_parent() as Node3D
	_camera_gimbal = world.get_node_or_null("CameraGimbal") as Node3D
	_track_container = world.get_node_or_null("TrackContainer") as Node3D
	_racers_container = world.get_node_or_null("RacersContainer") as Node3D

	# Setup Paper Mario Sky & Sun Environment
	_setup_environment(world)

	# Sound Effects Synthesizer (child of RaceManager -> never busy)
	_sfx = SFXManager.new()
	_sfx.name = "SFXManager"
	add_child(_sfx)

	# Player + 3 AI Racers (added into already-ready RacersContainer)
	_player = world.get_node_or_null("RCCar") as RCCar
	if _player == null:
		_player = _car_scene.instantiate() as RCCar
		_player.name = "RCCar"
		_racers_container.add_child(_player)

	_player.is_ai = false
	_player.racer_name = "Du"
	_player.sfx = _sfx
	_player.hazard_parent = _track_container
	_all_racers.append(_player)

	var lane_offsets: Array[float] = [-1.9, 1.9, -0.7]
	for i in range(3):
		var ai := _car_scene.instantiate() as RCCar
		ai.name = "AIRacer_%d" % (i + 1)
		ai.is_ai = true
		ai.racer_name = AI_NAMES[i]
		ai.car_number = i + 2
		ai.ai_lane_offset = lane_offsets[i]
		ai.hazard_parent = _track_container
		_racers_container.add_child(ai)
		_ai_cars.append(ai)
		_all_racers.append(ai)

	if _camera_gimbal != null:
		_camera_gimbal.set("target", _player)

	# UI Layer (child of RaceManager -> never busy)
	_ui = RaceUI.new()
	_ui.name = "RaceUI"
	add_child(_ui)
	_ui.start_race_requested.connect(_on_start_race_requested)
	_ui.restart_race_requested.connect(_on_restart_race_requested)
	_ui.open_menu_requested.connect(_enter_menu)
	_ui.car_class_changed.connect(_on_car_class_changed)
	_ui.paint_changed.connect(_on_paint_changed)
	_ui.track_changed.connect(_on_track_changed)
	_ui.laps_changed.connect(func(l: int): total_laps = l)

	_rebuild_track_and_grid()
	_enter_menu()
	_initialized = true


func _setup_environment(world: Node3D) -> void:
	_world_env = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env != null:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = PaperStyle.SKY_BLUE
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.96, 0.94, 0.99)
		env.ambient_light_energy = 0.50
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_world_env.environment = env

	var sun := world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(1.0, 0.97, 0.90)
		sun.light_energy = 1.15
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 135.0


func _ensure_input_bindings() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_backward", [KEY_S, KEY_DOWN])
	_bind_keys("steer_left", [KEY_A, KEY_LEFT])
	_bind_keys("steer_right", [KEY_D, KEY_RIGHT])
	_bind_keys("drift", [KEY_SPACE])
	_bind_keys("use_powerup", [KEY_SHIFT, KEY_E, KEY_CTRL])
	_bind_keys("respawn", [KEY_R])
	_bind_keys("toggle_camera", [KEY_C])
	_bind_keys("toggle_mute", [KEY_M])


func _bind_keys(action: String, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _rebuild_track_and_grid() -> void:
	var data := TrackBuilder.build_track(_track_container, selected_track, _checkpoint_scene)
	_checkpoints.clear()
	for cp in data["checkpoints"]:
		var rcp := cp as RaceCheckpoint
		rcp.racer_entered.connect(_on_checkpoint_entered)
		_checkpoints.append(rcp)

	_start_transforms.clear()
	for xf in data["start_transforms"]:
		_start_transforms.append(xf as Transform3D)

	_waypoints = data["waypoints"]
	_sway_nodes.clear()
	for sn in data["sway_nodes"]:
		_sway_nodes.append(sn as Node3D)

	if _camera_gimbal != null:
		_camera_gimbal.set("track_limits", data["limits"])

	if _world_env != null and _world_env.environment != null:
		_world_env.environment.background_color = data["sky_color"]

	_refresh_racer_lineup()


func _refresh_racer_lineup() -> void:
	_player.apply_class_and_paint(selected_class, selected_paint, 1)
	_player.waypoints = _waypoints

	var used_paints: Array[int] = [selected_paint]
	for i in range(_ai_cars.size()):
		var ai := _ai_cars[i]
		var cls := (selected_class + i + 1) % 4
		var pnt := (selected_paint + i + 1) % PaperStyle.CAR_PAINTS.size()
		while used_paints.has(pnt):
			pnt = (pnt + 1) % PaperStyle.CAR_PAINTS.size()
		used_paints.append(pnt)
		ai.apply_class_and_paint(cls, pnt, i + 2)
		ai.waypoints = _waypoints

	_place_cars_on_grid()


func _place_cars_on_grid() -> void:
	if _start_transforms.size() < _all_racers.size():
		return
	for i in range(_all_racers.size()):
		var r := _all_racers[i]
		r.reset_for_race(_start_transforms[i])
		r.next_checkpoint_id = 1 if _checkpoints.size() > 1 else 0
		r.race_can_move = false
	_update_checkpoint_visibility()


func _enter_menu() -> void:
	state = State.MENU
	_place_cars_on_grid()
	if _camera_gimbal != null:
		_camera_gimbal.set("showcase_mode", true)
	_ui.show_menu()
	_sfx.update_motor(0.0, false, false, false)


func _on_car_class_changed(cls_id: int) -> void:
	selected_class = cls_id
	_refresh_racer_lineup()
	_sfx.play("checkpoint", 1.1, -9.0)


func _on_paint_changed(p_id: int) -> void:
	selected_paint = p_id
	_refresh_racer_lineup()
	_sfx.play("checkpoint", 1.25, -9.0)


func _on_track_changed(t_id: int) -> void:
	selected_track = t_id
	_rebuild_track_and_grid()
	_sfx.play("pickup", 1.0, -8.0)


func _on_start_race_requested() -> void:
	_start_countdown()


func _on_restart_race_requested() -> void:
	_rebuild_track_and_grid()
	_start_countdown()


func _start_countdown() -> void:
	state = State.COUNTDOWN
	_place_cars_on_grid()
	if _camera_gimbal != null:
		_camera_gimbal.set("showcase_mode", false)
		_camera_gimbal.global_position = _player.global_position

	_countdown_timer = 3.2
	_last_countdown_int = 4
	_race_elapsed = 0.0
	_ui.show_hud()
	_ui.set_center_banner("3", Color(1.0, 0.36, 0.24))
	_sfx.play("beep_low")


func _process(delta: float) -> void:
	if not _initialized:
		return

	_animate_paper_breeze(delta)
	_handle_global_shortcuts()

	if _banner_clear_timer > 0.0:
		_banner_clear_timer -= delta
		if _banner_clear_timer <= 0.0:
			_ui.set_center_banner("")

	match state:
		State.MENU:
			if Input.is_action_just_pressed("ui_accept"):
				_start_countdown()

		State.COUNTDOWN:
			_countdown_timer -= delta
			var c_num := int(ceil(_countdown_timer))
			if c_num != _last_countdown_int and c_num >= 1 and c_num <= 3:
				_last_countdown_int = c_num
				var cols: Array[Color] = [Color.WHITE, Color(0.32, 0.90, 0.42), Color(1.0, 0.84, 0.18), Color(1.0, 0.36, 0.24)]
				_ui.set_center_banner(str(c_num), cols[c_num])
				_sfx.play("beep_low", 1.0 + float(3 - c_num) * 0.08)

			if _countdown_timer <= 0.0:
				state = State.RACING
				for r in _all_racers:
					r.race_can_move = true
					r.lap_start_time = 0.0
				_ui.set_center_banner("LOS!", Color(0.30, 0.96, 0.42))
				_banner_clear_timer = 1.0
				_sfx.play("beep_go")
			_update_rankings_and_rubberband()
			_ui.update_hud(_player, total_laps, 0.0)

		State.RACING:
			_race_elapsed += delta
			_update_rankings_and_rubberband()
			_ui.update_hud(_player, total_laps, _race_elapsed)

		State.FINISHED:
			_race_elapsed += delta
			if Input.is_action_just_pressed("ui_accept"):
				_on_restart_race_requested()
			elif Input.is_action_just_pressed("ui_cancel"):
				_enter_menu()


func _handle_global_shortcuts() -> void:
	if Input.is_action_just_pressed("toggle_camera") and _camera_gimbal != null:
		if _camera_gimbal.has_method("cycle_camera_mode"):
			var mode_name: String = _camera_gimbal.call("cycle_camera_mode")
			_ui.show_toast("🎥 Kamera: " + mode_name)

	if Input.is_action_just_pressed("toggle_mute"):
		var is_muted := _sfx.toggle_mute()
		_ui.show_toast("🔇 Ton aus" if is_muted else "🔊 Ton an")

	if state == State.RACING or state == State.COUNTDOWN:
		if Input.is_action_just_pressed("ui_cancel"):
			_enter_menu()


func _animate_paper_breeze(delta: float) -> void:
	_breeze_time += delta
	for i in range(_sway_nodes.size()):
		var n := _sway_nodes[i]
		if is_instance_valid(n):
			n.rotation.z = sin(_breeze_time * 2.1 + float(i) * 0.9) * 0.045


func _update_rankings_and_rubberband() -> void:
	if _checkpoints.is_empty():
		return

	var sorted: Array[RCCar] = _all_racers.duplicate()
	sorted.sort_custom(func(a: RCCar, b: RCCar) -> bool:
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		if a.checkpoints_passed != b.checkpoints_passed:
			return a.checkpoints_passed > b.checkpoints_passed
		var cp_a := _get_checkpoint_pos(a.next_checkpoint_id)
		var cp_b := _get_checkpoint_pos(b.next_checkpoint_id)
		return a.global_position.distance_squared_to(cp_a) < b.global_position.distance_squared_to(cp_b)
	)

	for rank_i in range(sorted.size()):
		sorted[rank_i].race_rank = rank_i + 1

	for i in range(_ai_cars.size()):
		var ai := _ai_cars[i]
		var skills: Array[float] = [0.99, 0.95, 0.91]
		var base_skill: float = skills[i]
		var diff_cp := _player.checkpoints_passed - ai.checkpoints_passed
		if diff_cp >= 2:
			ai.ai_skill = base_skill + 0.08
		elif diff_cp <= -2:
			ai.ai_skill = base_skill - 0.07
		else:
			ai.ai_skill = base_skill


func _get_checkpoint_pos(cp_id: int) -> Vector3:
	for cp in _checkpoints:
		if cp.checkpoint_id == cp_id:
			return cp.global_position
	return Vector3.ZERO


func _update_checkpoint_visibility() -> void:
	for cp in _checkpoints:
		if cp.checkpoint_id == _player.next_checkpoint_id:
			cp.show_visuals()
		else:
			cp.hide_visuals()


func _on_checkpoint_entered(racer: RCCar, entered_id: int) -> void:
	if state != State.RACING or racer.finished:
		return
	if entered_id != racer.next_checkpoint_id:
		return

	racer.checkpoints_passed += 1
	var num_cp := _checkpoints.size()

	if entered_id == 0:
		var lap_dur := _race_elapsed - racer.lap_start_time
		if lap_dur > 2.0 and lap_dur < racer.best_lap_time:
			racer.best_lap_time = lap_dur
		racer.lap_start_time = _race_elapsed

		if racer.current_lap >= total_laps:
			racer.finished = true
			racer.finish_time = _race_elapsed
			if racer == _player:
				_finish_player_race()
			return
		else:
			racer.current_lap += 1
			racer.next_checkpoint_id = 1 if num_cp > 1 else 0
			if racer == _player:
				_sfx.play("lap")
				if racer.current_lap == total_laps:
					_ui.set_center_banner("LETZTE RUNDE!", Color(1.0, 0.78, 0.16))
					_banner_clear_timer = 1.4
	else:
		racer.next_checkpoint_id = (entered_id + 1) % num_cp
		if racer == _player:
			_sfx.play("checkpoint", 1.0 + float(entered_id) * 0.04, -8.5)

	if racer == _player:
		_update_checkpoint_visibility()


func _finish_player_race() -> void:
	state = State.FINISHED
	_update_rankings_and_rubberband()
	_sfx.play("win")

	var ranked: Array[RCCar] = _all_racers.duplicate()
	ranked.sort_custom(func(a: RCCar, b: RCCar) -> bool:
		return a.race_rank < b.race_rank
	)
	_ui.show_finish(ranked, _player.best_lap_time)


func _on_out_of_bounds_area_body_entered(body: Node3D) -> void:
	if body is RCCar:
		(body as RCCar).respawn()
