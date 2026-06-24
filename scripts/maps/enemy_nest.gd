extends Node2D
class_name EnemyNest

signal nest_destroyed
signal enemy_spawned(enemy)

@export var max_health: int = 200
@export var spawn_interval: float = 8.0
@export var max_enemies_around: int = 4
@export var spawn_radius: float = 60.0
@export var enemy_type_id: String = "scout"
@export var nest_color: Color = Color(0.6, 0.1, 0.7, 0.95)
@export var display_name: String = "敌人巢穴"
@export var enemy_scene: PackedScene
@export var base_path: NodePath

var health: int
var is_destroyed: bool = false
var _spawn_cooldown: float = 0.0
var _base_core: Node2D
var _pulse_phase: float = 0.0

func _ready() -> void:
	add_to_group("enemy_nests")
	add_to_group("enemy_targets")
	add_to_group("build_blockers")
	health = max_health
	_spawn_cooldown = spawn_interval * 0.5
	_base_core = get_node_or_null(base_path)
	if _base_core == null:
		var bases: Array = get_tree().get_nodes_in_group("base_core")
		if not bases.is_empty():
			_base_core = bases[0]
	queue_redraw()

func _process(delta: float) -> void:
	if is_destroyed:
		return
	_pulse_phase += delta * 1.5
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_try_spawn_enemy()
		_spawn_cooldown = spawn_interval
	queue_redraw()

func _try_spawn_enemy() -> void:
	if enemy_scene == null:
		return
	var nearby_count: int = _count_nearby_enemies()
	if nearby_count >= max_enemies_around:
		return
	var enemy := enemy_scene.instantiate()
	var angle: float = randf() * TAU
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * spawn_radius
	enemy.global_position = global_position + offset
	get_parent().add_child(enemy)
	if enemy.has_method("setup") and _base_core != null:
		enemy.setup(_base_core)
	if enemy.has_method("setup_type"):
		var enemy_types: Dictionary = _load_enemy_types()
		if enemy_types.has(enemy_type_id):
			var wave: int = _get_current_wave()
			enemy.setup_type(enemy_types[enemy_type_id], wave)
	enemy_spawned.emit(enemy)

func _count_nearby_enemies() -> int:
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) <= spawn_radius * 3.0:
			count += 1
	return count

func _load_enemy_types() -> Dictionary:
	var result: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://data/enemies/enemy_types.json", FileAccess.READ)
	if file == null:
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return result
	for item in parsed:
		if item is Dictionary and item.has("id"):
			result[str(item["id"])] = item
	return result

func _get_current_wave() -> int:
	var wave_managers: Array = get_tree().get_nodes_in_group("wave_manager")
	if wave_managers.is_empty():
		return 1
	if wave_managers[0].has("wave"):
		return max(wave_managers[0].wave, 1)
	return 1

func take_damage(amount: int) -> void:
	if is_destroyed or amount <= 0:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		_destroy()

func _destroy() -> void:
	is_destroyed = true
	remove_from_group("enemy_targets")
	remove_from_group("build_blockers")
	nest_destroyed.emit()
	var game_state: Node = _get_game_state()
	if game_state != null:
		game_state.show_message("%s已摧毁" % display_name)
		game_state.add_resource("energy", 30)
		game_state.add_resource("iron", 15)
	queue_free()

func _get_game_state() -> Node:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	if not states.is_empty():
		return states[0]
	return null

func _draw() -> void:
	if is_destroyed:
		return
	var health_ratio: float = float(health) / float(max_health)
	var pulse_scale: float = 1.0 + sin(_pulse_phase) * 0.06
	var base_radius: float = 52.0 * pulse_scale
	draw_circle(Vector2.ZERO, base_radius, Color(0.08, 0.02, 0.12, 0.9))
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 48, nest_color, 4.0)
	var inner_radius: float = base_radius * 0.65
	for i in range(5):
		var angle: float = _pulse_phase * 0.8 + deg_to_rad(i * 72.0)
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * inner_radius * 0.3
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * inner_radius
		draw_line(start, end, Color(nest_color.r, nest_color.g, nest_color.b, 0.7), 4.0)
	draw_circle(Vector2.ZERO, inner_radius * 0.35, Color(nest_color.r, nest_color.g, nest_color.b, 0.4))
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-36, -base_radius - 14), Vector2(72, 7)), Color(0.12, 0.02, 0.02, 0.85))
		draw_rect(Rect2(Vector2(-36, -base_radius - 14), Vector2(72 * health_ratio, 7)), Color(0.95, 0.2, 0.3, 0.95))
