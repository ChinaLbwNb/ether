extends Node2D
class_name FogOfWar

@export var player_path: NodePath
@export var map_manager_path: NodePath
@export var fog_color: Color = Color(0.02, 0.03, 0.08, 0.78)
@export var player_visible_radius: float = 420.0
@export var edge_fade_width: float = 140.0

var _player: Node2D
var _map_manager: Node
var _revealed_zones: Array = []
var _fog_layer: Node2D
var _mask_layer: Node2D

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_map_manager = get_node_or_null(map_manager_path)
	_fog_layer = FogBackground.new()
	_mask_layer = FogMask.new()
	_fog_layer.fog_color = fog_color
	_mask_layer.fog_color = fog_color
	_mask_layer.edge_fade_width = edge_fade_width
	_mask_layer.player_visible_radius = player_visible_radius
	var mask_material := CanvasItemMaterial.new()
	mask_material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUBTRACT
	_mask_layer.material = mask_material
	add_child(_fog_layer)
	add_child(_mask_layer)
	if _map_manager != null and _map_manager.has_signal("zone_discovered"):
		_map_manager.zone_discovered.connect(_on_zone_discovered)
	_load_initial_zones()
	_mask_layer.revealed_zones = _revealed_zones
	_mask_layer.player_ref = _player
	_mask_layer.map_manager_ref = _map_manager

func _load_initial_zones() -> void:
	if _map_manager == null:
		return
	if not _map_manager.has_method("get_all_zones"):
		return
	var all_zones: Dictionary = _map_manager.get_all_zones()
	for zone_id in all_zones.keys():
		if _map_manager.has_method("is_zone_discovered") and _map_manager.is_zone_discovered(zone_id):
			var zone: Dictionary = all_zones[zone_id]
			_revealed_zones.append(zone)

func _on_zone_discovered(zone_id: String, _zone_name: String) -> void:
	if _map_manager == null:
		return
	if not _map_manager.has_method("get_zone_data"):
		return
	var zone: Dictionary = _map_manager.get_zone_data(zone_id)
	if not zone.is_empty():
		_revealed_zones.append(zone)
		_mask_layer.revealed_zones = _revealed_zones


class FogBackground extends Node2D:
	var fog_color: Color = Color(0.02, 0.03, 0.08, 0.78)
	func _draw() -> void:
		var size: float = 8000.0
		draw_rect(Rect2(Vector2(-size, -size), Vector2(size * 2, size * 2)), fog_color, true)
	func _process(_delta: float) -> void:
		queue_redraw()


class FogMask extends Node2D:
	var fog_color: Color = Color(0.02, 0.03, 0.08, 0.78)
	var edge_fade_width: float = 140.0
	var player_visible_radius: float = 420.0
	var player_ref: Node2D
	var map_manager_ref: Node
	var revealed_zones: Array = []
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if player_ref == null:
			return
		var player_pos: Vector2 = player_ref.global_position
		var visible_radius: float = player_visible_radius
		if map_manager_ref != null and map_manager_ref.has_method("get_modifier"):
			var vision_mult: float = map_manager_ref.get_modifier("player_vision_multiplier")
			if vision_mult > 0.0:
				visible_radius *= vision_mult
		_draw_hole(player_pos, visible_radius)
		for zone in revealed_zones:
			var zone_center: Vector2 = Vector2(
				float(zone.get("center_x", 0)),
				float(zone.get("center_y", 0))
			)
			var zone_radius: float = float(zone.get("radius", 500))
			_draw_hole(zone_center, zone_radius)
	func _draw_hole(world_pos: Vector2, radius: float) -> void:
		var steps: int = 48
		var inner_radius: float = max(radius - edge_fade_width, 0.0)
		var local_pos: Vector2 = to_local(world_pos)
		var sub_color: Color = fog_color
		if inner_radius > 0:
			var inner_points := PackedVector2Array()
			inner_points.resize(steps + 1)
			inner_points[0] = local_pos
			for i in range(steps):
				var angle: float = float(i) / float(steps) * TAU
				inner_points[i + 1] = local_pos + Vector2(cos(angle), sin(angle)) * inner_radius
			draw_colored_polygon(inner_points, sub_color)
		for i in range(steps):
			var angle0: float = float(i) / float(steps) * TAU
			var angle1: float = float(i + 1) / float(steps) * TAU
			var inner0: Vector2 = local_pos + Vector2(cos(angle0), sin(angle0)) * inner_radius
			var inner1: Vector2 = local_pos + Vector2(cos(angle1), sin(angle1)) * inner_radius
			var outer0: Vector2 = local_pos + Vector2(cos(angle0), sin(angle0)) * radius
			var outer1: Vector2 = local_pos + Vector2(cos(angle1), sin(angle1)) * radius
			var tri_points := PackedVector2Array([inner0, inner1, outer1, inner0, outer1, outer0])
			var tri_colors := PackedColorArray([
				sub_color,
				sub_color,
				Color(0, 0, 0, 0),
				sub_color,
				Color(0, 0, 0, 0),
				Color(0, 0, 0, 0)
			])
			draw_primitive(tri_points, tri_colors, PackedVector2Array())
