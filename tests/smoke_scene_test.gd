extends SceneTree

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://node_2d.tscn") as PackedScene
	_assert(packed != null, "主场景可以加载")
	if packed == null:
		_finish()
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame

	var game_state: Node = scene.get_node_or_null("GameState")
	var base_core: Node = scene.get_node_or_null("BaseCore")
	var game_root: Node = scene.get_node_or_null("GameRoot")
	var resource_a: Node = scene.get_node_or_null("ResourceDeposits/EnergyDepositA")
	var iron_deposit: Node = scene.get_node_or_null("ResourceDeposits/IronDepositA")
	var carbon_deposit: Node = scene.get_node_or_null("ResourceDeposits/CarbonDepositA")
	var tower_scene: PackedScene = load("res://scenes/buildings/sentry_tower.tscn") as PackedScene
	var wall_scene: PackedScene = load("res://scenes/buildings/wall_segment.tscn") as PackedScene
	var miner_scene: PackedScene = load("res://scenes/buildings/mining_drill.tscn") as PackedScene
	var generator_scene: PackedScene = load("res://scenes/buildings/power_generator.tscn") as PackedScene
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene

	_assert(game_state != null, "存在 GameState")
	_assert(base_core != null, "存在 BaseCore")
	_assert(game_root != null, "存在 GameRoot")
	_assert(resource_a != null, "存在资源点")
	_assert(iron_deposit != null, "存在铁矿点")
	_assert(carbon_deposit != null, "存在碳矿点")
	_assert(tower_scene != null, "哨兵塔场景可以加载")
	_assert(wall_scene != null, "城墙场景可以加载")
	_assert(miner_scene != null, "采矿机场景可以加载")
	_assert(generator_scene != null, "发电机场景可以加载")
	_assert(enemy_scene != null, "敌人场景可以加载")

	if game_state != null:
		game_state.storage_capacity = 999
		game_state.add_energy(60)
		_assert(game_state.energy == 60, "资源增加有效")
		_assert(game_state.spend_energy(50), "资源足够时可以扣费")
		_assert(game_state.energy == 10, "扣费后资源正确")
		_assert(not game_state.spend_energy(50), "资源不足时拒绝扣费")
		game_state.add_resource("iron", 20)
		game_state.add_resource("carbon", 20)
		_assert(game_state.get_resource("iron") == 20, "铁资源增加有效")
		_assert(game_state.get_resource("carbon") == 20, "碳资源增加有效")

	if resource_a != null:
		var amount: int = resource_a.collect()
		_assert(amount == 10, "资源点采集数量正确")
	if iron_deposit != null:
		var iron_amount: int = iron_deposit.collect()
		game_state.add_resource("iron", iron_amount)
		_assert(iron_amount == 12, "铁矿采集数量正确")

	if base_core != null:
		base_core.take_damage(25)
		_assert(base_core.health == 475, "基地受伤有效")

	if game_root != null and base_core != null and resource_a != null and game_state != null:
		var player_for_repair: Node2D = scene.get_node_or_null("CharacterBody2D")
		_assert(player_for_repair.health == player_for_repair.max_health, "机甲初始生命值正确")
		_assert(player_for_repair.shield == player_for_repair.max_shield, "机甲初始护盾正确")
		_assert(player_for_repair.mech_energy == player_for_repair.max_energy, "机甲初始能量正确")
		player_for_repair.take_damage(30)
		_assert(player_for_repair.health == player_for_repair.max_health and player_for_repair.shield == player_for_repair.max_shield - 30, "机甲护盾会优先承伤")
		var energy_before_dash: int = player_for_repair.mech_energy
		_assert(player_for_repair.try_dash(Vector2.RIGHT), "机甲可以消耗能量冲刺")
		_assert(player_for_repair.mech_energy == energy_before_dash - player_for_repair.dash_cost, "冲刺会扣除机甲能量")
		player_for_repair.switch_weapon()
		_assert(player_for_repair.active_weapon == "melee", "机甲可以切换到近战武器")
		player_for_repair.switch_weapon()
		_assert(player_for_repair.active_weapon == "ranged", "机甲可以切换回远程武器")
		game_state.add_energy(100)
		game_state.add_resource("iron", 30)
		var weapon_level_before: int = player_for_repair.weapon_level
		game_root._try_upgrade_mech()
		_assert(player_for_repair.weapon_level == weapon_level_before + 1, "机甲武器可以消耗资源升级")
		var snapped: Vector2 = game_root._snap_to_build_grid(Vector2(95, 95))
		_assert(snapped == Vector2(64, 64), "建造坐标会吸附网格")
		var near_base_message: String = game_root._get_build_validation_message(base_core.global_position + Vector2(64, 0))
		_assert(not near_base_message.is_empty(), "基地附近禁止建造")
		var resource_message: String = game_root._get_build_validation_message(resource_a.global_position)
		_assert(not resource_message.is_empty(), "资源点上禁止建造")
		var valid_build_position: Vector2 = game_root._snap_to_build_grid(base_core.global_position + Vector2(256, 0))
		var valid_message: String = game_root._get_build_validation_message(valid_build_position)
		_assert(valid_message.is_empty(), "合法位置允许建造")
		game_root._rotate_current_building()
		game_state.add_energy(50)
		game_state.add_resource("iron", 20)
		var towers_root: Node = scene.get_node_or_null("Towers")
		var tower_count_before: int = towers_root.get_child_count()
		game_root._try_place_tower(valid_build_position)
		_assert(towers_root.get_child_count() == tower_count_before + 1, "合法位置能建造哨兵塔")
		var built_tower: Node2D = towers_root.get_child(tower_count_before)
		_assert(int(round(built_tower.rotation_degrees)) == 90, "建造旋转会应用到建筑")
		_assert(built_tower.has_meta("build_costs"), "建筑会记录建造成本")
		built_tower.take_damage(40)
		_assert(built_tower.health == 80, "防御塔可以受伤")
		player_for_repair.global_position = built_tower.global_position
		game_root._try_repair_nearest_building()
		_assert(built_tower.health == 115, "玩家可以修复受损防御塔")
		var old_damage: int = built_tower.damage
		game_state.add_energy(100)
		game_root._try_upgrade_nearest_tower()
		_assert(built_tower.level == 2 and built_tower.damage > old_damage, "玩家可以升级哨兵塔")
		var overlap_message: String = game_root._get_build_validation_message(valid_build_position)
		_assert(not overlap_message.is_empty(), "防御塔不能重叠建造")
		var walls_root: Node = scene.get_node_or_null("Walls")
		var wall_position: Vector2 = game_root._snap_to_build_grid(base_core.global_position + Vector2(256, 128))
		game_state.add_energy(50)
		game_state.add_resource("iron", 20)
		var wall_count_before: int = walls_root.get_child_count()
		game_root._try_place_wall(wall_position)
		_assert(walls_root.get_child_count() == wall_count_before + 1, "合法位置能建造城墙")
		var built_wall: Node = walls_root.get_child(wall_count_before)
		_assert(built_wall.has_meta("build_costs"), "城墙会记录建造成本")
		built_wall.take_damage(60)
		_assert(built_wall.health == 120, "城墙可以受伤")
		player_for_repair.global_position = built_wall.global_position
		game_root._try_repair_nearest_building()
		_assert(built_wall.health == 155, "玩家可以修复城墙")
		var energy_before_demolish: int = game_state.get_resource("energy")
		var iron_before_demolish: int = game_state.get_resource("iron")
		game_root._try_demolish_nearest_building()
		await process_frame
		_assert(walls_root.get_child_count() == wall_count_before, "玩家可以拆除附近城墙")
		_assert(game_state.get_resource("energy") >= energy_before_demolish + 10, "拆除城墙返还能量")
		_assert(game_state.get_resource("iron") >= iron_before_demolish + 2, "拆除城墙返还铁")
		var production_root: Node = scene.get_node_or_null("ProductionBuildings")
		var generator_position: Vector2 = game_root._snap_to_build_grid(base_core.global_position + Vector2(384, 0))
		game_state.add_energy(50)
		game_state.add_resource("carbon", 20)
		var production_count_before: int = production_root.get_child_count()
		game_root._try_place_generator(generator_position)
		_assert(production_root.get_child_count() == production_count_before + 1, "合法位置能建造发电机")
		_assert(game_state.power_supply == 30, "发电机提供电力")
		var miner_position: Vector2 = game_root._snap_to_build_grid(iron_deposit.global_position + Vector2(64, 0))
		game_state.add_energy(50)
		game_state.add_resource("iron", 30)
		var miner_count_before: int = production_root.get_child_count()
		game_root._try_place_miner(miner_position)
		_assert(production_root.get_child_count() == miner_count_before + 1, "资源点旁能建造采矿机")
		_assert(game_state.power_demand == 8, "采矿机消耗电力")
		var built_miner: Node = production_root.get_child(miner_count_before)
		_assert(built_miner.has_meta("build_costs"), "采矿机会记录建造成本")
		var iron_before_tick: int = game_state.get_resource("iron")
		built_miner._timer = 0.0
		built_miner._process(0.1)
		_assert(game_state.get_resource("iron") > iron_before_tick, "采矿机在电力稳定时自动产出")
		player_for_repair.global_position = built_miner.global_position
		game_root._try_demolish_nearest_building()
		await process_frame
		_assert(game_state.power_demand == 0, "拆除采矿机会释放电力需求")
		var built_generator: Node = production_root.get_child(production_count_before)
		player_for_repair.global_position = built_generator.global_position
		game_root._try_demolish_nearest_building()
		await process_frame
		_assert(game_state.power_supply == 0, "拆除发电机会释放电力供给")
		game_state.add_energy(100)
		var energy_before_death: int = game_state.energy
		player_for_repair.take_damage(999)
		_assert(player_for_repair.health == player_for_repair.max_health, "机甲死亡后会复活")
		_assert(player_for_repair.shield == 0, "机甲复活后护盾清零")
		_assert(game_state.energy == energy_before_death - player_for_repair.death_energy_penalty, "机甲死亡会扣除资源惩罚")

	if tower_scene != null:
		var tower: Node = tower_scene.instantiate()
		_assert(tower != null, "哨兵塔可以实例化")
		tower.queue_free()

	if wall_scene != null:
		var wall: Node = wall_scene.instantiate()
		_assert(wall != null, "城墙可以实例化")
		wall.queue_free()

	if miner_scene != null:
		var miner: Node = miner_scene.instantiate()
		_assert(miner != null, "采矿机可以实例化")
		miner.queue_free()

	if generator_scene != null:
		var generator: Node = generator_scene.instantiate()
		_assert(generator != null, "发电机可以实例化")
		generator.queue_free()

	if enemy_scene != null and base_core != null:
		var enemy: Node = enemy_scene.instantiate()
		root.add_child(enemy)
		enemy.setup(base_core)
		enemy.take_damage(10)
		_assert(enemy.health == 30, "敌人受伤有效")
		enemy.queue_free()

	if enemy_scene != null and base_core != null:
		var tower_target: Node2D = scene.get_node_or_null("Towers").get_child(0)
		var target_test_enemy: Node = enemy_scene.instantiate()
		scene.add_child(target_test_enemy)
		target_test_enemy.global_position = tower_target.global_position + Vector2(48, 0)
		target_test_enemy.setup(base_core)
		_assert(target_test_enemy._find_attack_target() == tower_target, "敌人会优先攻击附近建筑")
		target_test_enemy.queue_free()

	if enemy_scene != null and game_root != null:
		var player: Node2D = scene.get_node_or_null("CharacterBody2D")
		var test_enemy: Node = enemy_scene.instantiate()
		scene.add_child(test_enemy)
		test_enemy.global_position = player.global_position + Vector2(120, 0)
		test_enemy.setup(base_core)
		game_root._try_player_attack(test_enemy.global_position)
		_assert(test_enemy.health == 14, "玩家远程武器攻击链路有效")
		player.switch_weapon()
		test_enemy.global_position = player.global_position + Vector2(80, 0)
		game_root._player_attack_cooldown = 0.0
		var enemy_health_before_melee: int = test_enemy.health
		game_root._try_player_attack(test_enemy.global_position)
		_assert(test_enemy.health < enemy_health_before_melee, "玩家近战武器攻击链路有效")
		test_enemy.queue_free()

	if game_state != null and game_root != null:
		var energy_before_finish: int = game_state.energy
		var wall_count_before_finish: int = scene.get_node_or_null("Walls").get_child_count()
		game_state.finish_game(false, "测试结束锁定")
		game_state.add_energy(999)
		game_root._try_place_wall(base_core.global_position + Vector2(320, 0))
		_assert(game_state.energy == energy_before_finish, "游戏结束后不再增加资源")
		_assert(scene.get_node_or_null("Walls").get_child_count() == wall_count_before_finish, "游戏结束后不能继续建造")

	scene.queue_free()
	_finish()

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] " + label)
	else:
		_failed = true
		push_error("[FAIL] " + label)

func _finish() -> void:
	if _failed:
		quit(1)
	else:
		print("[PASS] 冒烟测试完成")
		quit(0)
