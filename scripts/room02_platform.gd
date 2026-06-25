extends Node2D

signal level_completed

const LiliesPlayerSceneScript := preload("res://scripts/player.gd")
const BG_TEXTURE := preload("res://assets/environment/gothicvania/backgrounds.png")
const COLUMN_TEXTURE := preload("res://assets/environment/gothicvania/column.png")
const BGM_STREAM := preload("res://assets/audio/heavenly_loop.ogg")
const SFX_PICKUP := preload("res://assets/audio/sfx/pickup_chime.wav")
const SFX_DOOR := preload("res://assets/audio/sfx/door_open.wav")
const SFX_ERROR := preload("res://assets/audio/sfx/soft_error.wav")
const SFX_CHAPTER := preload("res://assets/audio/sfx/chapter_complete.wav")

const FLOOR_Y := 586.0
const PLAYER_SPAWN := Vector2(112.0, 551.0)
const PETAL_COUNT := 3

var player: LiliesPlayer
var status_label: Label
var objective_label: Label
var prompt_label: Label
var progress_label: Label
var door: Node2D
var door_visual: ColorRect
var door_glow: ColorRect
var pickup_sfx: AudioStreamPlayer
var door_sfx: AudioStreamPlayer
var error_sfx: AudioStreamPlayer
var complete_sfx: AudioStreamPlayer
var petals: Array[Area2D] = []
var active_petal: Area2D = null
var petals_collected := 0
var door_open := false
var level_complete := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_world()
	_say("第二关：回声台阶。她终于要自己跳过一点点空白。")
	_update_guidance()
	_show_title()

func _process(_delta: float) -> void:
	_animate_petals()
	active_petal = _nearest_petal(78.0)
	_update_prompt()
	_update_guidance()
	if door_open and not level_complete and player.global_position.distance_to(door.global_position) < 96.0:
		await _finish_level()
	if player.global_position.y > 760.0 and not level_complete:
		_respawn_player()

func _unhandled_input(event: InputEvent) -> void:
	if level_complete:
		return
	if event.is_action_pressed("interact"):
		_try_collect_petal()
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	_add_background()
	_add_platforms()
	_add_player()
	_add_petals()
	_add_door()
	_add_audio()
	_add_ui()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.022, 0.024, 0.037)
	bg.size = Vector2(1280, 720)
	bg.z_index = -100
	add_child(bg)

	var chapel := Sprite2D.new()
	chapel.texture = BG_TEXTURE
	chapel.centered = false
	chapel.position = Vector2(-54, 80)
	chapel.scale = Vector2(2.35, 2.35)
	chapel.modulate = Color(0.48, 0.50, 0.70, 0.54)
	chapel.z_index = -94
	add_child(chapel)

	_add_column(Vector2(54, 220), 2.18, 0.36)
	_add_column(Vector2(462, 206), 1.76, 0.34)
	_add_column(Vector2(942, 188), 2.05, 0.42)

	var moon := ColorRect.new()
	moon.color = Color(0.72, 0.78, 1.0, 0.18)
	moon.position = Vector2(982, 92)
	moon.size = Vector2(94, 94)
	moon.z_index = -88
	add_child(moon)

	for i in range(4):
		var veil := ColorRect.new()
		veil.color = Color(0.62, 0.72, 1.0, 0.055)
		veil.position = Vector2(80 + i * 280, 188 + i * 18)
		veil.size = Vector2(230, 18)
		veil.z_index = -82
		add_child(veil)

func _add_column(pos: Vector2, scale_value: float, alpha: float) -> void:
	var column := Sprite2D.new()
	column.texture = COLUMN_TEXTURE
	column.centered = false
	column.position = pos
	column.scale = Vector2(scale_value, scale_value)
	column.modulate = Color(0.50, 0.50, 0.70, alpha)
	column.z_index = -86
	add_child(column)

func _add_platforms() -> void:
	_add_platform("Ground", Vector2(640, FLOOR_Y + 24), Vector2(1500, 48), Vector2(0, FLOOR_Y - 18), Vector2(1280, 42), 0.58)
	_add_platform("StepA", Vector2(390, 536), Vector2(190, 24), Vector2(296, 512), Vector2(188, 26), 0.76)
	_add_platform("StepB", Vector2(620, 478), Vector2(190, 24), Vector2(526, 454), Vector2(188, 26), 0.82)
	_add_platform("StepC", Vector2(856, 420), Vector2(196, 24), Vector2(758, 396), Vector2(196, 26), 0.88)
	_add_platform("DoorStep", Vector2(1110, 420), Vector2(210, 24), Vector2(1005, 396), Vector2(210, 26), 0.92)

func _add_platform(node_name: String, body_pos: Vector2, shape_size: Vector2, visual_pos: Vector2, visual_size: Vector2, alpha: float) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = body_pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = shape_size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

	var visual := ColorRect.new()
	visual.color = Color(0.30, 0.29, 0.47, alpha)
	visual.position = visual_pos
	visual.size = visual_size
	visual.z_index = -35
	add_child(visual)

	var lip := ColorRect.new()
	lip.color = Color(0.68, 0.70, 0.95, 0.34)
	lip.position = visual_pos
	lip.size = Vector2(visual_size.x, 4)
	lip.z_index = -34
	add_child(lip)

func _add_player() -> void:
	player = LiliesPlayerSceneScript.new()
	player.position = PLAYER_SPAWN
	player.jump_velocity = -410.0
	player.speed = 198.0
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _make_lilith_frames()
	sprite.animation = "idle"
	sprite.scale = Vector2(3.0, 3.0)
	sprite.position = Vector2(0, -4)
	sprite.modulate = Color(1.12, 1.12, 1.26)
	player.add_child(sprite)
	sprite.play("idle")

	var veil := Polygon2D.new()
	veil.polygon = PackedVector2Array([
		Vector2(-23, -48),
		Vector2(0, -64),
		Vector2(23, -48),
		Vector2(18, -20),
		Vector2(0, -8),
		Vector2(-18, -20),
	])
	veil.color = Color(0.95, 0.94, 1.0, 0.50)
	veil.z_index = 3
	player.add_child(veil)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 70)
	collision.shape = shape
	player.add_child(collision)
	add_child(player)

func _make_lilith_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 2.0)
	frames.add_frame("idle", load("res://assets/characters/lilith/Margery_Idle_Right_0.png") as Texture2D)
	frames.add_frame("idle", load("res://assets/characters/lilith/Margery_Idle_Right_1.png") as Texture2D)

	frames.add_animation("run")
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 8.0)
	for i in range(6):
		var path := "res://assets/characters/lilith/Margery_Run_Right_%d.png" % i
		frames.add_frame("run", load(path) as Texture2D)

	frames.add_animation("jump")
	frames.set_animation_loop("jump", true)
	frames.set_animation_speed("jump", 1.0)
	frames.add_frame("jump", load("res://assets/characters/lilith/Margery_Jump_Right_0.png") as Texture2D)
	return frames

func _add_petals() -> void:
	_create_petal("I", Vector2(390, 468))
	_create_petal("II", Vector2(620, 410))
	_create_petal("III", Vector2(856, 352))

func _create_petal(label_text: String, pos: Vector2) -> void:
	var area := Area2D.new()
	area.name = "EchoPetal%s" % label_text
	area.position = pos
	area.set_meta("petal_label", label_text)
	add_child(area)

	var visual := Node2D.new()
	visual.name = "EchoPetalVisual"
	area.add_child(visual)

	_add_echo_petal_visual(visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(62, 62)
	shape.shape = rect
	area.add_child(shape)
	petals.append(area)

func _add_echo_petal_visual(visual: Node2D) -> void:
	var outer_halo := Polygon2D.new()
	outer_halo.polygon = PackedVector2Array([
		Vector2(0, -42),
		Vector2(36, -7),
		Vector2(22, 34),
		Vector2(-24, 34),
		Vector2(-38, -7),
	])
	outer_halo.color = Color(0.66, 0.72, 1.0, 0.12)
	outer_halo.z_index = -3
	visual.add_child(outer_halo)

	var inner_halo := Polygon2D.new()
	inner_halo.polygon = PackedVector2Array([
		Vector2(0, -31),
		Vector2(25, -4),
		Vector2(15, 25),
		Vector2(-17, 25),
		Vector2(-27, -4),
	])
	inner_halo.color = Color(0.84, 0.88, 1.0, 0.18)
	inner_halo.z_index = -2
	visual.add_child(inner_halo)

	_add_petal_leaf(visual, PackedVector2Array([
		Vector2(0, -33),
		Vector2(12, -13),
		Vector2(0, -2),
		Vector2(-12, -13),
	]), Color(0.91, 0.91, 1.0, 0.78), 1)
	_add_petal_leaf(visual, PackedVector2Array([
		Vector2(-5, -4),
		Vector2(-30, -12),
		Vector2(-18, 8),
		Vector2(-3, 10),
	]), Color(0.72, 0.80, 1.0, 0.58), 0)
	_add_petal_leaf(visual, PackedVector2Array([
		Vector2(5, -4),
		Vector2(30, -12),
		Vector2(18, 8),
		Vector2(3, 10),
	]), Color(0.80, 0.75, 1.0, 0.58), 0)
	_add_petal_leaf(visual, PackedVector2Array([
		Vector2(0, 3),
		Vector2(11, 20),
		Vector2(0, 30),
		Vector2(-11, 20),
	]), Color(0.70, 0.88, 1.0, 0.48), -1)

	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, -9),
		Vector2(9, 0),
		Vector2(0, 9),
		Vector2(-9, 0),
	])
	core.color = Color(1.0, 0.98, 0.88, 0.92)
	core.z_index = 3
	visual.add_child(core)

	var stem := Line2D.new()
	stem.points = PackedVector2Array([
		Vector2(0, 9),
		Vector2(-4, 18),
		Vector2(3, 29),
	])
	stem.width = 2.0
	stem.default_color = Color(0.72, 0.92, 1.0, 0.42)
	stem.z_index = 2
	visual.add_child(stem)

	var glint := ColorRect.new()
	glint.color = Color(1.0, 1.0, 1.0, 0.88)
	glint.position = Vector2(3, -19)
	glint.size = Vector2(4, 4)
	glint.z_index = 4
	visual.add_child(glint)

func _add_petal_leaf(visual: Node2D, points: PackedVector2Array, color: Color, z: int) -> void:
	var leaf := Polygon2D.new()
	leaf.polygon = points
	leaf.color = color
	leaf.z_index = z
	visual.add_child(leaf)

func _add_door() -> void:
	door = Node2D.new()
	door.position = Vector2(1134, 358)
	add_child(door)

	door_glow = ColorRect.new()
	door_glow.color = Color(0.72, 0.76, 1.0, 1.0)
	door_glow.modulate.a = 0.0
	door_glow.position = Vector2(-42, -112)
	door_glow.size = Vector2(84, 144)
	door.add_child(door_glow)

	door_visual = ColorRect.new()
	door_visual.color = Color(0.070, 0.065, 0.110)
	door_visual.position = Vector2(-25, -104)
	door_visual.size = Vector2(50, 136)
	door.add_child(door_visual)

	var column := Sprite2D.new()
	column.texture = COLUMN_TEXTURE
	column.centered = false
	column.position = Vector2(-56, -126)
	column.scale = Vector2(1.5, 1.5)
	column.modulate = Color(0.58, 0.56, 0.78, 0.74)
	door.add_child(column)

func _add_audio() -> void:
	var bgm := AudioStreamPlayer.new()
	bgm.stream = BGM_STREAM
	bgm.volume_db = -15.0
	bgm.finished.connect(func(): bgm.play())
	add_child(bgm)
	bgm.play()
	pickup_sfx = _make_sfx_player("PickupSfx", SFX_PICKUP, -15.0)
	door_sfx = _make_sfx_player("DoorSfx", SFX_DOOR, -15.0)
	error_sfx = _make_sfx_player("ErrorSfx", SFX_ERROR, -18.0)
	complete_sfx = _make_sfx_player("CompleteSfx", SFX_CHAPTER, -14.0)

func _make_sfx_player(node_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.name = node_name
	player_node.stream = stream
	player_node.volume_db = volume_db
	add_child(player_node)
	return player_node

func _add_ui() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	objective_label = Label.new()
	objective_label.position = Vector2(34, 28)
	objective_label.size = Vector2(690, 44)
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.modulate = Color(0.92, 0.90, 1.0)
	hud.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(34, 82)
	status_label.size = Vector2(700, 74)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.modulate = Color(0.86, 0.84, 0.96)
	hud.add_child(status_label)

	progress_label = Label.new()
	progress_label.position = Vector2(768, 34)
	progress_label.size = Vector2(460, 32)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.modulate = Color(0.74, 0.78, 0.94)
	hud.add_child(progress_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 662)
	prompt_label.size = Vector2(1280, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 19)
	prompt_label.modulate = Color(0.86, 0.90, 1.0)
	hud.add_child(prompt_label)

	var controls := Label.new()
	controls.text = "A/D移动  W/Space轻跳  E拾取回声花瓣"
	controls.position = Vector2(740, 610)
	controls.size = Vector2(500, 32)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.modulate = Color(0.64, 0.67, 0.82)
	hud.add_child(controls)

func _show_title() -> void:
	var title := Label.new()
	title.text = "Level 2\n回声台阶"
	title.position = Vector2(0, 260)
	title.size = Vector2(1280, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(0.94, 0.92, 1.0, 0.0)
	add_child(title)
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.24)
	tween.tween_interval(1.35)
	tween.tween_property(title, "modulate:a", 0.0, 0.42)
	tween.finished.connect(func(): title.queue_free())

func _try_collect_petal() -> void:
	var petal: Area2D = _nearest_petal(84.0)
	if petal == null:
		error_sfx.play()
		_say("她伸出手，却只摸到一点安静的空气。")
		return
	petals.erase(petal)
	petal.monitoring = false
	petals_collected += 1
	pickup_sfx.play()
	_say("回声花瓣 %d/%d：她把孤独折得更轻了一点。" % [petals_collected, PETAL_COUNT])
	var tween := create_tween()
	tween.tween_property(petal, "scale", Vector2(1.4, 1.4), 0.14)
	tween.parallel().tween_property(petal, "modulate:a", 0.0, 0.14)
	await tween.finished
	petal.queue_free()
	if petals_collected >= PETAL_COUNT:
		_open_door()

func _nearest_petal(max_distance: float) -> Area2D:
	var nearest: Area2D = null
	var nearest_distance := max_distance
	for i in range(petals.size()):
		var petal: Area2D = petals[i]
		if not is_instance_valid(petal):
			continue
		var distance := player.global_position.distance_to(petal.global_position)
		if distance < nearest_distance:
			nearest = petal
			nearest_distance = distance
	return nearest

func _animate_petals() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(petals.size()):
		var petal: Area2D = petals[i]
		if not is_instance_valid(petal):
			continue
		var pulse := 1.0 + sin(t * 3.2 + i) * 0.052
		petal.scale = Vector2(pulse, pulse)
		var visual: Node2D = petal.get_node_or_null("EchoPetalVisual") as Node2D
		if visual != null:
			visual.position.y = sin(t * 2.0 + i * 1.4) * 4.0
			visual.rotation = sin(t * 1.35 + i * 0.9) * 0.10

func _open_door() -> void:
	if door_open:
		return
	door_open = true
	door_sfx.play()
	_say("三枚回声连成一条很细的路。门没有催她，只是亮着。")
	var tween := create_tween()
	tween.tween_property(door_visual, "modulate:a", 0.24, 0.65)
	tween.parallel().tween_property(door_glow, "modulate:a", 0.58, 0.65)

func _finish_level() -> void:
	if level_complete:
		return
	level_complete = true
	player.set_movement_locked(true)
	complete_sfx.play()
	_say("她站在高处，看见盒子的边缘也会呼吸。第二关完成。")
	await get_tree().create_timer(0.80).timeout
	level_completed.emit()

func _respawn_player() -> void:
	error_sfx.play()
	player.global_position = PLAYER_SPAWN
	player.velocity = Vector2.ZERO
	_say("她从空白里醒来，重新站回第一块石阶前。")

func _update_guidance() -> void:
	if objective_label == null:
		return
	if level_complete:
		objective_label.text = "第二关完成：她听见了自己的脚步。"
	elif door_open:
		objective_label.text = "目标：跳到右侧门前。"
	else:
		objective_label.text = "目标：跳上台阶，拾起三枚回声花瓣。"
	progress_label.text = "回声花瓣 %d/%d" % [petals_collected, PETAL_COUNT]

func _update_prompt() -> void:
	if prompt_label == null:
		return
	if level_complete:
		prompt_label.text = "第二关完成"
	elif active_petal != null:
		prompt_label.text = "按 E 拾起回声花瓣"
	elif door_open:
		prompt_label.text = "门亮了。跳向右侧的光。"
	else:
		prompt_label.text = "平台很窄。轻跳，不急。"

func _say(text: String) -> void:
	if status_label:
		status_label.text = text
