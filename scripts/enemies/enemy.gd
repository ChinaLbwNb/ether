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

var enemy_type_id: String = "scout"
var display_name: String = "异虫"
var role: String = "scout"
var armor: int = 0
var target_priority: String = "nearest"
var tint_color: Color = Color(0.95, 0.15, 0.12, 0.95)
var health: int
var shield: int = 0
var max_shield: int = 0
var base_core
var attack_target
var is_dead: bool = false
var _attack_cooldown: float = 0.0
var _shield_regen_cooldown: float = 0.0
var _base_speed: float = 75.0
var _slow_amount: float = 0.0
var _slow_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	queue_redraw()

func setup(target_base) -> void:
	base_core = target_base

func setup_type(profile: Dictionary, wave: int = 1, strength_mult: float = 1.0) -> void:
	enemy_type_id = str(profile.get("id", enemy_type_id))
	display_name = str(profile.get("name", display_name))
	role = str(profile.get("role", role))
	var base_health: int = int(profile.get("health", max_health)) + max(wave - 1, 0) * int(profile.get("health_growth", 6))
	max_health = int(float(base_health) * strength_mult)
	move_speed = float(profile.get("speed", move_speed))
	var base_damage: int = int(profile.get("damage", damage)) + int(floor(float(wave - 1) * 1.5))
	damage = int(float(base_damage) * strength_mult)
	attack_range = float(profile.get("attack_range", attack_range))
	attack_interval = float(profile.get("attack_interval", attack_interval))
	armor = int(profile.get("armor", armor))
	target_priority = str(profile.get("target_priority", target_priority))
	tint_color = Color.html(str(profile.get("color", "#ef5b52")))
	max_shield = int(float(int(profile.get("shield", 0))) * strength_mult)
	shield = max_shield
	_base_speed = move_speed
	health = max_health
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _game_is_finished():
		velocity = Vector2.ZERO
		return
	if is_dead or base_core == null or not is_instance_valid(base_core):
		return
	_update_slow(delta)
	_update_shield_regen(delta)
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

func _update_slow(delta: float) -> void:
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_amount = 0.0
			move_speed = _base_speed

func _update_shield_regen(delta: float) -> void:
	if max_shield <= 0:
		return
	if _shield_regen_cooldown > 0.0:
		_shield_regen_cooldown -= delta
		return
	if shield < max_shield:
		shield = min(shield + int(float(max_shield) * 0.02 * delta * 60.0), max_shield)
		queue_redraw()

func _find_attack_target() -> Node2D:
	if target_priority == "core" and base_core != null and is_instance_valid(base_core):
		return base_core as Node2D
	if target_priority == "buildings":
		var building_target: Node2D = _find_nearest_target_in_group("build_blockers")
		if building_target != null:
			return building_target
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

func _find_nearest_target_in_group(group_name: String) -> Node2D:
	var best_target: Node2D = null
	var best_distance: float = INF
	for target in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var distance := global_position.distance_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = target
	return best_target

func take_damage(amount: int) -> void:
	if is_dead:
		return
	var final_damage: int = maxi(amount - armor, 1)
	_shield_regen_cooldown = 3.0
	if shield > 0:
		if final_damage <= shield:
			shield -= final_damage
			queue_redraw()
			return
		else:
			final_damage -= shield
			shield = 0
	health = max(health - final_damage, 0)
	queue_redraw()
	if health == 0:
		is_dead = true
		remove_from_group("enemies")
		died.emit()
		_spawn_death_effect()
		queue_free()

func apply_slow(amount: float, duration: float) -> void:
	if amount > _slow_amount or _slow_timer <= 0.0:
		_slow_amount = amount
		move_speed = _base_speed * (1.0 - amount)
	_slow_timer = max(_slow_timer, duration)

func _spawn_death_effect() -> void:
	var managers: Array = get_tree().get_nodes_in_group("effect_manager")
	if managers.is_empty():
		return
	var manager = managers[0]
	if manager.has_method("spawn_death"):
		manager.spawn_death(global_position, tint_color)

func _draw() -> void:
	var ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false, tint_color)
		draw_rect(Rect2(Vector2(-26, -42), Vector2(52, 5)), Color(0.12, 0.02, 0.02, 0.85))
		draw_rect(Rect2(Vector2(-26, -42), Vector2(52 * ratio, 5)), Color(0.95, 0.15, 0.12, 0.95))
		if max_shield > 0:
			var shield_ratio: float = float(shield) / float(max_shield)
			draw_rect(Rect2(Vector2(-26, -49), Vector2(52, 4)), Color(0.05, 0.1, 0.25, 0.85))
			draw_rect(Rect2(Vector2(-26, -49), Vector2(52 * shield_ratio, 4)), Color(0.3, 0.6, 1.0, 0.95))
		if role == "elite":
			draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 48, Color(0.7, 0.35, 1.0, 0.85), 3.0)
		return
	draw_circle(Vector2.ZERO, 28.0, tint_color)
	draw_circle(Vector2.ZERO, 17.0, Color(0.95, 0.24, 0.18, 0.95))
	draw_rect(Rect2(Vector2(-26, -42), Vector2(52, 5)), Color(0.12, 0.02, 0.02, 0.85))
	draw_rect(Rect2(Vector2(-26, -42), Vector2(52 * ratio, 5)), Color(0.95, 0.15, 0.12, 0.95))
	if max_shield > 0:
		var shield_ratio: float = float(shield) / float(max_shield)
		draw_rect(Rect2(Vector2(-26, -49), Vector2(52, 4)), Color(0.05, 0.1, 0.25, 0.85))
		draw_rect(Rect2(Vector2(-26, -49), Vector2(52 * shield_ratio, 4)), Color(0.3, 0.6, 1.0, 0.95))
	if _slow_amount > 0.0:
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 48, Color(0.3, 0.7, 1.0, 0.4), 2.0)

func _game_is_finished() -> bool:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	return not states.is_empty() and states[0].is_finished
