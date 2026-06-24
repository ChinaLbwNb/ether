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
	var research_manager: Node = scene.get_node_or_null("ResearchManager")
	var map_manager: Node = scene.get_node_or_null("MapManager")
	var mission_manager: Node = scene.get_node_or_null("MissionManager")
	var base_core: Node = scene.get_node_or_null("BaseCore")
	var game_root: Node = scene.get_node_or_null("GameRoot")
	var wave_manager: Node = scene.get_node_or_null("WaveManager")
	var resource_a: Node = scene.get_node_or_null("ResourceDeposits/EnergyDepositA")
	var iron_deposit: Node = scene.get_node_or_null("ResourceDeposits/IronDepositA")
	var carbon_deposit: Node = scene.get_node_or_null("ResourceDeposits/CarbonDepositA")
	var tower_scene: PackedScene = load("res://scenes/buildings/sentry_tower.tscn") as PackedScene
	var wall_scene: PackedScene = load("res://scenes/buildings/wall_segment.tscn") as PackedScene
	var miner_scene: PackedScene = load("res://scenes/buildings/mining_drill.tscn") as PackedScene
	var generator_scene: PackedScene = load("res://scenes/buildings/power_generator.tscn") as PackedScene
	var research_station_scene: PackedScene = load("res://scenes/buildings/research_station.tscn") as PackedScene
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene

	_assert(game_state != null, "存在 GameState")
	_assert(research_manager != null, "存在 ResearchManager")
	_assert(map_manager != null, "存在 MapManager")
	_assert(mission_manager != null, "存在 MissionManager")
	_assert(base_core != null, "存在 BaseCore")
	_assert(game_root != null, "存在 GameRoot")
	_assert(wave_manager != null, "存在 WaveManager")
	_assert(resource_a != null, "存在资源点")
	_assert(iron_deposit != null, "存在铁矿点")
	_assert(carbon_deposit != null, "存在碳矿点")
	_assert(tower_scene != null, "哨兵塔场景可以加载")
	_assert(wall_scene != null, "城墙场景可以加载")
	_assert(miner_scene != null, "采矿机场景可以加载")
	_assert(generator_scene != null, "发电机场景可以加载")
	_assert(research_station_scene != null, "研究站场景可以加载")
	_assert(enemy_scene != null, "敌人场景可以加载")

	if game_state != null:
		game_state.storage_capacity = 999
		_assert(mission_manager.mission_definitions.size() >= 6, "战役任务数据可以加载")
		_assert(mission_manager.get_current_mission_title() == "重启基地核心", "战役初始任务正确")
		game_state.add_energy(60)
		_assert(game_state.energy == 60, "资源增加有效")
		_assert(mission_manager.completed_missions.has("stockpile_energy"), "资源任务会自动完成")
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
		_assert(map_manager.map_definitions.size() >= 3, "地图区域数据可以加载")
		_assert(map_manager.current_map_id == "home_base", "默认位于主基地")
		_assert(map_manager.apply_resource_yield("iron", 10) == 10, "主基地资源倍率正常")
		_assert(not map_manager.travel_to_map("iron_ridge"), "未解锁区域不能传送")
		game_state.add_energy(100)
		game_state.add_resource("iron", 40)
		_assert(map_manager.unlock_map("iron_ridge"), "可以消耗资源解锁铁脊矿区")
		_assert(map_manager.travel_to_map("iron_ridge"), "可以传送到已解锁区域")
		_assert(map_manager.apply_resource_yield("iron", 10) == 18, "区域会提升对应资源产出")
		_assert(map_manager.get_enemy_pressure_bonus() > 0, "外部区域会增加敌潮压力")
		_assert(wave_manager._dynamic_pressure_bonus() >= map_manager.get_enemy_pressure_bonus(), "波次压力会读取当前区域规则")
		_assert(map_manager.travel_to_map("home_base"), "可以传送回主基地")
		_assert(research_manager.tech_definitions.size() >= 5, "科技数据可以加载")
		_assert(wave_manager._enemy_types.size() >= 5, "敌人类型数据可以加载")
		var wave_one: Dictionary = wave_manager._build_wave_composition(1)
		var wave_four: Dictionary = wave_manager._build_wave_composition(4)
		_assert(wave_one.has("scout"), "第一波包含轻型敌人")
		_assert(wave_four.has("armored") and wave_four.has("breaker") and wave_four.has("spitter"), "高波次会混合重甲、破墙和远程敌人")
		_assert(not wave_manager._format_wave_warning(4, wave_four).is_empty(), "波次预警文本可以生成")
		_assert(not research_manager.try_research("tower_overdrive"), "没有研究站时不能研究科技")
		player_for_repair.take_damage(30)
		_assert(player_for_repair.health == player_for_repair.max_health and player_for_repair.shield == player_for_repair.max_shield - 30, "机甲护盾会优先承伤")
		var energy_before_dash: int = player_for_repair.mech_energy
		_assert(player_for_repair.try_dash(Vector2.RIGHT), "机甲可以消耗能量冲刺")
		_assert(player_for_repair.mech_energy == energy_before_dash - player_for_repair.dash_cost, "冲刺会扣除机甲能量")
		player_for_repair._dash_cooldown_timer = 0.0
		player_for_repair._last_move_vector = Vector2.LEFT
		_assert(player_for_repair.try_dash(Vector2.ZERO), "无移动输入时冲刺沿最后移动方向")
		_assert(player_for_repair._dash_direction == Vector2.LEFT, "冲刺方向不再固定反向")
		player_for_repair._play_move_animation(Vector2(1, 1).normalized())
		_assert(player_for_repair.last_direction == "back", "右下斜向移动优先使用右向动作")
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
		_assert(mission_manager.completed_missions.has("build_first_tower"), "建塔任务会自动完成")
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
		var research_position: Vector2 = game_root._snap_to_build_grid(base_core.global_position + Vector2(0, 256))
		game_state.add_energy(120)
		game_state.add_resource("iron", 60)
		game_state.add_resource("carbon", 30)
		var production_root: Node = scene.get_node_or_null("ProductionBuildings")
		var station_count_before: int = production_root.get_child_count()
		game_root._try_place_research_station(research_position)
		_assert(production_root.get_child_count() == station_count_before + 1, "合法位置能建造研究站")
		_assert(research_manager.station_count == 1, "研究站会注册到科技管理器")
		_assert(mission_manager.completed_missions.has("build_research_station"), "研究站任务会自动完成")
		var tower_damage_before_research: int = built_tower.damage
		game_state.add_energy(120)
		game_state.add_resource("iron", 60)
		_assert(research_manager.try_research("tower_overdrive"), "可以研究哨兵塔科技")
		_assert(research_manager.has_technology("tower_overdrive"), "科技完成状态会记录")
		_assert(built_tower.damage > tower_damage_before_research, "科技会强化现有哨兵塔")
		_assert(mission_manager.completed_missions.has("research_tower_overdrive"), "科技任务会自动完成")
		_assert(mission_manager.completed_missions.has("unlock_iron_ridge"), "地图解锁任务会自动完成")
		mission_manager._on_wave_status_changed(2, "清场", 0.0, 0)
		_assert(mission_manager.completed_missions.has("survive_second_wave"), "守波任务会自动完成")
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
		game_state.add_energy(100)
		game_state.add_resource("iron", 60)
		var wall_health_before_research: int = built_wall.max_health
		_assert(research_manager.try_research("wall_plating"), "前置满足后可以研究城墙科技")
		_assert(built_wall.max_health > wall_health_before_research, "科技会强化现有城墙")
		built_wall.take_damage(60)
		_assert(built_wall.health == built_wall.max_health - 60, "城墙可以受伤")
		player_for_repair.global_position = built_wall.global_position
		var wall_health_before_repair: int = built_wall.health
		game_root._try_repair_nearest_building()
		_assert(built_wall.health == mini(wall_health_before_repair + game_root.repair_amount, built_wall.max_health), "玩家可以修复城墙")
		var energy_before_demolish: int = game_state.get_resource("energy")
		var iron_before_demolish: int = game_state.get_resource("iron")
		game_root._try_demolish_nearest_building()
		await process_frame
		_assert(walls_root.get_child_count() == wall_count_before, "玩家可以拆除附近城墙")
		_assert(game_state.get_resource("energy") >= energy_before_demolish + 10, "拆除城墙返还能量")
		_assert(game_state.get_resource("iron") >= iron_before_demolish + 2, "拆除城墙返还铁")
		var generator_position: Vector2 = game_root._snap_to_build_grid(base_core.global_position + Vector2(384, 0))
		game_state.add_energy(50)
		game_state.add_resource("carbon", 20)
		var production_count_before: int = production_root.get_child_count()
		game_root._try_place_generator(generator_position)
		_assert(production_root.get_child_count() == production_count_before + 1, "合法位置能建造发电机")
		_assert(game_state.power_supply == 30, "发电机提供电力")
		game_state.add_energy(80)
		game_state.add_resource("carbon", 40)
		_assert(research_manager.try_research("generator_efficiency"), "可以研究发电效率科技")
		_assert(game_state.power_supply == 40, "科技会提升现有发电机供电")
		var miner_position: Vector2 = game_root._snap_to_build_grid(iron_deposit.global_position + Vector2(64, 0))
		game_state.add_energy(50)
		game_state.add_resource("iron", 30)
		var miner_count_before: int = production_root.get_child_count()
		game_root._try_place_miner(miner_position)
		_assert(production_root.get_child_count() == miner_count_before + 1, "资源点旁能建造采矿机")
		_assert(game_state.power_demand == 8, "采矿机消耗电力")
		var built_miner: Node = production_root.get_child(miner_count_before)
		_assert(built_miner.has_meta("build_costs"), "采矿机会记录建造成本")
		game_state.add_energy(80)
		game_state.add_resource("iron", 40)
		var miner_amount_before_research: int = built_miner.production_amount
		_assert(research_manager.try_research("mining_efficiency"), "可以研究采矿效率科技")
		_assert(built_miner.production_amount > miner_amount_before_research, "科技会提升现有采矿机产出")
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
		var max_weapon_level_before_research: int = player_for_repair.max_weapon_level
		game_state.add_energy(100)
		game_state.add_resource("iron", 50)
		_assert(research_manager.try_research("mech_mk2"), "可以研究机甲科技")
		_assert(player_for_repair.max_weapon_level > max_weapon_level_before_research, "科技会提升机甲成长上限")
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

	if research_station_scene != null:
		var station: Node = research_station_scene.instantiate()
		_assert(station != null, "研究站可以实例化")
		station.queue_free()

	if enemy_scene != null and base_core != null:
		var enemy: Node = enemy_scene.instantiate()
		root.add_child(enemy)
		enemy.setup(base_core)
		enemy.take_damage(10)
		_assert(enemy.health == 30, "敌人受伤有效")
		enemy.queue_free()

	if enemy_scene != null and base_core != null and wave_manager != null:
		var armored_enemy: Node = enemy_scene.instantiate()
		root.add_child(armored_enemy)
		armored_enemy.setup_type(wave_manager._enemy_types["armored"], 2)
		armored_enemy.setup(base_core)
		var armored_health_before: int = armored_enemy.health
		armored_enemy.take_damage(10)
		_assert(armored_enemy.health == armored_health_before - 6, "重甲敌人会用护甲减伤")
		armored_enemy.queue_free()

	if enemy_scene != null and base_core != null and wave_manager != null:
		var breaker_enemy: Node = enemy_scene.instantiate()
		scene.add_child(breaker_enemy)
		breaker_enemy.setup_type(wave_manager._enemy_types["breaker"], 3)
		breaker_enemy.setup(base_core)
		var tower_target_for_breaker: Node2D = scene.get_node_or_null("Towers").get_child(0)
		breaker_enemy.global_position = tower_target_for_breaker.global_position + Vector2(90, 0)
		_assert(breaker_enemy._find_attack_target() == tower_target_for_breaker, "破墙敌人会优先锁定建筑")
		breaker_enemy.queue_free()

	if enemy_scene != null and base_core != null and wave_manager != null:
		var spitter_enemy: Node = enemy_scene.instantiate()
		root.add_child(spitter_enemy)
		spitter_enemy.setup_type(wave_manager._enemy_types["spitter"], 4)
		_assert(spitter_enemy.attack_range > 150.0, "远程敌人拥有更长攻击距离")
		spitter_enemy.queue_free()

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
