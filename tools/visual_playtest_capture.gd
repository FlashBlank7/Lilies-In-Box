extends SceneTree

const CHAPTER_02_SCENE := preload("res://scenes/Chapter02Workflow.tscn")
const CHAPTER_03_SCENE := preload("res://scenes/Chapter03Workflow.tscn")
const FINALE_SCENE := preload("res://scenes/FinaleWorkflow.tscn")

const OUTPUT_DIR := "/tmp/lilies_playtest_captures"
const ALL_BLOCKS: Array[String] = ["See", "Compare", "Push", "Listen", "Quiet", "Remember", "Hold", "Wait", "Refuse", "Stop"]

var active_scene: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	await _capture_workflow_scene(CHAPTER_02_SCENE, "chapter2_first.png", 0, ALL_BLOCKS, false)
	await _capture_workflow_scene(CHAPTER_02_SCENE, "chapter2_drawer.png", 0, ALL_BLOCKS, true)
	await _capture_chapter2_cost_shadow()
	await _capture_workflow_scene(CHAPTER_03_SCENE, "chapter3_first.png", 0, ALL_BLOCKS, false)
	await _capture_workflow_scene(CHAPTER_03_SCENE, "chapter3_drawer.png", 0, ALL_BLOCKS, true)
	await _capture_chapter3_failure()
	await _capture_workflow_scene(FINALE_SCENE, "finale_first.png", 0, ALL_BLOCKS, false)
	await _capture_workflow_scene(FINALE_SCENE, "finale_drawer.png", 0, ALL_BLOCKS, true)
	print("Visual playtest captures written to %s" % OUTPUT_DIR)
	quit(0)

func _capture_workflow_scene(scene_resource: PackedScene, file_name: String, task_index: int, blocks: Array[String], open_drawer: bool) -> void:
	await _clear_current_scene()
	active_scene = scene_resource.instantiate()
	if active_scene.has_method("configure_stage"):
		active_scene.call("configure_stage", task_index, blocks)
	root.add_child(active_scene)
	await process_frame
	await process_frame
	await create_timer(2.05).timeout
	if open_drawer:
		var builder: CanvasLayer = active_scene.get("builder") as CanvasLayer
		if builder != null:
			builder.visible = true
	await process_frame
	await _save_viewport(file_name)

func _capture_chapter3_failure() -> void:
	await _clear_current_scene()
	active_scene = CHAPTER_03_SCENE.instantiate()
	if active_scene.has_method("configure_stage"):
		active_scene.call("configure_stage", 0, ALL_BLOCKS)
	root.add_child(active_scene)
	await process_frame
	await process_frame
	await create_timer(2.05).timeout
	var sequence: Array[String] = ["Listen", "Quiet"]
	active_scene.call("_deploy_friend", sequence)
	await create_timer(2.5).timeout
	await _save_viewport("chapter3_failure_echo.png")

func _capture_chapter2_cost_shadow() -> void:
	await _clear_current_scene()
	active_scene = CHAPTER_02_SCENE.instantiate()
	if active_scene.has_method("configure_stage"):
		active_scene.call("configure_stage", 2, ALL_BLOCKS)
	root.add_child(active_scene)
	await process_frame
	await process_frame
	await create_timer(2.05).timeout
	var sequence: Array[String] = ["See", "Compare", "Push"]
	active_scene.call("_deploy_friend", sequence)
	await create_timer(3.2).timeout
	await _wait_for_friend_idle(active_scene)
	await _save_viewport("chapter2_cost_shadow.png")
	var recovery_sequence: Array[String] = ["See", "Wait", "Push"]
	active_scene.call("_deploy_friend", recovery_sequence)
	await create_timer(4.0).timeout
	await _wait_for_friend_idle(active_scene)
	await _save_viewport("chapter2_cost_recovery.png")

func _wait_for_friend_idle(scene: Node) -> void:
	var friend: Node = scene.get("friend") as Node
	for i in range(90):
		if friend == null or not bool(friend.get("active")):
			return
		await process_frame

func _save_viewport(file_name: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("Could not read viewport image for %s. Run without --headless for visual captures." % file_name)
		return
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		push_error("Could not save %s: %s" % [file_name, error])

func _clear_current_scene() -> void:
	if active_scene != null and is_instance_valid(active_scene):
		active_scene.queue_free()
		active_scene = null
		await process_frame
		await process_frame
