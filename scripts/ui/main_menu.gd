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
	start_game.emit(_selected_mode, config)

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
