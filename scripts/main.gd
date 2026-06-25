extends Node2D

const ROOM_01_SCENE := preload("res://scenes/Room01.tscn")
const ROOM_02_SCENE := preload("res://scenes/Room02.tscn")
const CHAPTER_01_SCENE := preload("res://scenes/Chapter01Workflow.tscn")
const BG_TEXTURE := preload("res://assets/environment/gothicvania/backgrounds.png")

const MENU_MAIN := "main"
const MENU_SELECT := "select"
const MENU_END := "end"

const MAIN_MENU_ITEMS: Array[String] = ["开始新游戏", "选择关卡", "退出/返回标题"]
const END_MENU_ITEMS: Array[String] = ["回到开始", "选择关卡"]
const STAGE_IDS: Array[String] = [
	"prologue_p1",
	"prologue_p2",
	"prologue_p3",
	"echo_steps",
	"chapter1_1",
	"chapter1_2",
	"chapter1_3",
	"chapter1_4",
]
const STAGE_NAMES: Array[String] = [
	"P-1 先学会看见",
	"P-2 记忆的重量",
	"P-3 回声门",
	"Prologue 回声台阶",
	"1-1 会害怕的门",
	"1-2 低声花",
	"1-3 不确定的台阶",
	"1-4 疑问的影子",
]

var current_scene: Node
var start_layer: CanvasLayer
var end_layer: CanvasLayer
var fade_rect: ColorRect
var menu_title_label: Label
var menu_subtitle_label: Label
var menu_hint_label: Label
var menu_labels: Array[Label] = []
var awaiting_start := true
var awaiting_end_restart := false
var transitioning := false
var menu_mode := MENU_MAIN
var selected_menu_index := 0
var selected_stage_index := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_start_screen(MENU_MAIN)

func _input(event: InputEvent) -> void:
	if transitioning or not _menu_is_open():
		return
	if _is_menu_up(event):
		_move_menu_selection(-1)
		get_viewport().set_input_as_handled()
	elif _is_menu_down(event):
		_move_menu_selection(1)
		get_viewport().set_input_as_handled()
	elif _is_confirm_event(event):
		get_viewport().set_input_as_handled()
		await _confirm_menu_selection()
	elif _is_back_event(event):
		get_viewport().set_input_as_handled()
		await _back_menu()

func _menu_is_open() -> bool:
	return (start_layer != null and is_instance_valid(start_layer)) or (end_layer != null and is_instance_valid(end_layer))

func _is_menu_up(event: InputEvent) -> bool:
	return event.is_action_pressed("move_up")

func _is_menu_down(event: InputEvent) -> bool:
	return event.is_action_pressed("move_down")

func _is_confirm_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("deploy_friend"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	return false

func _is_back_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE
	return false

func _move_menu_selection(delta: int) -> void:
	var count := _menu_item_count()
	if count <= 0:
		return
	if menu_mode == MENU_SELECT:
		selected_stage_index = wrapi(selected_stage_index + delta, 0, count)
	else:
		selected_menu_index = wrapi(selected_menu_index + delta, 0, count)
	_refresh_menu_labels()

func _menu_item_count() -> int:
	if menu_mode == MENU_SELECT:
		return STAGE_NAMES.size()
	if menu_mode == MENU_END:
		return END_MENU_ITEMS.size()
	return MAIN_MENU_ITEMS.size()

func _confirm_menu_selection() -> void:
	if menu_mode == MENU_SELECT:
		await start_stage(STAGE_IDS[selected_stage_index])
		return
	if menu_mode == MENU_END:
		if selected_menu_index == 0:
			await return_to_title()
		else:
			await _return_to_title_to_mode(MENU_SELECT)
		return
	if selected_menu_index == 0:
		await start_full_run()
	elif selected_menu_index == 1:
		menu_mode = MENU_SELECT
		selected_stage_index = 0
		_refresh_menu_labels()
	else:
		if current_scene != null or end_layer != null:
			await return_to_title()
		else:
			get_tree().quit()

func _back_menu() -> void:
	if menu_mode == MENU_SELECT:
		menu_mode = MENU_MAIN
		selected_menu_index = 0
		_refresh_menu_labels()
	elif menu_mode == MENU_END:
		await return_to_title()

func _build_start_screen(new_menu_mode: String) -> void:
	menu_mode = new_menu_mode
	awaiting_start = true
	awaiting_end_restart = false
	selected_menu_index = 0
	if menu_mode == MENU_SELECT:
		selected_stage_index = clampi(selected_stage_index, 0, STAGE_IDS.size() - 1)

	start_layer = CanvasLayer.new()
	start_layer.layer = 50
	add_child(start_layer)

	_add_menu_backdrop(start_layer, Vector2(-80, 70), Vector2(2.4, 2.4), 0.48)

	menu_title_label = Label.new()
	menu_title_label.position = Vector2(0, 152)
	menu_title_label.size = Vector2(1280, 70)
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 48)
	menu_title_label.modulate = Color(0.95, 0.93, 1.0)
	start_layer.add_child(menu_title_label)

	menu_subtitle_label = Label.new()
	menu_subtitle_label.position = Vector2(0, 232)
	menu_subtitle_label.size = Vector2(1280, 42)
	menu_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle_label.add_theme_font_size_override("font_size", 20)
	menu_subtitle_label.modulate = Color(0.74, 0.74, 0.88)
	start_layer.add_child(menu_subtitle_label)

	_build_menu_labels(start_layer, 310, 38)

	menu_hint_label = Label.new()
	menu_hint_label.position = Vector2(0, 632)
	menu_hint_label.size = Vector2(1280, 34)
	menu_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint_label.modulate = Color(0.62, 0.64, 0.78)
	start_layer.add_child(menu_hint_label)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.012, 0.012, 0.022, 1.0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.modulate.a = 0.0
	fade_rect.z_index = 100
	start_layer.add_child(fade_rect)
	_refresh_menu_labels()

func _add_menu_backdrop(layer: CanvasLayer, chapel_pos: Vector2, chapel_scale: Vector2, chapel_alpha: float) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.018, 0.030)
	bg.size = Vector2(1280, 720)
	layer.add_child(bg)

	var chapel := Sprite2D.new()
	chapel.texture = BG_TEXTURE
	chapel.centered = false
	chapel.position = chapel_pos
	chapel.scale = chapel_scale
	chapel.modulate = Color(0.50, 0.48, 0.70, chapel_alpha)
	layer.add_child(chapel)

	var mist := ColorRect.new()
	mist.color = Color(0.60, 0.68, 1.0, 0.08)
	mist.position = Vector2(0, 470)
	mist.size = Vector2(1280, 84)
	layer.add_child(mist)

func _build_menu_labels(layer: CanvasLayer, start_y: int, gap: int) -> void:
	menu_labels.clear()
	for i in range(max(MAIN_MENU_ITEMS.size(), STAGE_NAMES.size())):
		var label := Label.new()
		label.position = Vector2(0, start_y + i * gap)
		label.size = Vector2(1280, 34)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		layer.add_child(label)
		menu_labels.append(label)

func _refresh_menu_labels() -> void:
	var items: Array[String] = _current_menu_items()
	var selected_index := selected_stage_index if menu_mode == MENU_SELECT else selected_menu_index
	if menu_title_label != null:
		menu_title_label.text = "Lilies in Box" if menu_mode != MENU_END else "Demo 完成"
	if menu_subtitle_label != null:
		if menu_mode == MENU_SELECT:
			menu_subtitle_label.text = "选择一段已经开放的梦。"
		elif menu_mode == MENU_END:
			menu_subtitle_label.text = "莉莉丝把孤独折轻了一点。盒子还在，但它已经有了风。"
		else:
			menu_subtitle_label.text = "她醒在盒子里，先学会把孤独拼成朋友。"
	if menu_hint_label != null:
		menu_hint_label.text = "W/S 或方向键选择  Enter/Space/E确认  Esc/Backspace返回"
	for i in range(menu_labels.size()):
		var label: Label = menu_labels[i]
		if i >= items.size():
			label.visible = false
			continue
		label.visible = true
		label.text = (">  %s  <" % items[i]) if i == selected_index else items[i]
		label.modulate = Color(0.92, 0.94, 1.0) if i == selected_index else Color(0.62, 0.64, 0.78)

func _current_menu_items() -> Array[String]:
	if menu_mode == MENU_SELECT:
		return STAGE_NAMES.duplicate()
	if menu_mode == MENU_END:
		return END_MENU_ITEMS.duplicate()
	return MAIN_MENU_ITEMS.duplicate()

func start_full_run() -> void:
	await start_stage("prologue_p1")

func _start_game() -> void:
	await start_full_run()

func start_stage(stage_id: String) -> void:
	if transitioning:
		return
	transitioning = true
	awaiting_start = false
	awaiting_end_restart = false
	await _fade_to(0.92, 0.35)
	_clear_menu_layers()
	_load_stage(stage_id)
	await _fade_from(0.42)
	transitioning = false

func _load_stage(stage_id: String) -> void:
	if stage_id == "prologue_p2":
		_load_room_01(1, ["See", "Push"])
	elif stage_id == "prologue_p3":
		_load_room_01(2, ["See", "Push", "Remember"])
	elif stage_id == "echo_steps":
		_load_room_02()
	elif stage_id == "chapter1_1":
		_load_chapter_01(0, [])
	elif stage_id == "chapter1_2":
		_load_chapter_01(1, ["See", "Compare", "Push"])
	elif stage_id == "chapter1_3":
		_load_chapter_01(2, ["See", "Compare", "Push", "Listen", "Quiet"])
	elif stage_id == "chapter1_4":
		_load_chapter_01(3, ["See", "Compare", "Push", "Listen", "Quiet", "Remember", "Hold"])
	else:
		_load_room_01(0, [])

func _load_room_01(level_index: int, blocks: Array[String]) -> void:
	_clear_current_scene()
	current_scene = ROOM_01_SCENE.instantiate()
	if current_scene.has_method("configure_stage"):
		current_scene.call("configure_stage", level_index, blocks)
	add_child(current_scene)
	if current_scene.has_signal("chapter_completed"):
		current_scene.connect("chapter_completed", Callable(self, "_on_chapter_one_completed"))

func _load_room_02() -> void:
	_clear_current_scene()
	current_scene = ROOM_02_SCENE.instantiate()
	add_child(current_scene)
	if current_scene.has_signal("level_completed"):
		current_scene.connect("level_completed", Callable(self, "_on_level_two_completed"))

func _load_chapter_01(task_index: int, blocks: Array[String]) -> void:
	_clear_current_scene()
	current_scene = CHAPTER_01_SCENE.instantiate()
	if current_scene.has_method("configure_stage"):
		current_scene.call("configure_stage", task_index, blocks)
	add_child(current_scene)
	if current_scene.has_signal("chapter_completed"):
		current_scene.connect("chapter_completed", Callable(self, "_on_workflow_chapter_completed"))

func _on_chapter_one_completed() -> void:
	if transitioning:
		return
	transitioning = true
	await get_tree().create_timer(2.2).timeout
	await _fade_to(0.94, 0.45)
	_load_room_02()
	await _fade_from(0.50)
	transitioning = false

func _on_level_two_completed() -> void:
	if transitioning:
		return
	transitioning = true
	await get_tree().create_timer(1.2).timeout
	await _fade_to(0.94, 0.52)
	_load_chapter_01(0, [])
	await _fade_from(0.60)
	transitioning = false

func _on_workflow_chapter_completed() -> void:
	if transitioning:
		return
	transitioning = true
	await get_tree().create_timer(1.2).timeout
	await _fade_to(0.94, 0.52)
	_clear_current_scene()
	_build_end_screen()
	await _fade_from(0.60)
	awaiting_end_restart = true
	transitioning = false

func return_to_title() -> void:
	await _return_to_title_to_mode(MENU_MAIN)

func _return_to_title_to_mode(target_menu_mode: String) -> void:
	if transitioning:
		return
	transitioning = true
	awaiting_end_restart = false
	await _fade_to(0.94, 0.35)
	_clear_current_scene()
	_clear_menu_layers()
	_build_start_screen(target_menu_mode)
	await _fade_from(0.45)
	transitioning = false

func _build_end_screen() -> void:
	end_layer = CanvasLayer.new()
	end_layer.layer = 50
	add_child(end_layer)
	menu_mode = MENU_END
	selected_menu_index = 0
	awaiting_start = false
	awaiting_end_restart = true
	_add_menu_backdrop(end_layer, Vector2(-120, 54), Vector2(2.55, 2.55), 0.36)
	menu_title_label = Label.new()
	menu_title_label.position = Vector2(0, 194)
	menu_title_label.size = Vector2(1280, 70)
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 40)
	menu_title_label.modulate = Color(0.94, 0.92, 1.0)
	end_layer.add_child(menu_title_label)
	menu_subtitle_label = Label.new()
	menu_subtitle_label.position = Vector2(0, 292)
	menu_subtitle_label.size = Vector2(1280, 92)
	menu_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle_label.add_theme_font_size_override("font_size", 22)
	menu_subtitle_label.modulate = Color(0.76, 0.78, 0.92)
	end_layer.add_child(menu_subtitle_label)
	_build_menu_labels(end_layer, 430, 42)
	menu_hint_label = Label.new()
	menu_hint_label.position = Vector2(0, 620)
	menu_hint_label.size = Vector2(1280, 34)
	menu_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint_label.modulate = Color(0.62, 0.64, 0.78)
	end_layer.add_child(menu_hint_label)
	_refresh_menu_labels()

func _clear_menu_layers() -> void:
	if start_layer != null and is_instance_valid(start_layer):
		start_layer.queue_free()
	start_layer = null
	if end_layer != null and is_instance_valid(end_layer):
		end_layer.queue_free()
	end_layer = null
	menu_labels.clear()
	fade_rect = null

func _clear_current_scene() -> void:
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
	current_scene = null

func _fade_to(alpha: float, duration: float) -> void:
	var overlay := _ensure_overlay()
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", alpha, duration)
	await tween.finished

func _fade_from(duration: float) -> void:
	var overlay := _ensure_overlay()
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, duration)
	await tween.finished

func _ensure_overlay() -> ColorRect:
	if fade_rect != null and is_instance_valid(fade_rect):
		return fade_rect
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.012, 0.012, 0.022, 1.0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.modulate.a = 0.0
	layer.add_child(fade_rect)
	return fade_rect
