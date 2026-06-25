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
@export var path_recheck_interval: float = 0.75
@export var waypoint_reach_distance: float = 20.0

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
var _nav_manager: Node
var _current_path: Array[Vector2] = []
var _path_index: int = 0
var _path_recheck_timer: float = 0.0
var _last_target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	var nav_managers: Array = get_tree().get_nodes_in_group("navigation_manager")
	if not nav_managers.is_empty():
		_nav_manager = nav_managers[0]
	queue_redraw()

func setup(target_base) -> void:
	base_core = target_base
	_request_new_path()

func setup_type(profile: Dictionary, wave: int = 1, strength_mult: float = 1.0, type_id: String = "") -> void:
	if type_id != "":
		enemy_type_id = type_id
	else:
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
	if profile.has("texture"):
		asset_texture = load(profile.texture)
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
	_path_recheck_timer -= delta
	attack_target = _find_attack_target()
	if attack_target == null:
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(attack_target.global_position)
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if _attack_cooldown <= 0.0:
			attack_target.take_damage(damage)
			_attack_cooldown = attack_interval
		return
	var move_target: Vector2 = _get_movement_target(attack_target.global_position)
	var dir: Vector2 = Vector2.ZERO
	if move_target != global_position:
		dir = global_position.direction_to(move_target)
	velocity = dir * move_speed
	var collision: KinematicCollision2D = move_and_slide()
	if _path_recheck_timer <= 0.0 or _last_target_position.distance_to(attack_target.global_position) > 60.0:
		_request_new_path()

func _get_movement_target(target_pos: Vector2) -> Vector2:
	if _current_path.is_empty() or _path_index >= _current_path.size():
		return target_pos
	if _nav_manager == null:
		return target_pos
	if _path_index >= _current_path.size() - 1:
		var final_dist: float = global_position.distance_to(target_pos)
		if final_dist < waypoint_reach_distance * 2.0:
			return target_pos
	var waypoint: Vector2 = _current_path[_path_index]
	if global_position.distance_to(waypoint) < waypoint_reach_distance:
		_path_index += 1
		if _path_index < _current_path.size():
			waypoint = _current_path[_path_index]
		else:
			return target_pos
	return waypoint

func _request_new_path() -> void:
	_path_recheck_timer = path_recheck_interval
	if attack_target != null and is_instance_valid(attack_target):
		_last_target_position = attack_target.global_position
	else:
		_last_target_position = base_core.global_position
	if _nav_manager == null:
		var nav_managers: Array = get_tree().get_nodes_in_group("navigation_manager")
		if not nav_managers.is_empty():
			_nav_manager = nav_managers[0]
	if _nav_manager != null and _nav_manager.has_method("find_path"):
		_current_path = _nav_manager.find_path(global_position, _last_target_position)
		_path_index = 0
	else:
		_current_path = [_last_target_position]
		_path_index = 0

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
