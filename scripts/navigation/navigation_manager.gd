extends Node2D
class_name NavigationManager

signal navigation_updated

@export var cell_size: float = 64.0
@export var map_half_extents: Vector2 = Vector2(2000, 2000)
@export var base_path: NodePath
@export var debug_draw_path: bool = false

var _astar: AStar2D = AStar2D.new()
var _base_core: Node2D
var _obstacle_cells: Dictionary = {}
var _is_dirty: bool = true
var _grid_origin: Vector2
var _grid_width: int
var _grid_height: int
var _debug_paths: Array = []

func _ready() -> void:
	add_to_group("navigation_manager")
	_base_core = get_node_or_null(base_path)
	_grid_origin = -map_half_extents
	_grid_width = int(ceil(map_half_extents.x * 2.0 / cell_size)) + 1
	_grid_height = int(ceil(map_half_extents.y * 2.0 / cell_size)) + 1
	_build_grid()
	rebuild_obstacles()

func _process(delta: float) -> void:
	if _is_dirty:
		_rebuild_navigation()
		_is_dirty = false

func _draw() -> void:
	if not debug_draw_path:
		return
	for path_points in _debug_paths:
		if path_points.size() < 2:
			continue
		for i in range(path_points.size() - 1):
			draw_line(path_points[i], path_points[i + 1], Color(0.2, 1.0, 0.3, 0.6), 2.0)
		_debug_draw_obstacles()

func _debug_draw_obstacles() -> void:
	var blocked_color: Color = Color(1.0, 0.2, 0.2, 0.15)
	for y in range(_grid_height):
		for x in range(_grid_width):
			var cell_id: int = _cell_to_id(x, y)
			if _astar.has_point(cell_id) and _astar.is_point_disabled(cell_id):
				var world_pos: Vector2 = _cell_to_world(x, y)
				draw_rect(Rect2(world_pos - Vector2(cell_size * 0.5, cell_size * 0.5), Vector2(cell_size, cell_size)), blocked_color)

func _build_grid() -> void:
	_astar.clear()
	for y in range(_grid_height):
		for x in range(_grid_width):
			var id: int = _cell_to_id(x, y)
			var pos: Vector2 = _cell_to_world(x, y)
			_astar.add_point(id, pos)
	for y in range(_grid_height):
		for x in range(_grid_width):
			var id: int = _cell_to_id(x, y)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if abs(dx) + abs(dy) > 1:
						continue
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and nx < _grid_width and ny >= 0 and ny < _grid_height:
						var nid: int = _cell_to_id(nx, ny)
						_astar.connect_points(id, nid, false)

func _cell_to_id(x: int, y: int) -> int:
	return y * _grid_width + x

func _id_to_cell(id: int) -> Vector2i:
	return Vector2i(id % _grid_width, id / _grid_width)

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - _grid_origin
	return Vector2i(
		int(floor(local.x / cell_size)),
		int(floor(local.y / cell_size))
	)

func _cell_to_world(x: int, y: int) -> Vector2:
	return _grid_origin + Vector2(
		(float(x) + 0.5) * cell_size,
		(float(y) + 0.5) * cell_size
	)

func _is_cell_valid(x: int, y: int) -> bool:
	return x >= 0 and x < _grid_width and y >= 0 and y < _grid_height

func _rebuild_navigation() -> void:
	_build_grid()
	_mark_obstacles()
	navigation_updated.emit()
	queue_redraw()

func mark_dirty() -> void:
	_is_dirty = true

func add_circular_obstacle(world_pos: Vector2, radius: float) -> void:
	var min_cell: Vector2i = _world_to_cell(world_pos - Vector2(radius, radius))
	var max_cell: Vector2i = _world_to_cell(world_pos + Vector2(radius, radius))
	var key: String = "%d_%d" % [int(world_pos.x), int(world_pos.y)]
	var cells: Array = []
	for y in range(maxi(min_cell.y, 0), mini(max_cell.y + 1, _grid_height)):
		for x in range(maxi(min_cell.x, 0), mini(max_cell.x + 1, _grid_width)):
			var cell_world: Vector2 = _cell_to_world(x, y)
			if cell_world.distance_to(world_pos) <= radius + cell_size * 0.3:
				cells.append(Vector2i(x, y))
	_obstacle_cells[key] = {"pos": world_pos, "radius": radius, "cells": cells}
	mark_dirty()

func remove_circular_obstacle(world_pos: Vector2) -> void:
	var key: String = "%d_%d" % [int(world_pos.x), int(world_pos.y)]
	if _obstacle_cells.has(key):
		_obstacle_cells.erase(key)
		mark_dirty()

func update_circular_obstacle(old_pos: Vector2, new_pos: Vector2, radius: float) -> void:
	remove_circular_obstacle(old_pos)
	add_circular_obstacle(new_pos, radius)

func rebuild_obstacles() -> void:
	_obstacle_cells.clear()
	for building in get_tree().get_nodes_in_group("build_blockers"):
		if not is_instance_valid(building) or not (building is Node2D):
			continue
		var block_radius: float = cell_size * 0.5
		if building.has_method("get_block_radius"):
			block_radius = building.get_block_radius()
		elif building.is_in_group("base_core"):
			block_radius = cell_size * 0.75
		elif building.is_in_group("defense_towers"):
			block_radius = cell_size * 0.5
		elif building.is_in_group("rift_portal"):
			block_radius = cell_size * 0.8
		elif WallSegment != null and building is WallSegment:
			block_radius = cell_size * 0.3
		elif building.is_in_group("enemy_nests"):
			block_radius = cell_size * 0.6
		elif building.is_in_group("destructible_obstacles"):
			block_radius = cell_size * 0.5
		elif building.is_in_group("repairable_buildings"):
			block_radius = cell_size * 0.55
		add_circular_obstacle(building.global_position, block_radius)
	for deposit in get_tree().get_nodes_in_group("resource_deposits"):
		if is_instance_valid(deposit) and deposit is Node2D:
			add_circular_obstacle(deposit.global_position, cell_size * 0.45)
	mark_dirty()

func _mark_obstacles() -> void:
	for data in _obstacle_cells.values():
		for cell in data.cells:
			var x: int = cell.x
			var y: int = cell.y
			if _is_cell_valid(x, y):
				var id: int = _cell_to_id(x, y)
				if _astar.has_point(id):
					_astar.set_point_disabled(id, true)

func _mark_area_blocked(world_pos: Vector2, radius: float) -> void:
	var min_cell: Vector2i = _world_to_cell(world_pos - Vector2(radius, radius))
	var max_cell: Vector2i = _world_to_cell(world_pos + Vector2(radius, radius))
	for y in range(maxi(min_cell.y, 0), mini(max_cell.y + 1, _grid_height)):
		for x in range(maxi(min_cell.x, 0), mini(max_cell.x + 1, _grid_width)):
			var cell_world: Vector2 = _cell_to_world(x, y)
			if cell_world.distance_to(world_pos) <= radius + cell_size * 0.2:
				var id: int = _cell_to_id(x, y)
				if _astar.has_point(id):
					_astar.set_point_disabled(id, true)

func find_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var start_cell: Vector2i = _world_to_cell(from_pos)
	var end_cell: Vector2i = _world_to_cell(to_pos)
	if not _is_cell_valid(start_cell.x, start_cell.y) or not _is_cell_valid(end_cell.x, end_cell.y):
		return [to_pos]
	var start_id: int = _cell_to_id(start_cell.x, start_cell.y)
	var end_id: int = _cell_to_id(end_cell.x, end_cell.y)
	if not _astar.has_point(start_id) or not _astar.has_point(end_id):
		return [to_pos]
	if _astar.is_point_disabled(start_id):
		start_id = _find_nearest_free_cell(start_cell)
	if _astar.is_point_disabled(end_id):
		end_id = _find_nearest_free_cell(end_cell)
	if start_id == -1 or end_id == -1:
		return [to_pos]
	var path_ids: PackedInt64Array = _astar.get_id_path(start_id, end_id)
	if path_ids.is_empty():
		return [to_pos]
	var path: Array[Vector2] = []
	for pid in path_ids:
		path.append(_astar.get_point_position(pid))
	if not path.is_empty():
		path[-1] = to_pos
	if debug_draw_path:
		_debug_paths = [path.duplicate()]
		queue_redraw()
	return path

func _find_nearest_free_cell(cell: Vector2i, search_radius: int = 5) -> int:
	for r in range(1, search_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var nx: int = cell.x + dx
				var ny: int = cell.y + dy
				if _is_cell_valid(nx, ny):
					var nid: int = _cell_to_id(nx, ny)
					if _astar.has_point(nid) and not _astar.is_point_disabled(nid):
						return nid
	return -1

func find_nearest_spawn_position(target_pos: Vector2, min_distance: float = 500.0) -> Vector2:
	var angles_to_try: int = 32
	var best_pos: Vector2 = Vector2.ZERO
	var best_dist: float = -1.0
	for i in range(angles_to_try):
		var angle: float = (float(i) / float(angles_to_try)) * TAU
		for dist_mult in range(8, 16):
			var dist: float = float(dist_mult) * cell_size
			var test_pos: Vector2 = target_pos + Vector2(cos(angle), sin(angle)) * dist
			var test_cell: Vector2i = _world_to_cell(test_pos)
			if not _is_cell_valid(test_cell.x, test_cell.y):
				continue
			var test_id: int = _cell_to_id(test_cell.x, test_cell.y)
			if _astar.has_point(test_id) and not _astar.is_point_disabled(test_id):
				var path: Array = find_path(test_pos, target_pos)
				if path.size() > 1 or test_pos.distance_to(target_pos) < cell_size * 2:
					if dist > best_dist and dist >= min_distance:
						best_dist = dist
						best_pos = test_pos
					break
	if best_dist < 0:
		var fallback_angle: float = randf() * TAU
		best_pos = target_pos + Vector2(cos(fallback_angle), sin(fallback_angle)) * min_distance
	return best_pos

func is_position_walkable(world_pos: Vector2) -> bool:
	var cell: Vector2i = _world_to_cell(world_pos)
	if not _is_cell_valid(cell.x, cell.y):
		return false
	var id: int = _cell_to_id(cell.x, cell.y)
	return _astar.has_point(id) and not _astar.is_point_disabled(id)

func register_building(building: Node2D) -> void:
	if building == null or not is_instance_valid(building):
		return
	var block_radius: float = cell_size * 0.6
	if building.has_method("get_block_radius"):
		block_radius = building.get_block_radius()
	add_circular_obstacle(building.global_position, block_radius)

func unregister_building(building: Node2D) -> void:
	if building == null or not is_instance_valid(building):
		return
	remove_circular_obstacle(building.global_position)
