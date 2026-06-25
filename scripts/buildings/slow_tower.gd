extends Node2D
class_name SlowTower

@export var attack_range: float = 280.0
@export var damage_per_second: int = 4
@export var slow_amount: float = 0.35
@export var slow_duration: float = 0.25
@export var max_health: int = 130
@export var max_level: int = 3
@export var visual_size: Vector2 = Vector2(78, 78)

var health: int
var is_destroyed: bool = false
var level: int = 1
var _research_bonuses: Dictionary = {}
var _pulse_phase: float = 0.0
var _enemies_in_range: int = 0

func _ready() -> void:
	add_to_group("defense_towers")
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	health = max_health
	queue_redraw()

func _process(delta: float) -> void:
	if _game_is_finished():
		return
	_pulse_phase += delta * 3.0
	_apply_slow_field(delta)
	queue_redraw()

func _apply_slow_field(delta: float) -> void:
	_enemies_in_range = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= attack_range:
			_enemies_in_range += 1
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_amount, slow_duration)
			if damage_per_second > 0 and enemy.has_method("take_damage"):
				var dmg: int = int(float(damage_per_second) * delta)
				enemy.take_damage(max(dmg, 1))

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_destroyed = true
		remove_from_group("defense_towers")
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

func can_upgrade() -> bool:
	return not is_destroyed and level < max_level

func get_upgrade_cost(base_cost: int) -> int:
	return base_cost * level

func upgrade() -> bool:
	if not can_upgrade():
		return false
	level += 1
	slow_amount = min(slow_amount + 0.08, 0.65)
	attack_range += 35.0
	damage_per_second += 3
	max_health += 55
	health = max_health
	queue_redraw()
	return true

func apply_research_bonus(tech_id: String) -> void:
	if _research_bonuses.has(tech_id):
		return
	_research_bonuses[tech_id] = true
	if tech_id == "generator_efficiency":
		slow_amount = min(slow_amount + 0.05, 0.7)
		attack_range += 25.0
	queue_redraw()

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	draw_circle(Vector2.ZERO, 36.0, Color(0.05, 0.08, 0.15, 0.95))
	draw_circle(Vector2.ZERO, 26.0, Color(0.2, 0.4, 0.85, 0.9))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.7, 1.0, 0.8))
	var pulse_radius := attack_range * (0.85 + 0.15 * sin(_pulse_phase))
	var pulse_alpha := 0.12 + 0.08 * sin(_pulse_phase)
	draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 96, Color(0.3, 0.6, 1.0, pulse_alpha), 3.0)
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(0.3, 0.6, 1.0, 0.1), 2.0)
	if _enemies_in_range > 0:
		draw_circle(Vector2.ZERO, 30.0, Color(0.3, 0.7, 1.0, 0.2))
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-31, -53), Vector2(62, 5)), Color(0.08, 0.02, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-31, -53), Vector2(62 * health_ratio, 5)), Color(0.3, 0.7, 1.0, 0.95))
	if health_ratio < 0.45:
		draw_circle(Vector2.ZERO, 38.0, Color(1.0, 0.16, 0.08, 0.18))
	for index in range(level):
		draw_circle(Vector2(-16 + index * 16, 45), 4.0, Color(0.4, 0.8, 1.0, 0.95))

func _game_is_finished() -> bool:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	return not states.is_empty() and states[0].is_finished
