extends Control
class_name MainMenu

signal start_game(mode_id: String, config: Dictionary)

@export var game_mode_manager_path: NodePath

var _mode_manager: Node
var _selected_mode: String = "campaign"
var _selected_difficulty: String = "normal"
var _title_label: Label
var _mode_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _start_button: Button
var _leaderboard_button: Button
var _leaderboard_panel: PanelContainer
var _leaderboard_list: VBoxContainer
var _config_panel: PanelContainer
var _survival_config_panel: VBoxContainer
var _sandbox_config_panel: VBoxContainer
var _sandbox_res_mult: float = 1.0
var _sandbox_enemy_str: float = 1.0
var _sandbox_wave_int: float = 1.0
var _sandbox_res_buttons: Array = []
var _sandbox_enemy_buttons: Array = []
var _sandbox_wave_buttons: Array = []
var _sandbox_toggle_unlimited: Button
var _sandbox_toggle_all_tech: Button
var _sandbox_toggle_enemies: Button
var _sandbox_toggle_death: Button

func _ready() -> void:
	_mode_manager = get_node_or_null(game_mode_manager_path)
	_build_menu()
	_update_mode_selection()

func _build_menu() -> void:
	var center_container := CenterContainer.new()
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	add_child(center_container)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	main_vbox.custom_minimum_size = Vector2(480, 0)
	center_container.add_child(main_vbox)

	_title_label = Label.new()
	_title_label.text = "ETHER"
	_title_label.add_theme_font_size_override("font_size", 72)
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	var subtitle := Label.new()
	subtitle.text = "选择游戏模式"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 12)
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(mode_hbox)

	var modes := [
		{"id": "campaign", "name": "战役模式", "desc": "跟随主线任务，探索世界"},
		{"id": "survival", "name": "生存模式", "desc": "抵御无限敌潮，挑战最高波次"},
		{"id": "sandbox", "name": "沙盒模式", "desc": "自由调参，建造测试基地"}
	]
	for mode_info in modes:
		var btn := Button.new()
		btn.text = str(mode_info["name"])
		btn.custom_minimum_size = Vector2(140, 50)
		btn.tooltip_text = str(mode_info["desc"])
		btn.pressed.connect(_on_mode_selected.bind(str(mode_info["id"])))
		_mode_buttons[str(mode_info["id"])] = btn
		mode_hbox.add_child(btn)

	_build_config_panel(main_vbox)

	_leaderboard_button = Button.new()
	_leaderboard_button.text = "排行榜"
	_leaderboard_button.custom_minimum_size = Vector2(200, 40)
	_leaderboard_button.pressed.connect(_toggle_leaderboard)
	main_vbox.add_child(_leaderboard_button)

	_start_button = Button.new()
	_start_button.text = "开始游戏"
	_start_button.custom_minimum_size = Vector2(200, 60)
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.pressed.connect(_on_start_pressed)
	main_vbox.add_child(_start_button)

	_build_leaderboard_panel()

func _build_config_panel(parent: VBoxContainer) -> void:
	_config_panel = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	panel_style.border_color = Color(0.6, 0.85, 1.0, 0.3)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_config_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(_config_panel)

	var config_margin := MarginContainer.new()
	config_margin.add_theme_constant_override("margin_left", 16)
	config_margin.add_theme_constant_override("margin_right", 16)
	config_margin.add_theme_constant_override("margin_top", 12)
	config_margin.add_theme_constant_override("margin_bottom", 12)
	_config_panel.add_child(config_margin)

	var config_vbox := VBoxContainer.new()
	config_vbox.add_theme_constant_override("separation", 10)
	config_margin.add_child(config_vbox)

	_survival_config_panel = VBoxContainer.new()
	_survival_config_panel.add_theme_constant_override("separation", 8)
	config_vbox.add_child(_survival_config_panel)
	var surv_title := Label.new()
	surv_title.text = "生存模式设置"
	surv_title.add_theme_font_size_override("font_size", 18)
	surv_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	_survival_config_panel.add_child(surv_title)

	var diff_label := Label.new()
	diff_label.text = "难度选择："
	diff_label.add_theme_font_size_override("font_size", 16)
	_survival_config_panel.add_child(diff_label)

	var diff_hbox := HBoxContainer.new()
	diff_hbox.add_theme_constant_override("separation", 8)
	_survival_config_panel.add_child(diff_hbox)

	var difficulties := [
		{"id": "easy", "name": "简单", "desc": "敌人较弱，适合新手"},
		{"id": "normal", "name": "普通", "desc": "标准难度"},
		{"id": "hard", "name": "困难", "desc": "敌人更强，挑战自我"}
	]
	for diff_info in difficulties:
		var btn := Button.new()
		btn.text = str(diff_info["name"])
		btn.tooltip_text = str(diff_info["desc"])
		btn.pressed.connect(_on_difficulty_selected.bind(str(diff_info["id"])))
		_difficulty_buttons[str(diff_info["id"])] = btn
		diff_hbox.add_child(btn)

	var resource_info := Label.new()
	resource_info.text = "初始资源：能量 80 | 铁 30 | 碳 20"
	resource_info.add_theme_font_size_override("font_size", 14)
	resource_info.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.9))
	_survival_config_panel.add_child(resource_info)

	_sandbox_config_panel = VBoxContainer.new()
	_sandbox_config_panel.add_theme_constant_override("separation", 8)
	_sandbox_config_panel.visible = false
	config_vbox.add_child(_sandbox_config_panel)
	var sand_title := Label.new()
	sand_title.text = "沙盒模式设置"
	sand_title.add_theme_font_size_override("font_size", 18)
	sand_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	_sandbox_config_panel.add_child(sand_title)

	var sand_desc := Label.new()
	sand_desc.text = "自由建造，测试基地设计"
	sand_desc.add_theme_font_size_override("font_size", 14)
	sand_desc.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.9))
	_sandbox_config_panel.add_child(sand_desc)

	var res_mult_label := Label.new()
	res_mult_label.text = "资源倍率：1.0x"
	res_mult_label.name = "ResMultLabel"
	res_mult_label.add_theme_font_size_override("font_size", 14)
	_sandbox_config_panel.add_child(res_mult_label)
	var res_mult_hbox := HBoxContainer.new()
	res_mult_hbox.add_theme_constant_override("separation", 6)
	_sandbox_config_panel.add_child(res_mult_hbox)
	var res_mult_values := [0.5, 1.0, 2.0, 5.0, 10.0]
	_sandbox_res_mult = 1.0
	for mult in res_mult_values:
		var btn := Button.new()
		btn.text = "%.1fx" % mult
		btn.pressed.connect(_on_sandbox_res_mult.bind(float(mult)))
		_sandbox_res_buttons.append(btn)
		res_mult_hbox.add_child(btn)

	var enemy_str_label := Label.new()
	enemy_str_label.text = "敌人强度：1.0x"
	enemy_str_label.name = "EnemyStrLabel"
	enemy_str_label.add_theme_font_size_override("font_size", 14)
	_sandbox_config_panel.add_child(enemy_str_label)
	var enemy_str_hbox := HBoxContainer.new()
	enemy_str_hbox.add_theme_constant_override("separation", 6)
	_sandbox_config_panel.add_child(enemy_str_hbox)
	var enemy_str_values := [0.5, 1.0, 1.5, 2.0, 3.0]
	_sandbox_enemy_str = 1.0
	for mult in enemy_str_values:
		var btn := Button.new()
		btn.text = "%.1fx" % mult
		btn.pressed.connect(_on_sandbox_enemy_str.bind(float(mult)))
		_sandbox_enemy_buttons.append(btn)
		enemy_str_hbox.add_child(btn)

	var wave_int_label := Label.new()
	wave_int_label.text = "波次间隔：1.0x"
	wave_int_label.name = "WaveIntLabel"
	wave_int_label.add_theme_font_size_override("font_size", 14)
	_sandbox_config_panel.add_child(wave_int_label)
	var wave_int_hbox := HBoxContainer.new()
	wave_int_hbox.add_theme_constant_override("separation", 6)
	_sandbox_config_panel.add_child(wave_int_hbox)
	var wave_int_values := [0.5, 1.0, 1.5, 2.0]
	_sandbox_wave_int = 1.0
	for mult in wave_int_values:
		var btn := Button.new()
		btn.text = "%.1fx" % mult
		btn.pressed.connect(_on_sandbox_wave_int.bind(float(mult)))
		_sandbox_wave_buttons.append(btn)
		wave_int_hbox.add_child(btn)

	var toggle_unlimited := Button.new()
	toggle_unlimited.text = "无限资源：关"
	toggle_unlimited.name = "ToggleUnlimited"
	toggle_unlimited.toggle_mode = true
	toggle_unlimited.pressed.connect(_on_sandbox_toggle_unlimited)
	_sandbox_toggle_unlimited = toggle_unlimited
	_sandbox_config_panel.add_child(toggle_unlimited)

	var toggle_all_tech := Button.new()
	toggle_all_tech.text = "全科技解锁：关"
	toggle_all_tech.name = "ToggleAllTech"
	toggle_all_tech.toggle_mode = true
	toggle_all_tech.pressed.connect(_on_sandbox_toggle_all_tech)
	_sandbox_toggle_all_tech = toggle_all_tech
	_sandbox_config_panel.add_child(toggle_all_tech)

	var toggle_enemies := Button.new()
	toggle_enemies.text = "敌人开关：开"
	toggle_enemies.name = "ToggleEnemies"
	toggle_enemies.toggle_mode = true
	toggle_enemies.button_pressed = true
	toggle_enemies.pressed.connect(_on_sandbox_toggle_enemies)
	_sandbox_toggle_enemies = toggle_enemies
	_sandbox_config_panel.add_child(toggle_enemies)

	var toggle_death := Button.new()
	toggle_death.text = "死亡惩罚：开"
	toggle_death.name = "ToggleDeath"
	toggle_death.toggle_mode = true
	toggle_death.button_pressed = true
	toggle_death.pressed.connect(_on_sandbox_toggle_death)
	_sandbox_toggle_death = toggle_death
	_sandbox_config_panel.add_child(toggle_death)

func _build_leaderboard_panel() -> void:
	_leaderboard_panel = PanelContainer.new()
	_leaderboard_panel.visible = false
	_leaderboard_panel.position = Vector2(0, 0)
	_leaderboard_panel.custom_minimum_size = Vector2(320, 400)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	panel_style.border_color = Color(0.6, 0.85, 1.0, 0.4)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_leaderboard_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_leaderboard_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_leaderboard_panel.add_child(margin)

	_leaderboard_list = VBoxContainer.new()
	_leaderboard_list.add_theme_constant_override("separation", 6)
	margin.add_child(_leaderboard_list)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_toggle_leaderboard)
	_leaderboard_list.add_child(close_btn)

func _on_mode_selected(mode_id: String) -> void:
	_selected_mode = mode_id
	_update_mode_selection()

func _on_difficulty_selected(difficulty_id: String) -> void:
	_selected_difficulty = difficulty_id
	_update_difficulty_selection()

func _update_mode_selection() -> void:
	for mode_id in _mode_buttons.keys():
		var btn: Button = _mode_buttons[mode_id]
		btn.disabled = (mode_id == _selected_mode)
	_survival_config_panel.visible = (_selected_mode == "survival")
	_sandbox_config_panel.visible = (_selected_mode == "sandbox")
	_update_difficulty_selection()

func _update_difficulty_selection() -> void:
	for diff_id in _difficulty_buttons.keys():
		var btn: Button = _difficulty_buttons[diff_id]
		btn.disabled = (diff_id == _selected_difficulty)

func _on_start_pressed() -> void:
	var config: Dictionary = {"difficulty": _selected_difficulty}
	if _selected_mode == "sandbox":
		config["resource_multiplier"] = _sandbox_res_mult
		config["enemy_strength"] = _sandbox_enemy_str
		config["wave_interval"] = _sandbox_wave_int
		config["unlimited_resources"] = _sandbox_toggle_unlimited.button_pressed
		config["all_tech_unlocked"] = _sandbox_toggle_all_tech.button_pressed
		config["enemies_enabled"] = _sandbox_toggle_enemies.button_pressed
		config["death_penalty_enabled"] = _sandbox_toggle_death.button_pressed
	start_game.emit(_selected_mode, config)

func _on_sandbox_res_mult(mult: float) -> void:
	_sandbox_res_mult = mult
	for btn in _sandbox_res_buttons:
		btn.disabled = false
	var label := _sandbox_config_panel.get_node("ResMultLabel")
	label.text = "资源倍率：%.1fx" % mult

func _on_sandbox_enemy_str(mult: float) -> void:
	_sandbox_enemy_str = mult
	var label := _sandbox_config_panel.get_node("EnemyStrLabel")
	label.text = "敌人强度：%.1fx" % mult

func _on_sandbox_wave_int(mult: float) -> void:
	_sandbox_wave_int = mult
	var label := _sandbox_config_panel.get_node("WaveIntLabel")
	label.text = "波次间隔：%.1fx" % mult

func _on_sandbox_toggle_unlimited() -> void:
	var on: bool = _sandbox_toggle_unlimited.button_pressed
	_sandbox_toggle_unlimited.text = "无限资源：" + ("开" if on else "关")

func _on_sandbox_toggle_all_tech() -> void:
	var on: bool = _sandbox_toggle_all_tech.button_pressed
	_sandbox_toggle_all_tech.text = "全科技解锁：" + ("开" if on else "关")

func _on_sandbox_toggle_enemies() -> void:
	var on: bool = _sandbox_toggle_enemies.button_pressed
	_sandbox_toggle_enemies.text = "敌人开关：" + ("开" if on else "关")

func _on_sandbox_toggle_death() -> void:
	var on: bool = _sandbox_toggle_death.button_pressed
	_sandbox_toggle_death.text = "死亡惩罚：" + ("开" if on else "关")

func _toggle_leaderboard() -> void:
	_leaderboard_panel.visible = not _leaderboard_panel.visible
	if _leaderboard_panel.visible:
		_refresh_leaderboard()

func _refresh_leaderboard() -> void:
	if _leaderboard_list == null:
		return
	var children_to_remove: Array = []
	for i in range(1, _leaderboard_list.get_child_count()):
		children_to_remove.append(_leaderboard_list.get_child(i))
	for child in children_to_remove:
		child.queue_free()
	var title := Label.new()
	title.text = "生存模式排行榜"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	_leaderboard_list.add_child(title)
	if _mode_manager == null:
		return
	var scores: Array = _mode_manager.get_leaderboard("survival")
	if scores.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无记录"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.8))
		_leaderboard_list.add_child(empty_label)
		return
	for i in range(scores.size()):
		var score: Dictionary = scores[i]
		var entry := Label.new()
		var wave: int = int(score.get("wave", 0))
		var kills: int = int(score.get("kills", 0))
		var time_val: float = float(score.get("time", 0))
		var date_str: String = str(score.get("date", ""))
		var mins: int = int(time_val) / 60
		var secs: int = int(time_val) % 60
		entry.text = "%d. 第%d波 | 击杀%d | %02d:%02d" % [i + 1, wave, kills, mins, secs]
		entry.add_theme_font_size_override("font_size", 14)
		entry.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
		_leaderboard_list.add_child(entry)
