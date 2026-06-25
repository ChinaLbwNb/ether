extends Node2D
class_name LaserTower

@export var attack_range: float = 340.0
@export var damage_per_second: int = 25
@export var max_health: int = 140
@export var max_level: int = 3
@export var visual_size: Vector2 = Vector2(80, 80)

var _target: Node2D = null
var _target_lost_timer: float = 0.0
var health: int
var is_destroyed: bool = false
var level: int = 1
var _research_bonuses: Dictionary = {}
var _laser_beam_alpha: float = 0.0

func _ready() -> void:
	add_to_group("defense_towers")
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	health = max_health
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _game_is_finished():
		return
	var new_target := _find_target()
	if new_target != _target:
		_target = new_target
		if _target != null:
			_laser_beam_alpha = 1.0
	if _target == null:
		_laser_beam_alpha = max(_laser_beam_alpha - delta * 4.0, 0.0)
		queue_redraw()
		return
	if not is_instance_valid(_target) or _target.is_dead:
		_target = null
		_laser_beam_alpha = 0.0
		queue_redraw()
		return
	var dmg: int = int(float(damage_per_second) * delta)
	_target.take_damage(max(dmg, 1))
	_laser_beam_alpha = 0.85 + randf() * 0.15
	queue_redraw()

func _find_target() -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance := attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	return closest_enemy

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
	damage_per_second += 15
	attack_range += 40.0
	max_health += 70
	health = max_health
	queue_redraw()
	return true

func apply_research_bonus(tech_id: String) -> void:
	if _research_bonuses.has(tech_id):
		return
	_research_bonuses[tech_id] = true
	if tech_id == "tower_overdrive":
		damage_per_second += int(float(damage_per_second) * 0.2)
		attack_range += 30.0
	queue_redraw()

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	draw_circle(Vector2.ZERO, 38.0, Color(0.08, 0.05, 0.12, 0.95))
	draw_circle(Vector2.ZERO, 28.0, Color(0.5, 0.2, 0.85, 0.9))
	draw_circle(Vector2.ZERO, 18.0, Color(0.8, 0.4, 1.0, 0.8))
	if _target != null and is_instance_valid(_target) and _laser_beam_alpha > 0.0:
		var target_dir := global_position.direction_to(_target.global_position)
		var beam_color := Color(0.9, 0.4, 1.0, _laser_beam_alpha)
		var glow_color := Color(0.7, 0.2, 0.9, _laser_beam_alpha * 0.4)
		var local_target := (_target.global_position - global_position)
		draw_line(Vector2.ZERO, local_target, glow_color, 10.0)
		draw_line(Vector2.ZERO, local_target, beam_color, 4.0)
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(0.7, 0.3, 1.0, 0.12), 2.0)
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-32, -54), Vector2(64, 5)), Color(0.08, 0.02, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-32, -54), Vector2(64 * health_ratio, 5)), Color(0.8, 0.4, 1.0, 0.95))
	if health_ratio < 0.45:
		draw_circle(Vector2.ZERO, 36.0, Color(1.0, 0.16, 0.08, 0.18))
	for index in range(level):
		draw_circle(Vector2(-16 + index * 16, 46), 4.0, Color(0.9, 0.5, 1.0, 0.95))

func _game_is_finished() -> bool:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	return not states.is_empty() and states[0].is_finished
