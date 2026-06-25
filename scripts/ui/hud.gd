extends CanvasLayer
class_name GameHud

@export var game_state_path: NodePath
@export var player_path: NodePath
@export var research_manager_path: NodePath
@export var map_manager_path: NodePath
@export var quest_manager_path: NodePath
@export var survival_manager_path: NodePath

var _energy_label: Label
var _iron_label: Label
var _carbon_label: Label
var _storage_label: Label
var _power_label: Label
var _mech_health_label: Label
var _mech_shield_label: Label
var _mech_energy_label: Label
var _weapon_label: Label
var _base_label: Label
var _wave_label: Label
var _wave_warning_label: Label
var _message_label: Label
var _result_label: Label
var _research_label: Label
var _zone_label: Label
var _research_panel: PanelContainer
var _research_list: VBoxContainer
var _research_manager: Node
var _quest_panel: PanelContainer
var _quest_title_label: Label
var _quest_progress_label: Label
var _quest_desc_label: Label
var _quest_manager: Node
var _survival_panel: PanelContainer
var _survival_wave_label: Label
var _survival_time_label: Label
var _survival_kills_label: Label
var _survival_manager: Node

func _ready() -> void:
	var root := VBoxContainer.new()
	root.position = Vector2(18, 18)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_energy_label = _make_label("能量：0")
	_iron_label = _make_label("铁：0")
	_carbon_label = _make_label("碳：0")
	_storage_label = _make_label("仓储：0 / 0")
	_power_label = _make_label("电力：0 / 0")
	_mech_health_label = _make_label("机甲：--")
	_mech_shield_label = _make_label("护盾：--")
	_mech_energy_label = _make_label("机甲能量：--")
	_weapon_label = _make_label("武器：电磁步枪 Lv.1")
	_base_label = _make_label("基地：--")
	_wave_label = _make_label("波次：准备")
	_wave_warning_label = _make_label("预警：等待侦测")
	_research_label = _make_label("科技：无")
	_zone_label = _make_label("区域：主基地")
	_message_label = _make_label("E 采集/传送，N 研究站，K 科技，Q 切武器，Space 冲刺")
	_result_label = _make_label("")
	_result_label.add_theme_font_size_override("font_size", 30)

	root.add_child(_energy_label)
	root.add_child(_iron_label)
	root.add_child(_carbon_label)
	root.add_child(_storage_label)
	root.add_child(_power_label)
	root.add_child(_mech_health_label)
	root.add_child(_mech_shield_label)
	root.add_child(_mech_energy_label)
	root.add_child(_weapon_label)
	root.add_child(_research_label)
	root.add_child(_zone_label)
	root.add_child(_base_label)
	root.add_child(_wave_label)
	root.add_child(_wave_warning_label)
	root.add_child(_message_label)
	root.add_child(_result_label)

	var game_state := get_node(game_state_path)
	game_state.resource_changed.connect(_on_resource_changed)
	game_state.storage_changed.connect(_on_storage_changed)
	game_state.power_changed.connect(_on_power_changed)
	game_state.base_health_changed.connect(_on_base_health_changed)
	game_state.wave_status_changed.connect(_on_wave_status_changed)
	game_state.wave_warning_changed.connect(_on_wave_warning_changed)
	game_state.message_changed.connect(_on_message_changed)
	game_state.game_finished.connect(_on_game_finished)
	var player: Node = get_node(player_path)
	if player.has_signal("mech_status_changed"):
		player.mech_status_changed.connect(_on_mech_status_changed)
	_research_manager = get_node_or_null(research_manager_path)
	if _research_manager != null:
		_research_manager.research_changed.connect(_on_research_changed)
		_research_manager.station_count_changed.connect(_on_station_count_changed)
	var map_manager: Node = get_node_or_null(map_manager_path)
	if map_manager != null and map_manager.has_signal("zone_changed"):
		map_manager.zone_changed.connect(_on_zone_changed)
	_quest_manager = get_node_or_null(quest_manager_path)
	if _quest_manager != null:
		if _quest_manager.has_signal("main_quest_updated"):
			_quest_manager.main_quest_updated.connect(_on_main_quest_updated)
		if _quest_manager.has_signal("quest_completed"):
			_quest_manager.quest_completed.connect(_on_quest_completed)
	_survival_manager = get_node_or_null(survival_manager_path)
	if _survival_manager != null:
		if _survival_manager.has_signal("survival_started"):
			_survival_manager.survival_started.connect(_on_survival_started)
		if _survival_manager.has_signal("stats_updated"):
			_survival_manager.stats_updated.connect(_on_survival_stats_updated)
	_build_research_panel()
	_build_quest_panel()
	_build_survival_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_research"):
		_toggle_research_panel()

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _build_research_panel() -> void:
	_research_panel = PanelContainer.new()
	_research_panel.visible = false
	_research_panel.position = Vector2(760, 18)
	_research_panel.custom_minimum_size = Vector2(380, 420)
	add_child(_research_panel)

	_research_list = VBoxContainer.new()
	_research_list.add_theme_constant_override("separation", 8)
	_research_panel.add_child(_research_list)
	_refresh_research_panel()

func _toggle_research_panel() -> void:
	_research_panel.visible = not _research_panel.visible
	if _research_panel.visible:
		_refresh_research_panel()

func _refresh_research_panel() -> void:
	if _research_list == null:
		return
	for child in _research_list.get_children():
		child.queue_free()
	var title: Label = _make_label("科技研究")
	title.add_theme_font_size_override("font_size", 24)
	_research_list.add_child(title)
	if _research_manager == null:
		_research_list.add_child(_make_label("缺少科技管理器"))
		return
	_research_list.add_child(_make_label("研究站：%d" % _research_manager.station_count))
	_research_list.add_child(_make_label(_research_manager.get_unlocked_text()))
	for tech_id in _research_manager.tech_definitions.keys():
		var tech: Dictionary = _research_manager.tech_definitions[tech_id]
		var button: Button = Button.new()
		button.text = "%s  [%s]" % [str(tech.get("name", tech_id)), _format_cost(tech.get("costs", {}))]
		button.tooltip_text = str(tech.get("description", ""))
		button.disabled = _research_manager.has_technology(str(tech_id)) or not _requirements_visible(tech)
		button.pressed.connect(_on_research_button_pressed.bind(str(tech_id)))
		_research_list.add_child(button)

func _format_cost(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in costs.keys():
		parts.append("%s %d" % [str(resource_id), int(costs[resource_id])])
	return "、".join(parts)

func _requirements_visible(tech: Dictionary) -> bool:
	for required_id in tech.get("requires", []):
		if not _research_manager.has_technology(str(required_id)):
			return false
	return true

func _on_research_button_pressed(tech_id: String) -> void:
	if _research_manager != null:
		_research_manager.try_research(tech_id)
	_refresh_research_panel()

func _on_resource_changed(resource_id: String, amount: int) -> void:
	if resource_id == "energy":
		_energy_label.text = "能量：%d" % amount
	elif resource_id == "iron":
		_iron_label.text = "铁：%d" % amount
	elif resource_id == "carbon":
		_carbon_label.text = "碳：%d" % amount

func _on_storage_changed(current_total: int, max_total: int) -> void:
	_storage_label.text = "仓储：%d / %d" % [current_total, max_total]

func _on_power_changed(supply: int, demand: int) -> void:
	_power_label.text = "电力：%d / %d" % [supply, demand]
	if supply < demand:
		_power_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18, 1.0))
	else:
		_power_label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))

func _on_mech_status_changed(health: int, max_health: int, shield: int, max_shield: int, mech_energy: int, max_energy: int, weapon_name: String, weapon_level: int) -> void:
	_mech_health_label.text = "机甲：%d / %d" % [health, max_health]
	_mech_shield_label.text = "护盾：%d / %d" % [shield, max_shield]
	_mech_energy_label.text = "机甲能量：%d / %d" % [mech_energy, max_energy]
	_weapon_label.text = "武器：%s Lv.%d" % [weapon_name, weapon_level]

func _on_research_changed(_unlocked_ids: Array[String]) -> void:
	if _research_manager != null:
		_research_label.text = _research_manager.get_unlocked_text()
	_refresh_research_panel()

func _on_station_count_changed(_count: int) -> void:
	_refresh_research_panel()

func _on_base_health_changed(current_health: int, max_health: int) -> void:
	_base_label.text = "基地：%d / %d" % [current_health, max_health]

func _on_wave_status_changed(wave: int, status: String, countdown: float, enemies_alive: int) -> void:
	if status == "准备":
		_wave_label.text = "波次：%d  准备 %.0f 秒  敌人 %d" % [wave + 1, countdown, enemies_alive]
	else:
		_wave_label.text = "波次：%d  %s  敌人 %d" % [wave, status, enemies_alive]

func _on_wave_warning_changed(text: String) -> void:
	_wave_warning_label.text = text

func _on_message_changed(text: String) -> void:
	_message_label.text = text

func _on_game_finished(victory: bool, reason: String) -> void:
	_result_label.text = ("胜利：" if victory else "失败：") + reason

func _on_zone_changed(zone_id: String, zone_name: String) -> void:
	if zone_name == "":
		_zone_label.text = "区域：荒野"
	else:
		_zone_label.text = "区域：%s" % zone_name

func _build_quest_panel() -> void:
	_quest_panel = PanelContainer.new()
	_quest_panel.position = Vector2(18, 370)
	_quest_panel.custom_minimum_size = Vector2(320, 0)
	add_child(_quest_panel)
	var quest_vbox := VBoxContainer.new()
	quest_vbox.add_theme_constant_override("separation", 4)
	_quest_panel.add_child(quest_vbox)
	var header_label: Label = _make_label("★ 当前任务")
	header_label.add_theme_font_size_override("font_size", 22)
	quest_vbox.add_child(header_label)
	_quest_title_label = _make_label("暂无任务")
	_quest_title_label.add_theme_font_size_override("font_size", 18)
	quest_vbox.add_child(_quest_title_label)
	_quest_progress_label = _make_label("进度：--")
	quest_vbox.add_child(_quest_progress_label)
	_quest_desc_label = _make_label("")
	_quest_desc_label.add_theme_font_size_override("font_size", 14)
	_quest_desc_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 1.0))
	quest_vbox.add_child(_quest_desc_label)
	_refresh_quest_panel()

func _refresh_quest_panel() -> void:
	if _quest_manager == null:
		return
	if not _quest_manager.has_method("get_current_main_quest"):
		return
	var main_quest: Dictionary = _quest_manager.get_current_main_quest()
	if main_quest.is_empty():
		_quest_title_label.text = "任务全部完成！"
		_quest_progress_label.text = ""
		_quest_desc_label.text = ""
		return
	var quest_data: Dictionary = main_quest.get("data", {})
	var quest_name: String = str(quest_data.get("name", "未知任务"))
	var quest_desc: String = str(quest_data.get("description", ""))
	var progress: float = float(main_quest.get("progress", 0.0))
	_quest_title_label.text = quest_name
	_quest_progress_label.text = "进度：%d%%" % int(progress * 100)
	_quest_desc_label.text = quest_desc

func _on_main_quest_updated(_quest_id: String, _name: String, _progress: float) -> void:
	_refresh_quest_panel()

func _on_quest_completed(_quest_id: String, _quest_data: Dictionary) -> void:
	_refresh_quest_panel()

func _build_survival_panel() -> void:
	_survival_panel = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	panel_style.border_color = Color(0.6, 0.85, 1.0, 0.4)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_survival_panel.add_theme_stylebox_override("panel", panel_style)
	var survival_margin: MarginContainer = MarginContainer.new()
	survival_margin.add_theme_constant_override("margin_left", 14)
	survival_margin.add_theme_constant_override("margin_right", 14)
	survival_margin.add_theme_constant_override("margin_top", 10)
	survival_margin.add_theme_constant_override("margin_bottom", 10)
	_survival_panel.add_child(survival_margin)
	var survival_vbox: VBoxContainer = VBoxContainer.new()
	survival_vbox.add_theme_constant_override("separation", 4)
	survival_margin.add_child(survival_vbox)
	var title_label: Label = _make_label("⚔ 生存模式")
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	survival_vbox.add_child(title_label)
	_survival_wave_label = _make_label("波次：0")
	_survival_wave_label.add_theme_font_size_override("font_size", 15)
	survival_vbox.add_child(_survival_wave_label)
	_survival_time_label = _make_label("时间：00:00")
	_survival_time_label.add_theme_font_size_override("font_size", 15)
	survival_vbox.add_child(_survival_time_label)
	_survival_kills_label = _make_label("击杀：0")
	_survival_kills_label.add_theme_font_size_override("font_size", 15)
	survival_vbox.add_child(_survival_kills_label)
	_survival_panel.position = Vector2(18, 380)
	_survival_panel.visible = false
	add_child(_survival_panel)

func _on_survival_started() -> void:
	if _survival_panel != null:
		_survival_panel.visible = true
	if _quest_panel != null:
		_quest_panel.visible = false

func _on_survival_stats_updated(wave: int, time: float, kills: int) -> void:
	if _survival_wave_label != null:
		_survival_wave_label.text = "波次：%d" % wave
	if _survival_time_label != null and _survival_manager != null and _survival_manager.has_method("format_time"):
		_survival_time_label.text = "时间：%s" % _survival_manager.format_time(time)
	if _survival_kills_label != null:
		_survival_kills_label.text = "击杀：%d" % kills
