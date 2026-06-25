extends Node2D
class_name RiftPortal

signal charge_updated(percent: float)
signal fully_charged

@export var max_health: int = 500
@export var max_charge: float = 100.0
@export var charge_per_second: float = 2.0
@export var power_drain: int = 10
@export var defense_start_charge_percent: float = 30.0
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(120, 140)
@export var portal_color: Color = Color(0.4, 0.2, 0.9, 0.95)

var health: int
var is_destroyed: bool = false
var current_charge: float = 0.0
var _pulse_phase: float = 0.0
var _is_activated: bool = false
var _defense_started: bool = false

func _ready() -> void:
	add_to_group("rift_portal")
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	health = max_health
	_notify_quest_built()
	queue_redraw()

func _process(delta: float) -> void:
	if is_destroyed or _game_is_finished():
		return
	_pulse_phase += delta * 2.5
	if _has_sufficient_power() and current_charge < max_charge:
		var charge_amount: float = charge_per_second * delta
		current_charge = min(current_charge + charge_amount, max_charge)
		charge_updated.emit(current_charge)
		_notify_quest_charge()
		var charge_pct: float = get_charge_percent()
		if not _defense_started and charge_pct >= defense_start_charge_percent:
			_defense_started = true
			_start_final_defense()
		if current_charge >= max_charge:
			fully_charged.emit()
			_is_activated = true
	queue_redraw()

func _has_sufficient_power() -> bool:
	var game_state: Node = _get_game_state()
	if game_state == null:
		return false
	if not game_state.has_method("get_power_supply") or not game_state.has_method("get_power_demand"):
		return true
	var supply: int = game_state.get_power_supply()
	var demand: int = game_state.get_power_demand()
	return supply >= demand + power_drain

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_destroyed = true
		remove_from_group("enemy_targets")
		remove_from_group("repairable_buildings")
		remove_from_group("build_blockers")
		queue_free()

func repair(amount: int) -> void:
	if is_destroyed:
		return
	health = min(health + amount, max_health)
	queue_redraw()

func is_damaged() -> bool:
	return not is_destroyed and health < max_health

func get_charge_percent() -> float:
	if max_charge <= 0:
		return 0.0
	return current_charge / max_charge * 100.0

func _notify_quest_built() -> void:
	var quest_managers: Array = get_tree().get_nodes_in_group("quest_manager")
	if quest_managers.is_empty():
		return
	var qm: Node = quest_managers[0]
	if qm.has_method("notify_rift_built"):
		qm.notify_rift_built()

func _notify_quest_charge() -> void:
	var quest_managers: Array = get_tree().get_nodes_in_group("quest_manager")
	if quest_managers.is_empty():
		return
	var qm: Node = quest_managers[0]
	if qm.has_method("notify_rift_charge_changed"):
		qm.notify_rift_charge_changed(get_charge_percent())

func _start_final_defense() -> void:
	var wave_managers: Array = get_tree().get_nodes_in_group("wave_manager")
	if wave_managers.is_empty():
		return
	var wm: Node = wave_managers[0]
	if wm.has_method("start_final_defense"):
		wm.start_final_defense()

func _get_game_state() -> Node:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	if not states.is_empty():
		return states[0]
	return null

func _game_is_finished() -> bool:
	var gs: Node = _get_game_state()
	return gs != null and gs.is_finished

func _draw() -> void:
	if is_destroyed:
		return
	var health_ratio: float = float(health) / float(max_health)
	var charge_ratio: float = current_charge / max_charge
	var base_radius: float = visual_size.x * 0.45
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
	else:
		var portal_height: float = visual_size.y * 0.5
		draw_circle(Vector2(0, portal_height * 0.15), base_radius * 0.9, Color(0.05, 0.03, 0.12, 0.9))
		draw_arc(Vector2(0, portal_height * 0.15), base_radius, 0.0, PI, 48, Color(portal_color.r, portal_color.g, portal_color.b, 0.8), 4.0)
		var inner_radius: float = base_radius * 0.75
		var charge_color: Color = Color(
			portal_color.r * 0.8,
			portal_color.g * 0.6,
			portal_color.b,
			0.6 + charge_ratio * 0.35
		)
		for i in range(3):
			var offset: float = sin(_pulse_phase + float(i) * 2.0) * 4.0
			var ring_radius: float = inner_radius * (0.5 + float(i) * 0.2 + charge_ratio * 0.1)
			draw_arc(Vector2(0, portal_height * 0.15 + offset), ring_radius, 0.0, PI, 36, charge_color, 2.5 + float(i) * 0.5)
		if charge_ratio > 0:
			var fill_radius: float = inner_radius * 0.6 * charge_ratio
			draw_circle(Vector2(0, portal_height * 0.15), fill_radius, Color(portal_color.r, portal_color.g, portal_color.b, 0.5 + charge_ratio * 0.4))
		var leg_color: Color = Color(0.3, 0.25, 0.35, 0.9)
		draw_rect(Rect2(Vector2(-base_radius * 0.9, portal_height * 0.4), Vector2(base_radius * 0.25, portal_height * 0.5)), leg_color)
		draw_rect(Rect2(Vector2(base_radius * 0.65, portal_height * 0.4), Vector2(base_radius * 0.25, portal_height * 0.5)), leg_color)
		draw_rect(Rect2(Vector2(-base_radius, portal_height * 0.85), Vector2(base_radius * 2, 14)), Color(0.25, 0.2, 0.3, 0.95))
	if charge_ratio > 0 and asset_texture != null:
		var pulse_size: float = base_radius * 0.8 * (0.9 + 0.1 * sin(_pulse_phase))
		draw_circle(Vector2.ZERO, pulse_size, Color(portal_color.r, portal_color.g, portal_color.b, 0.2 + charge_ratio * 0.2))
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-base_radius, -visual_size.y * 0.55), Vector2(base_radius * 2, 7)), Color(0.08, 0.02, 0.02, 0.85))
		draw_rect(Rect2(Vector2(-base_radius, -visual_size.y * 0.55), Vector2(base_radius * 2 * health_ratio, 7)), Color(0.95, 0.2, 0.3, 0.95))
	var bar_width: float = base_radius * 2.0
	draw_rect(Rect2(Vector2(-base_radius, -visual_size.y * 0.4), Vector2(bar_width, 8)), Color(0.1, 0.05, 0.2, 0.85))
	draw_rect(Rect2(Vector2(-base_radius, -visual_size.y * 0.4), Vector2(bar_width * charge_ratio, 8)), Color(portal_color.r, portal_color.g, portal_color.b, 0.95))
