extends Node2D
class_name SentryTower

@export var attack_range: float = 300.0
@export var damage: int = 10
@export var fire_interval: float = 0.45
@export var max_health: int = 120
@export var max_level: int = 3
@export var projectile_scene: PackedScene
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(76, 76)

var _cooldown: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT
var health: int
var is_destroyed: bool = false
var level: int = 1
var _research_bonuses: Dictionary = {}

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
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_fire_at(target)
	_cooldown = fire_interval

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
	damage += 8
	attack_range += 45.0
	fire_interval = max(fire_interval - 0.08, 0.24)
	max_health += 60
	health = max_health
	queue_redraw()
	return true

func apply_research_bonus(tech_id: String) -> void:
	if _research_bonuses.has(tech_id):
		return
	_research_bonuses[tech_id] = true
	if tech_id == "tower_overdrive":
		damage += 6
		attack_range += 40.0
		fire_interval = max(fire_interval - 0.05, 0.2)
	queue_redraw()

func _fire_at(target: Node2D) -> void:
	_aim_direction = global_position.direction_to(target.global_position)
	queue_redraw()
	if projectile_scene == null:
		target.take_damage(damage)
		return
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position + _aim_direction * 38.0
	get_tree().current_scene.add_child(projectile)
	projectile.configure(target, damage)

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
		draw_line(Vector2.ZERO, _aim_direction * 46.0, Color(0.75, 0.96, 1.0, 0.9), 5.0)
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(0.2, 0.75, 1.0, 0.12), 2.0)
		if health_ratio < 1.0:
			draw_rect(Rect2(Vector2(-30, -52), Vector2(60, 5)), Color(0.08, 0.02, 0.02, 0.8))
			draw_rect(Rect2(Vector2(-30, -52), Vector2(60 * health_ratio, 5)), Color(0.2, 0.95, 0.55, 0.95))
		if health_ratio < 0.45:
			draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.16, 0.08, 0.18))
		for index in range(level):
			draw_circle(Vector2(-16 + index * 16, 44), 4.0, Color(0.5, 0.95, 1.0, 0.95))
		return
	draw_circle(Vector2.ZERO, 34.0, Color(0.06, 0.10, 0.13, 0.95))
	draw_circle(Vector2.ZERO, 24.0, Color(0.18, 0.55, 0.86, 0.95))
	draw_line(Vector2.ZERO, _aim_direction * 48.0, Color(0.75, 0.96, 1.0, 0.95), 12.0)
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(0.2, 0.75, 1.0, 0.16), 2.0)

func _game_is_finished() -> bool:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	return not states.is_empty() and states[0].is_finished
