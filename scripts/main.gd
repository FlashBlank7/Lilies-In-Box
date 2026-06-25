extends Node2D

const ROOM_01_SCENE := preload("res://scenes/Room01.tscn")
const ROOM_02_SCENE := preload("res://scenes/Room02.tscn")
const CHAPTER_01_SCENE := preload("res://scenes/Chapter01Workflow.tscn")
const BG_TEXTURE := preload("res://assets/environment/gothicvania/backgrounds.png")

var current_scene: Node
var start_layer: CanvasLayer
var end_layer: CanvasLayer
var fade_rect: ColorRect
var awaiting_start := true
var awaiting_end_restart := false
var transitioning := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_start_screen()

func _unhandled_input(event: InputEvent) -> void:
	if awaiting_start and _is_start_event(event):
		get_viewport().set_input_as_handled()
		await _start_game()
	elif awaiting_end_restart and _is_start_event(event):
		get_viewport().set_input_as_handled()
		await _return_to_title()

func _is_start_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("deploy_friend"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	return false

func _build_start_screen() -> void:
	start_layer = CanvasLayer.new()
	start_layer.layer = 50
	add_child(start_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.018, 0.030)
	bg.size = Vector2(1280, 720)
	start_layer.add_child(bg)

	var chapel := Sprite2D.new()
	chapel.texture = BG_TEXTURE
	chapel.centered = false
	chapel.position = Vector2(-80, 70)
	chapel.scale = Vector2(2.4, 2.4)
	chapel.modulate = Color(0.50, 0.48, 0.70, 0.48)
	start_layer.add_child(chapel)

	var mist := ColorRect.new()
	mist.color = Color(0.60, 0.68, 1.0, 0.08)
	mist.position = Vector2(0, 470)
	mist.size = Vector2(1280, 84)
	start_layer.add_child(mist)

	var title := Label.new()
	title.text = "Lilies in Box"
	title.position = Vector2(0, 184)
	title.size = Vector2(1280, 74)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color(0.95, 0.93, 1.0)
	start_layer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "她醒在盒子里，先学会把孤独拼成朋友。"
	subtitle.position = Vector2(0, 270)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.modulate = Color(0.74, 0.74, 0.88)
	start_layer.add_child(subtitle)

	var start := Label.new()
	start.text = "按 Enter / Space 开始"
	start.position = Vector2(0, 430)
	start.size = Vector2(1280, 40)
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.add_theme_font_size_override("font_size", 23)
	start.modulate = Color(0.88, 0.90, 1.0)
	start_layer.add_child(start)

	var hint := Label.new()
	hint.text = "A/D移动  W或Space轻跳  E拾取  Tab拼装"
	hint.position = Vector2(0, 620)
	hint.size = Vector2(1280, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.62, 0.64, 0.78)
	start_layer.add_child(hint)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.012, 0.012, 0.022, 1.0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.modulate.a = 0.0
	fade_rect.z_index = 100
	start_layer.add_child(fade_rect)

func _start_game() -> void:
	if transitioning:
		return
	transitioning = true
	awaiting_start = false
	await _fade_to(0.92, 0.38)
	if start_layer != null:
		start_layer.queue_free()
		start_layer = null
	if end_layer != null:
		end_layer.queue_free()
		end_layer = null
	_load_room_01()
	await _fade_from(0.42)
	transitioning = false

func _load_room_01() -> void:
	_clear_current_scene()
	current_scene = ROOM_01_SCENE.instantiate()
	add_child(current_scene)
	if current_scene.has_signal("chapter_completed"):
		current_scene.connect("chapter_completed", Callable(self, "_on_chapter_one_completed"))

func _on_chapter_one_completed() -> void:
	if transitioning:
		return
	transitioning = true
	await get_tree().create_timer(2.2).timeout
	await _fade_to(0.94, 0.45)
	_clear_current_scene()
	current_scene = ROOM_02_SCENE.instantiate()
	add_child(current_scene)
	if current_scene.has_signal("level_completed"):
		current_scene.connect("level_completed", Callable(self, "_on_level_two_completed"))
	await _fade_from(0.50)
	transitioning = false

func _on_level_two_completed() -> void:
	if transitioning:
		return
	transitioning = true
	await get_tree().create_timer(1.2).timeout
	await _fade_to(0.94, 0.52)
	_clear_current_scene()
	current_scene = CHAPTER_01_SCENE.instantiate()
	add_child(current_scene)
	if current_scene.has_signal("chapter_completed"):
		current_scene.connect("chapter_completed", Callable(self, "_on_workflow_chapter_completed"))
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

func _return_to_title() -> void:
	if transitioning:
		return
	transitioning = true
	awaiting_end_restart = false
	await _fade_to(0.94, 0.35)
	if end_layer != null:
		end_layer.queue_free()
		end_layer = null
	_build_start_screen()
	awaiting_start = true
	await _fade_from(0.45)
	transitioning = false

func _build_end_screen() -> void:
	end_layer = CanvasLayer.new()
	end_layer.layer = 50
	add_child(end_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.014, 0.015, 0.026)
	bg.size = Vector2(1280, 720)
	end_layer.add_child(bg)

	var chapel := Sprite2D.new()
	chapel.texture = BG_TEXTURE
	chapel.centered = false
	chapel.position = Vector2(-120, 54)
	chapel.scale = Vector2(2.55, 2.55)
	chapel.modulate = Color(0.46, 0.50, 0.72, 0.36)
	end_layer.add_child(chapel)

	var title := Label.new()
	title.text = "Demo 完成"
	title.position = Vector2(0, 210)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.modulate = Color(0.94, 0.92, 1.0)
	end_layer.add_child(title)

	var text := Label.new()
	text.text = "莉莉丝把孤独折轻了一点。\n盒子还在，但它已经有了风。"
	text.position = Vector2(0, 306)
	text.size = Vector2(1280, 90)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 22)
	text.modulate = Color(0.76, 0.78, 0.92)
	end_layer.add_child(text)

	var restart := Label.new()
	restart.text = "按 Enter / Space 回到开始"
	restart.position = Vector2(0, 476)
	restart.size = Vector2(1280, 40)
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.add_theme_font_size_override("font_size", 22)
	restart.modulate = Color(0.88, 0.90, 1.0)
	end_layer.add_child(restart)

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
