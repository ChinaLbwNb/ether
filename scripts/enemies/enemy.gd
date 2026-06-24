extends CharacterBody2D
class_name Enemy

signal died

@export var max_health: int = 40
@export var move_speed: float = 75.0
@export var damage: int = 10
@export var attack_range: float = 78.0
@export var attack_interval: float = 1.0
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(64, 64)

var health: int
var base_core
var attack_target
var is_dead: bool = false
var _attack_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	queue_redraw()

func setup(target_base) -> void:
	base_core = target_base

func _physics_process(delta: float) -> void:
	if _game_is_finished():
		velocity = Vector2.ZERO
		return
	if is_dead or base_core == null or not is_instance_valid(base_core):
		return
	_attack_cooldown -= delta
	attack_target = _find_attack_target()
	if attack_target == null:
		return
	var distance := global_position.distance_to(attack_target.global_position)
	if distance > attack_range:
		velocity = global_position.direction_to(attack_target.global_position) * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if _attack_cooldown <= 0.0:
			attack_target.take_damage(damage)
			_attack_cooldown = attack_interval

func _find_attack_target() -> Node2D:
	var best_target: Node2D = null
	var best_distance: float = INF
	for target in get_tree().get_nodes_in_group("enemy_targets"):
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var distance := global_position.distance_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = target
	if best_target != null:
		return best_target
	return base_core as Node2D

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_dead = true
		remove_from_group("enemies")
		died.emit()
		queue_free()

func _draw() -> void:
	var ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
		draw_rect(Rect2(Vector2(-26, -42), Vector2(52, 5)), Color(0.12, 0.02, 0.02, 0.85))
		draw_rect(Rect2(Vector2(-26, -42), Vector2(52 * ratio, 5)), Color(0.95, 0.15, 0.12, 0.95))
		return
	draw_circle(Vector2.ZERO, 28.0, Color(0.55, 0.06, 0.12, 0.95))
	draw_circle(Vector2.ZERO, 17.0, Color(0.95, 0.24, 0.18, 0.95))
	draw_rect(Rect2(Vector2(-26, -42), Vector2(52 * ratio, 5)), Color(0.95, 0.15, 0.12, 0.95))

func _game_is_finished() -> bool:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	return not states.is_empty() and states[0].is_finished
