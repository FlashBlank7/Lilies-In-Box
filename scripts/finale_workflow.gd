extends "res://scripts/chapter01_workflow.gd"

func _chapter_heading() -> String:
	return "Finale"

func _chapter_objective_text() -> String:
	return "目标：这里没有门。只剩一块等她写下去的空白。"

func _inventory_goal_text() -> String:
	return "不要找门。让抽屉听见她留下的名字"

func _chapter_tip_text() -> String:
	return "最后的房间没有出口。\n它只等一个很小的名字。"

func _chapter_completion_text() -> String:
	return "抽屉里多了一块小积木。朋友没有立刻离开。"

func _chapter_complete_banner_text() -> String:
	return "完成\n没有门的房间"

func _build_targets() -> void:
	targets.clear()
	_add_target(
		"name_in_drawer",
		"没有门的房间",
		"name",
		"Stop",
		["visual", "memory", "waiting", "silence"],
		62,
		32,
		64,
		"房间中央放着一块细长的空白。它不像门，也不像路。",
		"朋友停下来。空白上慢慢出现了莉莉丝的名字。",
		"看见它，记住来过的路。等到足够安静，再停下。",
		Color(0.88, 0.86, 1.0),
		Vector2(762, FLOOR_Y - 86)
	)
	targets[0].silence_required = 48
	targets[0].cost_limit = 8

func _add_background() -> void:
	super._add_background()
	var hush := ColorRect.new()
	hush.color = Color(0.92, 0.92, 1.0, 0.050)
	hush.position = Vector2(0, 230)
	hush.size = Vector2(1280, 140)
	hush.z_index = -79
	add_child(hush)

func _add_pickups_for_task() -> void:
	var nodes: Array[String] = ["See", "Remember", "Wait", "Stop"]
	for i in range(nodes.size()):
		var block_id: String = nodes[i]
		if not inventory.has_block(block_id):
			_create_pickup(block_id, Vector2(280 + i * 138, FLOOR_Y - 62), _block_color(block_id))

func _add_task_door() -> void:
	door = Node2D.new()
	door.name = "NameRest"
	door.position = Vector2(1086, FLOOR_Y - 72)
	level_root.add_child(door)

	door_glow = ColorRect.new()
	door_glow.color = Color(0.82, 0.82, 1.0, 1.0)
	door_glow.modulate.a = 0.0
	door_glow.position = Vector2(-54, -76)
	door_glow.size = Vector2(108, 72)
	door.add_child(door_glow)

	door_visual = ColorRect.new()
	door_visual.color = Color(0.070, 0.068, 0.104)
	door_visual.position = Vector2(-42, -58)
	door_visual.size = Vector2(84, 36)
	door.add_child(door_visual)
