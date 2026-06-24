extends CanvasLayer
class_name GameHud

@export var game_state_path: NodePath

var _energy_label: Label
var _iron_label: Label
var _carbon_label: Label
var _storage_label: Label
var _power_label: Label
var _base_label: Label
var _wave_label: Label
var _message_label: Label
var _result_label: Label

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
	_base_label = _make_label("基地：--")
	_wave_label = _make_label("波次：准备")
	_message_label = _make_label("E 采集，B 塔，C 墙，V 发电机，M 采矿机，R 旋转，X 拆除")
	_result_label = _make_label("")
	_result_label.add_theme_font_size_override("font_size", 30)

	root.add_child(_energy_label)
	root.add_child(_iron_label)
	root.add_child(_carbon_label)
	root.add_child(_storage_label)
	root.add_child(_power_label)
	root.add_child(_base_label)
	root.add_child(_wave_label)
	root.add_child(_message_label)
	root.add_child(_result_label)

	var game_state := get_node(game_state_path)
	game_state.resource_changed.connect(_on_resource_changed)
	game_state.storage_changed.connect(_on_storage_changed)
	game_state.power_changed.connect(_on_power_changed)
	game_state.base_health_changed.connect(_on_base_health_changed)
	game_state.wave_status_changed.connect(_on_wave_status_changed)
	game_state.message_changed.connect(_on_message_changed)
	game_state.game_finished.connect(_on_game_finished)

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

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

func _on_base_health_changed(current_health: int, max_health: int) -> void:
	_base_label.text = "基地：%d / %d" % [current_health, max_health]

func _on_wave_status_changed(wave: int, status: String, countdown: float, enemies_alive: int) -> void:
	if status == "准备":
		_wave_label.text = "波次：%d  准备 %.0f 秒  敌人 %d" % [wave + 1, countdown, enemies_alive]
	else:
		_wave_label.text = "波次：%d  %s  敌人 %d" % [wave, status, enemies_alive]

func _on_message_changed(text: String) -> void:
	_message_label.text = text

func _on_game_finished(victory: bool, reason: String) -> void:
	_result_label.text = ("胜利：" if victory else "失败：") + reason
