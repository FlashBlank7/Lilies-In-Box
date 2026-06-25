extends "res://scripts/chapter01_workflow.gd"

var remembered_failures := 0

func _chapter_heading() -> String:
	return "Chapter 3"

func _chapter_objective_text() -> String:
	return "目标：纸没有收件人。让旧回声帮她改写下一步。"

func _inventory_goal_text() -> String:
	return "读旧回声，再把新的顺序接上"

func _chapter_tip_text() -> String:
	return "失败不会消失。\n它会折成下一张纸的边。"

func _chapter_completion_text() -> String:
	return "未寄出的信没有寄出。它在抽屉里变成一盏很小的灯。"

func _chapter_complete_banner_text() -> String:
	return "Chapter 3 完成\n未寄出的信"

func _build_targets() -> void:
	targets.clear()
	_add_target(
		"empty_envelope",
		"3-1 空信封",
		"letter",
		"Quiet",
		["audio", "memory"],
		56,
		36,
		60,
		"信封里没有信。只有一层很轻的沙沙声。",
		"朋友记住那层声音，然后让它轻轻合上。",
		"先听见纸，再记住纸曾经空过。",
		Color(0.86, 0.82, 0.98),
		Vector2(812, FLOOR_Y - 84)
	)
	_add_target(
		"rewritten_step",
		"3-2 被改写的台阶",
		"step",
		"Push",
		["visual", "memory", "relation"],
		72,
		52,
		60,
		"台阶上有擦掉又写回去的痕迹。它不确定自己有没有来过。",
		"朋友把旧痕迹和眼前的路接起来，台阶停住了。",
		"看见它，记住它，再比较它和前方。",
		Color(0.62, 0.84, 1.0),
		Vector2(822, FLOOR_Y - 116)
	)
	_add_target(
		"no_addressee",
		"3-3 没有收件人的纸",
		"letter",
		"Refuse",
		["audio", "relation"],
		58,
		40,
		56,
		"纸想被交出去，却一直没有写上要去哪里。",
		"朋友没有替它决定方向。纸安静地落回抽屉。",
		"先听见它想走，再比较它没有去处。",
		Color(0.92, 0.80, 1.0),
		Vector2(820, FLOOR_Y - 78)
	)
	targets[targets.size() - 1].cost_limit = 18
	_add_target(
		"drawer_echo",
		"3-4 抽屉里的回声",
		"bell",
		"Stop",
		["memory", "waiting", "silence"],
		36,
		48,
		58,
		"抽屉自己开了一条缝。里面没有声音，却像记得所有声音。",
		"朋友停下来。那条缝没有合上，也没有要求她进去。",
		"记住，再等。沉默够久的时候，停下就好了。",
		Color(0.78, 0.78, 0.96),
		Vector2(828, FLOOR_Y - 92)
	)
	targets[targets.size() - 1].silence_required = 44

func _add_background() -> void:
	super._add_background()
	for i in range(6):
		var paper := ColorRect.new()
		paper.color = Color(0.90, 0.88, 1.0, 0.045)
		paper.position = Vector2(96 + i * 190, 122 + (i % 3) * 82)
		paper.size = Vector2(96, 58)
		paper.rotation = -0.08 + i * 0.025
		paper.z_index = -80
		add_child(paper)

func _add_pickups_for_task() -> void:
	var nodes: Array[String] = []
	if task_index == 0:
		nodes = ["Listen", "Remember", "Quiet"]
	elif task_index == 1:
		nodes = ["See", "Compare", "Push"]
	elif task_index == 2:
		nodes = ["Refuse"]
	elif task_index == 3:
		nodes = ["Wait", "Stop"]
	for i in range(nodes.size()):
		var block_id: String = nodes[i]
		if not inventory.has_block(block_id):
			_create_pickup(block_id, Vector2(280 + i * 138, FLOOR_Y - 62), _block_color(block_id))

func run_friend_workflow(actor: Node2D, sequence: Array[String]) -> bool:
	var success: bool = await super.run_friend_workflow(actor, sequence)
	if not success:
		remembered_failures += 1
		_say("那句回声被抽屉记住了。")
	return success
