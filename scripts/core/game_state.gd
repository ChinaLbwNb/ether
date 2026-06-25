extends Node
class_name GameState

signal resource_changed(resource_id: String, amount: int)
signal storage_changed(current_total: int, max_total: int)
signal power_changed(supply: int, demand: int)
signal base_health_changed(current_health: int, max_health: int)
signal wave_status_changed(wave: int, status: String, countdown: float, enemies_alive: int)
signal wave_warning_changed(text: String)
signal message_changed(text: String)
signal game_finished(victory: bool, reason: String)

@export var starting_energy: int = 0
@export var starting_iron: int = 0
@export var starting_carbon: int = 0
@export var storage_capacity: int = 240
@export var tower_cost: int = 50
@export var wall_cost: int = 20
@export var tower_upgrade_cost: int = 35
@export var miner_energy_cost: int = 30
@export var generator_energy_cost: int = 25
@export var mech_upgrade_energy_cost: int = 60
@export var mech_upgrade_iron_cost: int = 20
@export var research_station_energy_cost: int = 45
@export var rift_portal_energy_cost: int = 200
@export var rift_portal_iron_cost: int = 100
@export var rift_portal_carbon_cost: int = 80

var resources: Dictionary = {}
var energy: int = 0
var power_supply: int = 0
var power_demand: int = 0
var is_finished: bool = false
var unlimited_resources: bool = false
var resource_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("game_state")
	resources = {
		"energy": starting_energy,
		"iron": starting_iron,
		"carbon": starting_carbon
	}
	_sync_legacy_energy()
	call_deferred("_broadcast_initial_state")

func _broadcast_initial_state() -> void:
	_emit_all_resources()
	power_changed.emit(power_supply, power_demand)
	message_changed.emit("E 采集，N 研究站，K 科技，Q 切武器，Space 冲刺")

func set_starting_resources(energy: int, iron: int, carbon: int, storage: int) -> void:
	storage_capacity = max(storage, 0)
	resources["energy"] = max(energy, 0)
	resources["iron"] = max(iron, 0)
	resources["carbon"] = max(carbon, 0)
	_sync_legacy_energy()
	_emit_all_resources()

func add_energy(amount: int) -> void:
	add_resource("energy", amount)

func add_resource(resource_id: String, amount: int) -> int:
	if is_finished:
		return 0
	_ensure_resource(resource_id)
	var actual_amount: int = int(float(max(amount, 0)) * resource_multiplier)
	var free_space: int = maxi(storage_capacity - get_total_resources(), 0)
	var accepted: int = mini(actual_amount, free_space)
	if unlimited_resources:
		accepted = actual_amount
	resources[resource_id] += accepted
	_sync_legacy_energy()
	resource_changed.emit(resource_id, resources[resource_id])
	storage_changed.emit(get_total_resources(), storage_capacity)
	return accepted

func can_afford(cost: int) -> bool:
	if unlimited_resources:
		return true
	return get_resource("energy") >= cost

func can_afford_resources(costs: Dictionary) -> bool:
	if unlimited_resources:
		return true
	for resource_id in costs.keys():
		if get_resource(str(resource_id)) < int(costs[resource_id]):
			return false
	return true

func spend_energy(cost: int) -> bool:
	return spend_resources({"energy": cost})

func spend_resources(costs: Dictionary) -> bool:
	if is_finished:
		return false
	if unlimited_resources:
		return true
	if not can_afford_resources(costs):
		return false
	for resource_id in costs.keys():
		var id: String = str(resource_id)
		resources[id] -= int(costs[resource_id])
		resource_changed.emit(id, resources[id])
	_sync_legacy_energy()
	storage_changed.emit(get_total_resources(), storage_capacity)
	return true

func get_resource(resource_id: String) -> int:
	_ensure_resource(resource_id)
	return int(resources[resource_id])

func get_total_resources() -> int:
	if unlimited_resources:
		return 0
	var total: int = 0
	for amount in resources.values():
		total += int(amount)
	return total

func register_power_source(amount: int) -> void:
	power_supply += max(amount, 0)
	power_changed.emit(power_supply, power_demand)

func unregister_power_source(amount: int) -> void:
	power_supply = max(power_supply - max(amount, 0), 0)
	power_changed.emit(power_supply, power_demand)

func register_power_consumer(amount: int) -> void:
	power_demand += max(amount, 0)
	power_changed.emit(power_supply, power_demand)

func unregister_power_consumer(amount: int) -> void:
	power_demand = max(power_demand - max(amount, 0), 0)
	power_changed.emit(power_supply, power_demand)

func has_stable_power() -> bool:
	return power_supply >= power_demand

func get_tower_costs() -> Dictionary:
	return {"energy": tower_cost, "iron": 10}

func get_wall_costs() -> Dictionary:
	return {"energy": wall_cost, "iron": 5}

func get_miner_costs() -> Dictionary:
	return {"energy": miner_energy_cost, "iron": 15}

func get_generator_costs() -> Dictionary:
	return {"energy": generator_energy_cost, "carbon": 10}

func get_mech_upgrade_costs() -> Dictionary:
	return {"energy": mech_upgrade_energy_cost, "iron": mech_upgrade_iron_cost}

func get_research_station_costs() -> Dictionary:
	return {"energy": research_station_energy_cost, "iron": 20, "carbon": 10}

func get_rift_portal_costs() -> Dictionary:
	return {"energy": rift_portal_energy_cost, "iron": rift_portal_iron_cost, "carbon": rift_portal_carbon_cost}

func set_base_health(current_health: int, max_health: int) -> void:
	base_health_changed.emit(current_health, max_health)

func set_wave_status(wave: int, status: String, countdown: float, enemies_alive: int) -> void:
	wave_status_changed.emit(wave, status, countdown, enemies_alive)

func set_wave_warning(text: String) -> void:
	wave_warning_changed.emit(text)

func show_message(text: String) -> void:
	message_changed.emit(text)

func finish_game(victory: bool, reason: String) -> void:
	if is_finished:
		return
	is_finished = true
	game_finished.emit(victory, reason)
	message_changed.emit(reason)

func format_cost(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in costs.keys():
		parts.append("%s %d" % [_get_resource_label(str(resource_id)), int(costs[resource_id])])
	return "、".join(parts)

func _ensure_resource(resource_id: String) -> void:
	if not resources.has(resource_id):
		resources[resource_id] = 0

func _emit_all_resources() -> void:
	for resource_id in resources.keys():
		resource_changed.emit(str(resource_id), int(resources[resource_id]))
	storage_changed.emit(get_total_resources(), storage_capacity)

func _sync_legacy_energy() -> void:
	energy = get_resource("energy")

func _get_resource_label(resource_id: String) -> String:
	match resource_id:
		"energy":
			return "能量"
		"iron":
			return "铁"
		"carbon":
			return "碳"
		_:
			return resource_id
