extends "res://scripts/chapter01_workflow.gd"

var dim_marks: Array[Node2D] = []

func _load_task(next_index: int) -> void:
	dim_marks.clear()
	super._load_task(next_index)

func _chapter_heading() -> String:
	return "Chapter 2"

func _chapter_objective_text() -> String:
	return "目标：有些门不该被推开。读回声，再决定要不要伸手。"

func _inventory_goal_text() -> String:
	return "轻一点。不是每一次运行都要碰到终点"

func _chapter_tip_text() -> String:
	return "有些顺序能抵达那里，\n却会让朋友暗下去。"

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
		["visual"],
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
	var cold_wash := ColorRect.new()
	cold_wash.color = Color(0.14, 0.10, 0.22, 0.22)
	cold_wash.size = Vector2(1280, 568)
	cold_wash.z_index = -89
	add_child(cold_wash)
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
	for i in range(6):
		_add_background_block_outline(
			Vector2(148 + i * 188, 176 + (i % 3) * 54),
			Vector2(76 + (i % 2) * 30, 76 + (i % 2) * 30),
			Color(0.86, 0.82, 1.0, 0.16),
			-0.12 + i * 0.045
		)
	for i in range(3):
		var refusal_line := ColorRect.new()
		refusal_line.color = Color(0.96, 0.74, 0.82, 0.070)
		refusal_line.position = Vector2(690 + i * 118, 258 + i * 58)
		refusal_line.size = Vector2(170, 7)
		refusal_line.rotation = -0.18
		refusal_line.z_index = -76
		add_child(refusal_line)

func _add_background_block_outline(pos: Vector2, size: Vector2, color: Color, rotation_value: float) -> void:
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = color
	outline.closed = true
	outline.points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y),
	])
	outline.position = pos
	outline.rotation = rotation_value
	outline.z_index = -77
	add_child(outline)

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
	if _result.failure_reason.contains("代价太重"):
		_add_dim_friend_mark(target.position + Vector2(-118, 28))

func _add_dim_friend_mark(pos: Vector2) -> void:
	var mark := Node2D.new()
	mark.position = pos
	mark.z_index = 8
	level_root.add_child(mark)
	dim_marks.append(mark)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -58),
		Vector2(26, -18),
		Vector2(16, 20),
		Vector2(-16, 20),
		Vector2(-26, -18),
	])
	body.color = Color(0.34, 0.30, 0.48, 0.58)
	mark.add_child(body)

	var dim_core := ColorRect.new()
	dim_core.color = Color(0.94, 0.84, 1.0, 0.18)
	dim_core.position = Vector2(-10, -36)
	dim_core.size = Vector2(20, 5)
	mark.add_child(dim_core)

	var thread := Line2D.new()
	thread.width = 2.0
	thread.default_color = Color(0.96, 0.74, 0.88, 0.18)
	thread.points = PackedVector2Array([Vector2(-24, -10), Vector2(-74, -18)])
	mark.add_child(thread)

	mark.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(mark, "modulate:a", 1.0, 0.34)
	tween.parallel().tween_property(mark, "position:y", mark.position.y + 8.0, 0.34)

func _resolve_target(target: EncounterTarget) -> void:
	await super._resolve_target(target)
	for i in range(dim_marks.size()):
		var mark: Node2D = dim_marks[i]
		if mark != null and is_instance_valid(mark):
			var tween := create_tween()
			tween.tween_property(mark, "modulate:a", 0.18, 0.42)
