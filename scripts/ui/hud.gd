extends CanvasLayer
class_name GameHud

@export var game_state_path: NodePath
@export var player_path: NodePath
@export var research_manager_path: NodePath
@export var map_manager_path: NodePath

var _energy_label: Label
var _iron_label: Label
var _carbon_label: Label
var _storage_label: Label
var _power_label: Label
var _mech_health_label: Label
var _mech_shield_label: Label
var _mech_energy_label: Label
var _weapon_label: Label
var _map_label: Label
var _base_label: Label
var _wave_label: Label
var _wave_warning_label: Label
var _message_label: Label
var _result_label: Label
var _research_label: Label
var _research_panel: PanelContainer
var _research_list: VBoxContainer
var _research_manager: Node
var _map_manager: Node

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
	_map_label = _make_label("区域：主基地")
	_base_label = _make_label("基地：--")
	_wave_label = _make_label("波次：准备")
	_wave_warning_label = _make_label("预警：等待侦测")
	_research_label = _make_label("科技：无")
	_message_label = _make_label("E 采集，N 研究站，K 科技，Q 切武器，Space 冲刺")
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
	root.add_child(_map_label)
	root.add_child(_research_label)
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
	_map_manager = get_node_or_null(map_manager_path)
	if _map_manager != null:
		_map_manager.map_changed.connect(_on_map_changed)
	_build_research_panel()

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

func _on_map_changed(_map_id: String, _map_name: String, _biome: String) -> void:
	if _map_manager != null:
		_map_label.text = _map_manager.get_map_status_text()

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
