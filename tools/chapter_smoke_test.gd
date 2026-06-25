extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ROOM_SCENE := preload("res://scenes/Room01.tscn")
const ROOM_02_SCENE := preload("res://scenes/Room02.tscn")
const CHAPTER_01_SCENE := preload("res://scenes/Chapter01Workflow.tscn")
const EncounterTargetScript := preload("res://scripts/encounter_target.gd")

var main: Node
var room: Node
var room2: Node
var chapter1: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_workflow_evaluator()
	await _test_main_start_screen()
	await _test_stage_select_loading()

	room = ROOM_SCENE.instantiate()
	root.add_child(room)
	await process_frame
	await process_frame

	_assert_equal(_get_level_index(), 0, "chapter starts at level 0")
	_assert_equal(_required_text(), "See -> Push", "level 1 required sequence")

	await _solve_level(["See", "Push"], 0, true)
	_assert_equal(_get_level_index(), 1, "level 1 advances to level 2")
	_assert_equal(_required_text(), "See -> Remember -> Push", "level 2 required sequence")

	await _solve_level(["See", "Remember", "Push"], 1, true)
	_assert_equal(_get_level_index(), 2, "level 2 advances to level 3")
	_assert_equal(_required_text(), "Remember -> See -> Push", "level 3 required sequence")

	await _solve_level(["Remember", "See", "Push"], 2, false)
	_assert_bool(_get_bool("chapter_complete"), "chapter is complete after third door")

	await room.call("_restart_chapter")
	await process_frame
	await process_frame
	_assert_equal(_get_level_index(), 0, "restart returns to level 1")
	_assert_bool(not _get_bool("chapter_complete"), "restart clears chapter completion")
	_assert_bool(not _get_bool("door_open"), "restart closes the door")
	_assert_equal(_inventory_size(), 0, "restart clears inventory")

	await _cleanup_room_01()
	await _test_room_02()
	await _test_chapter_01_workflow()

	print("Chapter smoke test passed.")
	await _cleanup_all()
	quit(0)

func _solve_level(sequence: Array[String], expected_level: int, should_advance: bool) -> void:
	_assert_equal(_get_level_index(), expected_level, "level index before solve")
	_add_required_blocks(sequence)
	room.call("_deploy_friend", sequence)
	await create_timer(3.2).timeout
	_assert_bool(_get_bool("door_open"), "door opens after routine")
	await room.call("_finish_room")
	await create_timer(0.2).timeout
	if should_advance:
		_assert_equal(_get_level_index(), expected_level + 1, "level advances after exit")

func _add_required_blocks(sequence: Array[String]) -> void:
	var inventory: Node = room.get("inventory") as Node
	for i in range(sequence.size()):
		var block_id: String = sequence[i]
		inventory.call("add_block", block_id)

func _required_text() -> String:
	return String(room.call("_level_required_text"))

func _get_level_index() -> int:
	return int(room.get("chapter_level_index"))

func _get_bool(property_name: String) -> bool:
	return bool(room.get(property_name))

func _inventory_size() -> int:
	var inventory: Node = room.get("inventory") as Node
	var blocks: Array[String] = inventory.call("all_blocks")
	return blocks.size()

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_bool(value: bool, label: String) -> void:
	if not value:
		_fail(label)

func _fail(message: String) -> void:
	push_error(message)
	if main != null and is_instance_valid(main):
		main.queue_free()
	if room != null and is_instance_valid(room):
		room.queue_free()
	if room2 != null and is_instance_valid(room2):
		room2.queue_free()
	if chapter1 != null and is_instance_valid(chapter1):
		chapter1.queue_free()
	quit(1)

func _test_main_start_screen() -> void:
	main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_assert_bool(bool(main.get("awaiting_start")), "main starts on title screen")
	await main.call("_start_game")
	await create_timer(1.2).timeout
	_assert_bool(not bool(main.get("awaiting_start")), "main leaves title screen after start")
	var loaded_scene: Node = main.get("current_scene") as Node
	_assert_bool(loaded_scene != null, "main loads a gameplay scene")
	_assert_equal(loaded_scene.name, "Room01", "main starts with Prologue")
	await main.call("_on_chapter_one_completed")
	var loaded_room_02: Node = main.get("current_scene") as Node
	_assert_bool(loaded_room_02 != null, "main loads Echo Steps after Prologue rooms")
	_assert_equal(loaded_room_02.name, "Room02", "main transitions to Prologue Echo Steps")
	await main.call("_on_level_two_completed")
	var loaded_chapter_01: Node = main.get("current_scene") as Node
	_assert_bool(loaded_chapter_01 != null, "main loads Chapter 1 after Prologue")
	_assert_equal(loaded_chapter_01.name, "Chapter01Workflow", "main transitions to workflow Chapter 1")
	await main.call("_on_workflow_chapter_completed")
	_assert_bool(bool(main.get("awaiting_end_restart")), "main waits on ending after Chapter 1")
	_assert_bool(main.get("current_scene") == null, "main clears Chapter 1 after ending")
	_assert_equal(String(main.get("menu_mode")), "end", "main uses ending menu mode")
	await main.call("return_to_title")
	await create_timer(1.0).timeout
	_assert_bool(bool(main.get("awaiting_start")), "main returns to title after ending")
	_assert_equal(String(main.get("menu_mode")), "main", "main menu mode restored after ending")
	_assert_bool(main.get("current_scene") == null, "return to title keeps gameplay scene clear")
	await main.call("start_full_run")
	await create_timer(1.2).timeout
	var restarted_scene: Node = main.get("current_scene") as Node
	_assert_equal(restarted_scene.name, "Room01", "main can start again after returning to title")
	main.queue_free()
	await process_frame
	await process_frame
	main = null

func _test_stage_select_loading() -> void:
	await _assert_stage_loads("prologue_p3", "Room01", 2, ["See", "Push", "Remember"])
	await _assert_stage_loads("echo_steps", "Room02", -1, [])
	await _assert_stage_loads("chapter1_4", "Chapter01Workflow", 3, ["See", "Compare", "Push", "Listen", "Quiet", "Remember", "Hold"])

func _assert_stage_loads(stage_id: String, expected_scene_name: String, expected_index: int, expected_blocks: Array[String]) -> void:
	main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await main.call("start_stage", stage_id)
	await create_timer(1.0).timeout
	var loaded_scene: Node = main.get("current_scene") as Node
	_assert_bool(loaded_scene != null, "stage loads gameplay scene")
	_assert_equal(loaded_scene.name, expected_scene_name, "stage %s loads expected scene" % stage_id)
	if expected_scene_name == "Room01":
		_assert_equal(int(loaded_scene.get("chapter_level_index")), expected_index, "prologue selected room index")
		_assert_inventory_contains(loaded_scene, expected_blocks, "prologue selected inventory")
	elif expected_scene_name == "Chapter01Workflow":
		_assert_equal(int(loaded_scene.get("task_index")), expected_index, "workflow selected task index")
		_assert_inventory_contains(loaded_scene, expected_blocks, "workflow selected inventory")
	main.queue_free()
	await process_frame
	await process_frame
	main = null

func _assert_inventory_contains(owner: Node, expected_blocks: Array[String], label: String) -> void:
	var inventory: Node = owner.get("inventory") as Node
	for i in range(expected_blocks.size()):
		var block_id: String = expected_blocks[i]
		_assert_bool(bool(inventory.call("has_block", block_id)), "%s contains %s" % [label, block_id])

func _test_room_02() -> void:
	room2 = ROOM_02_SCENE.instantiate()
	root.add_child(room2)
	await process_frame
	await process_frame
	_assert_equal(int(room2.get("petals_collected")), 0, "level 2 starts with no petals")
	await _collect_room_02_petal(Vector2(390, 468))
	await _collect_room_02_petal(Vector2(620, 410))
	await _collect_room_02_petal(Vector2(856, 352))
	_assert_bool(bool(room2.get("door_open")), "level 2 door opens after petals")
	await room2.call("_finish_level")
	await create_timer(1.0).timeout
	_assert_bool(bool(room2.get("level_complete")), "level 2 completes")

func _test_workflow_evaluator() -> void:
	var door: EncounterTarget = _make_eval_target("fearful_door", "会害怕的门", "door", "Push", ["visual", "relation"], 70, 24, 60)
	var ok: WorkflowResult = WorkflowEvaluator.evaluate(["See", "Compare", "Push"], door)
	_assert_bool(ok.success, "workflow evaluator accepts confident door workflow")
	var missing: WorkflowResult = WorkflowEvaluator.evaluate(["See", "Push"], door)
	_assert_bool(not missing.success, "workflow evaluator rejects missing relation evidence")
	_assert_bool(missing.next_hint.contains("Compare"), "missing relation suggests Compare")
	var early: WorkflowResult = WorkflowEvaluator.evaluate(["Push", "See", "Compare"], door)
	_assert_bool(not early.success and early.failure_reason.contains("太早"), "workflow evaluator rejects early terminal action")
	_assert_bool(early.next_hint.contains("最后"), "early terminal suggests terminal last")
	var step: EncounterTarget = _make_eval_target("step", "不确定的台阶", "step", "Push", ["visual", "memory", "steady"], 64, 76, 48)
	var no_hold: WorkflowResult = WorkflowEvaluator.evaluate(["Remember", "See", "Push"], step)
	_assert_bool(not no_hold.success, "workflow evaluator rejects high-risk step workflow")
	_assert_bool(no_hold.next_hint.contains("Hold"), "high-risk workflow suggests Hold")
	var hold: WorkflowResult = WorkflowEvaluator.evaluate(["Remember", "See", "Hold", "Push"], step)
	_assert_bool(hold.success, "workflow evaluator accepts Hold risk control")
	_assert_equal(hold.steps.size(), 4, "workflow result records one step per node")

func _make_eval_target(
	target_id: String,
	title: String,
	kind: String,
	action: String,
	evidence: Array[String],
	confidence: int,
	base_risk: int,
	risk_limit: int
) -> EncounterTarget:
	var target: EncounterTarget = EncounterTargetScript.new()
	target.configure(target_id, title, kind, action, evidence, confidence, base_risk, risk_limit, "", "", "", Color.WHITE, Vector2.ZERO)
	return target

func _test_chapter_01_workflow() -> void:
	chapter1 = CHAPTER_01_SCENE.instantiate()
	root.add_child(chapter1)
	await process_frame
	await process_frame
	_assert_equal(int(chapter1.get("task_index")), 0, "workflow chapter starts at task 0")
	var failing_sequence: Array[String] = ["See", "Push"]
	_add_workflow_blocks(failing_sequence)
	chapter1.call("_deploy_friend", failing_sequence)
	await create_timer(2.0).timeout
	_assert_bool(not bool(chapter1.get("task_resolved")), "failed workflow does not resolve task")
	var failed_result: WorkflowResult = chapter1.get("last_result") as WorkflowResult
	_assert_bool(failed_result.next_hint.contains("Compare"), "chapter failure exposes actionable next hint")
	var builder: Node = chapter1.get("builder") as Node
	_assert_bool(String(builder.get("next_hint")).contains("Compare"), "builder displays actionable next hint")
	await _solve_workflow_task(["See", "Compare", "Push"], 0, true)
	await _solve_workflow_task(["See", "Listen", "Quiet"], 1, true)
	await _solve_workflow_task(["Remember", "See", "Hold", "Push"], 2, true)
	await _solve_workflow_task(["Listen", "Remember", "Compare", "Quiet"], 3, false)
	_assert_bool(bool(chapter1.get("chapter_complete")), "workflow Chapter 1 completes after four tasks")

func _solve_workflow_task(sequence: Array[String], expected_task: int, should_advance: bool) -> void:
	_assert_equal(int(chapter1.get("task_index")), expected_task, "workflow task index before solve")
	_add_workflow_blocks(sequence)
	chapter1.call("_deploy_friend", sequence)
	await create_timer(2.4).timeout
	_assert_bool(bool(chapter1.get("task_resolved")), "workflow task resolves after successful run")
	await chapter1.call("_finish_task")
	await create_timer(0.2).timeout
	if should_advance:
		_assert_equal(int(chapter1.get("task_index")), expected_task + 1, "workflow task advances")

func _add_workflow_blocks(sequence: Array[String]) -> void:
	var inventory: Node = chapter1.get("inventory") as Node
	for i in range(sequence.size()):
		var block_id: String = sequence[i]
		if not bool(inventory.call("has_block", block_id)):
			inventory.call("add_block", block_id)

func _collect_room_02_petal(pos: Vector2) -> void:
	var player: Node2D = room2.get("player") as Node2D
	player.global_position = pos
	await room2.call("_try_collect_petal")
	await process_frame

func _cleanup_room_01() -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
		await process_frame
		await process_frame
		room = null

func _cleanup_all() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame
		main = null
	await _cleanup_room_01()
	if room2 != null and is_instance_valid(room2):
		room2.queue_free()
		await process_frame
		await process_frame
		room2 = null
	if chapter1 != null and is_instance_valid(chapter1):
		chapter1.queue_free()
		await process_frame
		await process_frame
		chapter1 = null
