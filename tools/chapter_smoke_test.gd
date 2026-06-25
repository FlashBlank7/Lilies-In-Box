extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ROOM_SCENE := preload("res://scenes/Room01.tscn")
const ROOM_02_SCENE := preload("res://scenes/Room02.tscn")

var main: Node
var room: Node
var room2: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await _test_main_start_screen()

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
	_assert_equal(loaded_scene.name, "Room01", "main starts with Chapter 1")
	await main.call("_on_chapter_one_completed")
	var loaded_room_02: Node = main.get("current_scene") as Node
	_assert_bool(loaded_room_02 != null, "main loads level 2 after chapter 1")
	_assert_equal(loaded_room_02.name, "Room02", "main transitions to Level 2")
	await main.call("_on_level_two_completed")
	_assert_bool(bool(main.get("awaiting_end_restart")), "main waits on ending after level 2")
	_assert_bool(main.get("current_scene") == null, "main clears level 2 after ending")
	main.queue_free()
	await process_frame
	await process_frame
	main = null

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
