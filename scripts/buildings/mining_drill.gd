extends Node2D
class_name MiningDrill

@export var max_health: int = 120
@export var power_usage: int = 8
@export var production_interval: float = 2.0
@export var production_amount: int = 5
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(76, 76)

var health: int
var is_destroyed: bool = false
var target_deposit: Node
var mined_resource_id: String = "energy"
var _game_state: Node
var _timer: float = 0.0
var _is_registered: bool = false
var _research_bonuses: Dictionary = {}

func _ready() -> void:
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	health = max_health
	_game_state = _get_game_state()
	_register_power()
	queue_redraw()

func setup_deposit(deposit: Node) -> void:
	target_deposit = deposit
	if target_deposit != null:
		mined_resource_id = target_deposit.resource_id
	queue_redraw()

func _process(delta: float) -> void:
	if is_destroyed or _game_state == null or _game_state.is_finished:
		return
	if target_deposit == null or not is_instance_valid(target_deposit) or not target_deposit.can_collect():
		return
	if not _game_state.has_stable_power():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var amount: int = target_deposit.extract_amount(production_amount)
	if amount > 0:
		_game_state.add_resource(mined_resource_id, amount)
	_timer = production_interval

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_destroyed = true
		_unregister_power()
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

func apply_research_bonus(tech_id: String) -> void:
	if _research_bonuses.has(tech_id):
		return
	_research_bonuses[tech_id] = true
	if tech_id == "mining_efficiency":
		production_amount += 3
		production_interval = max(production_interval - 0.25, 0.8)
	queue_redraw()

func _exit_tree() -> void:
	_unregister_power()

func _register_power() -> void:
	if _game_state != null and not _is_registered:
		_game_state.register_power_consumer(power_usage)
		_is_registered = true

func _unregister_power() -> void:
	if _game_state != null and _is_registered:
		_game_state.unregister_power_consumer(power_usage)
		_is_registered = false

func _get_game_state() -> Node:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	if states.is_empty():
		return null
	return states[0]

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
	else:
		draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.7, 0.72, 0.74, 1.0), true)
	var status_color := Color(0.3, 1.0, 0.55, 0.2)
	if _game_state != null and not _game_state.has_stable_power():
		status_color = Color(1.0, 0.2, 0.1, 0.2)
	draw_circle(Vector2.ZERO, 40.0, status_color)
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-30, -52), Vector2(60, 5)), Color(0.08, 0.02, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-30, -52), Vector2(60 * health_ratio, 5)), Color(0.2, 0.95, 0.55, 0.95))
