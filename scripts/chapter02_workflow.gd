extends "res://scripts/chapter01_workflow.gd"

func _chapter_heading() -> String:
	return "Chapter 2"

func _chapter_objective_text() -> String:
	return "目标：有些门不该被推开。读回声，再决定要不要伸手。"

func _inventory_goal_text() -> String:
	return "轻一点。不是每一次运行都要碰到终点"

func _chapter_tip_text() -> String:
	return "有些 workflow 能抵达那里，\n却会让朋友暗下去。"

func _chapter_completion_text() -> String:
	return "无字积木没有被拿走。它只是安静地留在莉莉丝手心。"

func _chapter_complete_banner_text() -> String:
	return "Chapter 2 完成\n无字积木"

func _build_targets() -> void:
	targets.clear()
	_add_target(
		"blank_block",
		"2-1 无字积木",
		"blank",
		"Refuse",
		["visual", "relation"],
		58,
		28,
		62,
		"一块没有字的积木躺在地上。它很轻，轻得像没有被请求过。",
		"朋友把手收回。那块空白没有碎，也没有离开。",
		"先看见它，再比较它和抽屉之间的距离。最后可以不拿。",
		Color(0.82, 0.84, 1.0),
		Vector2(820, FLOOR_Y - 78)
	)
	targets[targets.size() - 1].cost_limit = 16
	_add_target(
		"thin_bell",
		"2-2 不肯停的铃",
		"bell",
		"Stop",
		["audio", "waiting"],
		44,
		46,
		56,
		"铃声很细，像有人在远处一直说：可以了，可以了。",
		"朋友停在铃声前。响声终于忘了自己要继续。",
		"先听见它，再等一会儿。停下也可以是一种回答。",
		Color(0.72, 0.82, 1.0),
		Vector2(824, FLOOR_Y - 98)
	)
	targets[targets.size() - 1].silence_required = 24
	_add_target(
		"bright_door",
		"2-3 太亮的门",
		"door",
		"Push",
		["visual", "waiting"],
		42,
		34,
		60,
		"门亮得过分。直接推开的话，朋友会把太多光带回来。",
		"朋友先等了一下，只推开能容下一次呼吸的缝。",
		"看见门以后，不要马上推。让它暗一点。",
		Color(0.92, 0.88, 1.0),
		Vector2(836, FLOOR_Y - 90)
	)
	targets[targets.size() - 1].cost_limit = 12
	_add_target(
		"dim_friend",
		"2-4 变暗的朋友",
		"shadow",
		"Quiet",
		["memory", "steady", "waiting"],
		44,
		72,
		48,
		"朋友的影子落在地上，比它自己还要安静。",
		"莉莉丝没有催它。影子慢慢回到朋友身边。",
		"记住它曾经亮过，稳住它，再等一等。",
		Color(0.54, 0.50, 0.76),
		Vector2(828, FLOOR_Y - 82)
	)
	targets[targets.size() - 1].cost_limit = 18

func _add_background() -> void:
	super._add_background()
	for i in range(4):
		var strip := ColorRect.new()
		strip.color = Color(0.78, 0.76, 1.0, 0.040)
		strip.position = Vector2(210 + i * 205, 156 + i * 44)
		strip.size = Vector2(138, 360)
		strip.rotation = -0.08
		strip.z_index = -81
		add_child(strip)
	for i in range(5):
		var blank := ColorRect.new()
		blank.color = Color(0.82, 0.80, 1.0, 0.055)
		blank.position = Vector2(116 + i * 218, 430 - (i % 2) * 42)
		blank.size = Vector2(46, 46)
		blank.rotation = 0.12 - i * 0.035
		blank.z_index = -78
		add_child(blank)

func _add_pickups_for_task() -> void:
	var nodes: Array[String] = []
	if task_index == 0:
		nodes = ["Wait", "Refuse"]
	elif task_index == 1:
		nodes = ["Stop"]
	elif task_index == 2:
		nodes = ["Wait"]
	elif task_index == 3:
		nodes = ["Remember", "Hold", "Quiet"]
	for i in range(nodes.size()):
		var block_id: String = nodes[i]
		if not inventory.has_block(block_id):
			_create_pickup(block_id, Vector2(278 + i * 138, FLOOR_Y - 62), _block_color(block_id))

func _on_workflow_failed(target: EncounterTarget, _result: WorkflowResult) -> void:
	for i in range(6):
		var mote := ColorRect.new()
		mote.color = Color(0.92, 0.76, 1.0, 0.20)
		mote.position = target.position + Vector2(-52 + i * 19, -70 + (i % 3) * 18)
		mote.size = Vector2(8, 8)
		mote.z_index = 19
		add_child(mote)
		var tween := create_tween()
		tween.tween_property(mote, "position:y", mote.position.y - 26.0, 0.55)
		tween.parallel().tween_property(mote, "modulate:a", 0.0, 0.55)
		tween.finished.connect(func(): mote.queue_free())
