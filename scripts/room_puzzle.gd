extends Node2D

signal chapter_completed

const LiliesPlayerSceneScript := preload("res://scripts/player.gd")
const BlockInventoryScript := preload("res://scripts/block_inventory.gd")
const FriendBuilderScript := preload("res://scripts/friend_builder.gd")
const FriendActorScript := preload("res://scripts/friend_actor.gd")

const BG_TEXTURE := preload("res://assets/environment/gothicvania/backgrounds.png")
const TILE_TEXTURE := preload("res://assets/environment/gothicvania/tileset.png")
const COLUMN_TEXTURE := preload("res://assets/environment/gothicvania/column.png")
const FLOWERS_TEXTURE := preload("res://assets/environment/flowers/plants.png")
const BGM_STREAM := preload("res://assets/audio/heavenly_loop.ogg")
const AMBIENCE_STREAM := preload("res://assets/audio/forest_ambience.mp3")
const SFX_PICKUP := preload("res://assets/audio/sfx/pickup_chime.wav")
const SFX_DRAWER := preload("res://assets/audio/sfx/drawer_tick.wav")
const SFX_BLOCK := preload("res://assets/audio/sfx/block_place.wav")
const SFX_ERROR := preload("res://assets/audio/sfx/soft_error.wav")
const SFX_FRIEND := preload("res://assets/audio/sfx/friend_wake.wav")
const SFX_DOOR := preload("res://assets/audio/sfx/door_open.wav")
const SFX_CHAPTER := preload("res://assets/audio/sfx/chapter_complete.wav")

const FLOOR_Y := 586.0
const PLAYER_SPAWN := Vector2(150.0, 551.0)
const BOX_START := Vector2(665.0, 548.0)
const BOX_END := Vector2(1038.0, 548.0)
const CHAPTER_LEVEL_COUNT := 3

var inventory: BlockInventory
var level_root: Node2D
var player: LiliesPlayer
var builder: FriendBuilder
var friend: FriendActor
var status_label: Label
var objective_label: Label
var prompt_label: Label
var progress_label: Label
var fade_rect: ColorRect
var chapter_banner: Label
var banner_tween: Tween
var pickup_sfx: AudioStreamPlayer
var drawer_sfx: AudioStreamPlayer
var block_sfx: AudioStreamPlayer
var error_sfx: AudioStreamPlayer
var friend_sfx: AudioStreamPlayer
var door_sfx: AudioStreamPlayer
var chapter_sfx: AudioStreamPlayer
var door: Node2D
var door_visual: ColorRect
var door_glow: ColorRect
var door_area: Area2D
var box_block: Node2D
var button: Node2D
var button_lit: ColorRect
var pickups: Array[Area2D] = []
var active_pickup: Area2D = null
var room_complete := false
var door_open := false
var chapter_complete := false
var transition_in_progress := false
var chapter_level_index := 0
var initial_level_index := 0
var initial_blocks: Array[String] = []

func configure_stage(level_index: int, blocks: Array[String]) -> void:
	initial_level_index = clampi(level_index, 0, CHAPTER_LEVEL_COUNT - 1)
	initial_blocks = blocks.duplicate()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chapter_level_index = initial_level_index
	_build_world()
	_say(_level_intro())
	_update_guidance()
	_show_room_banner()

func _process(_delta: float) -> void:
	_animate_pickups()
	active_pickup = _nearest_pickup(86.0)
	_update_context_prompt()
	_update_guidance()
	if player != null and player.can_finish and not room_complete and not chapter_complete:
		if player.global_position.distance_to(door_area.global_position) < 92.0:
			_finish_room()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_chapter"):
		get_viewport().set_input_as_handled()
		await _restart_chapter()
		return
	if room_complete or chapter_complete:
		return
	if event.is_action_pressed("deploy_friend") and (builder == null or not builder.visible):
		_play_feedback("error")
		_say("莉莉丝摸了摸衣角。朋友需要先在抽屉里被接好。")
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	inventory = BlockInventoryScript.new()
	inventory.changed.connect(_on_inventory_changed)
	add_child(inventory)
	for i in range(initial_blocks.size()):
		var block_id: String = initial_blocks[i]
		inventory.add_block(block_id)

	_add_background()
	level_root = Node2D.new()
	level_root.name = "ChapterRoom"
	add_child(level_root)
	_add_puzzle_props()
	_add_player()
	_add_pickups()
	_add_friend()
	_add_audio()
	_add_ui()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.026, 0.040)
	bg.size = Vector2(1280, 720)
	bg.z_index = -100
	add_child(bg)

	var chapel := Sprite2D.new()
	chapel.name = "ChapelBackdrop"
	chapel.texture = BG_TEXTURE
	chapel.centered = false
	chapel.position = Vector2(-8, 98)
	chapel.scale = Vector2(2.12, 2.12)
	chapel.modulate = Color(0.62, 0.58, 0.78, 0.72)
	chapel.z_index = -90
	add_child(chapel)

	_add_column(Vector2(96, 236), 2.05, 0.58)
	_add_column(Vector2(358, 230), 1.86, 0.44)
	_add_column(Vector2(948, 230), 1.96, 0.50)

	var far_floor := ColorRect.new()
	far_floor.color = Color(0.070, 0.064, 0.095)
	far_floor.position = Vector2(0, FLOOR_Y - 38)
	far_floor.size = Vector2(1280, 172)
	far_floor.z_index = -70
	add_child(far_floor)

	var high_window := ColorRect.new()
	high_window.color = Color(0.62, 0.66, 0.92, 0.12)
	high_window.position = Vector2(1010, 88)
	high_window.size = Vector2(78, 116)
	high_window.z_index = -74
	add_child(high_window)

	for i in range(5):
		var mist_band := ColorRect.new()
		mist_band.color = Color(0.62, 0.70, 1.0, 0.040 + i * 0.006)
		mist_band.position = Vector2(74 + i * 248, 256 + i * 34)
		mist_band.size = Vector2(190, 14)
		mist_band.z_index = -66
		add_child(mist_band)

	for i in range(8):
		var tile := Sprite2D.new()
		tile.texture = TILE_TEXTURE
		tile.region_enabled = true
		tile.region_rect = Rect2(0, 160, 96, 32)
		tile.centered = false
		tile.position = Vector2(i * 192 - 24, FLOOR_Y - 54)
		tile.scale = Vector2(2.0, 2.0)
		tile.modulate = Color(0.78, 0.72, 0.94, 0.58)
		tile.z_index = -62
		add_child(tile)

	var floor_line := ColorRect.new()
	floor_line.color = Color(0.48, 0.42, 0.66, 0.55)
	floor_line.position = Vector2(0, FLOOR_Y - 4)
	floor_line.size = Vector2(1280, 4)
	floor_line.z_index = -50
	add_child(floor_line)

	_add_flower_patch(Vector2(212, FLOOR_Y - 50), 0, 2.6, Color(0.74, 0.78, 0.92, 0.70))
	_add_flower_patch(Vector2(532, FLOOR_Y - 48), 84, 2.4, Color(0.82, 0.74, 0.95, 0.62))
	_add_flower_patch(Vector2(812, FLOOR_Y - 46), 192, 2.5, Color(0.66, 0.84, 0.92, 0.68))

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector2(640, FLOOR_Y + 24)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(1500, 48)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	_add_wall_body("LeftWall", Vector2(-24, 360), Vector2(48, 720))
	_add_wall_body("RightWall", Vector2(1304, 360), Vector2(48, 720))

func _add_column(pos: Vector2, scale_value: float, alpha: float) -> void:
	var column := Sprite2D.new()
	column.texture = COLUMN_TEXTURE
	column.centered = false
	column.position = pos
	column.scale = Vector2(scale_value, scale_value)
	column.modulate = Color(0.52, 0.47, 0.66, alpha)
	column.z_index = -80
	add_child(column)

func _add_wall_body(node_name: String, pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = node_name
	wall.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)

func _add_flower_patch(pos: Vector2, region_x: int, scale_value: float, tint: Color) -> void:
	var flowers := Sprite2D.new()
	flowers.texture = FLOWERS_TEXTURE
	flowers.region_enabled = true
	flowers.region_rect = Rect2(region_x, 0, 72, 24)
	flowers.centered = false
	flowers.position = pos
	flowers.scale = Vector2(scale_value, scale_value)
	flowers.modulate = tint
	flowers.z_index = -40
	add_child(flowers)

func _level_box_start() -> Vector2:
	if chapter_level_index == 1:
		return Vector2(548, 548)
	if chapter_level_index == 2:
		return Vector2(432, 548)
	return BOX_START

func _level_box_end() -> Vector2:
	if chapter_level_index == 1:
		return Vector2(984, 548)
	if chapter_level_index == 2:
		return Vector2(1048, 548)
	return BOX_END

func _level_button_position() -> Vector2:
	if chapter_level_index == 1:
		return Vector2(984, FLOOR_Y - 17)
	if chapter_level_index == 2:
		return Vector2(1048, FLOOR_Y - 17)
	return Vector2(1038, FLOOR_Y - 17)

func _level_door_position() -> Vector2:
	if chapter_level_index == 1:
		return Vector2(1148, FLOOR_Y - 88)
	if chapter_level_index == 2:
		return Vector2(1160, FLOOR_Y - 88)
	return Vector2(1152, FLOOR_Y - 88)

func _level_required_sequence() -> Array[String]:
	var required: Array[String] = []
	if chapter_level_index == 1:
		required.append("See")
		required.append("Remember")
		required.append("Push")
	elif chapter_level_index == 2:
		required.append("Remember")
		required.append("See")
		required.append("Push")
	else:
		required.append("See")
		required.append("Push")
	return required

func _level_required_text() -> String:
	return " -> ".join(_level_required_sequence())

func _level_name() -> String:
	if chapter_level_index == 1:
		return "P-2 记忆的重量"
	if chapter_level_index == 2:
		return "P-3 回声门"
	return "P-1 先学会看见"

func _level_intro() -> String:
	if chapter_level_index == 1:
		return "第二间房更安静。这里的按钮不会只记住重量，还想记住为什么。"
	if chapter_level_index == 2:
		return "最后一扇门像回声一样等着她：先抱住记忆，再看见，再伸手。"
	return "莉莉丝醒在一座很安静的小礼拜堂里。她还不敢碰世界，只敢先看。"

func _level_note() -> String:
	if chapter_level_index == 1:
		return "新积木 Remember 很轻。把它放在 See 和 Push 中间，让朋友记住要推向哪里。"
	if chapter_level_index == 2:
		return "有些门要先被记起，才肯被看见。顺序试试：Remember -> See -> Push。"
	return "她不能推，也不能战斗。先让她学会看见。"

func _level_success_text() -> String:
	if chapter_level_index == 1:
		return "按钮记住了方块，也记住了朋友的顺序。第二扇门慢慢亮起来。"
	if chapter_level_index == 2:
		return "回声门承认了她的小小朋友。盒子这一章，终于有了出口。"
	return "按钮记住了重量。门打开了，光没有催她，只是在等。"

func _add_puzzle_props() -> void:
	button = Node2D.new()
	button.name = "Button"
	button.position = _level_button_position()
	level_root.add_child(button)

	var button_base := ColorRect.new()
	button_base.color = Color(0.13, 0.09, 0.16)
	button_base.position = Vector2(-50, -10)
	button_base.size = Vector2(100, 20)
	button.add_child(button_base)

	button_lit = ColorRect.new()
	button_lit.color = Color(0.46, 0.18, 0.40, 0.46)
	button_lit.position = Vector2(-40, -7)
	button_lit.size = Vector2(80, 14)
	button.add_child(button_lit)

	box_block = Node2D.new()
	box_block.name = "MemoryBox"
	box_block.position = _level_box_start()
	level_root.add_child(box_block)
	_add_memory_box_visual(box_block)

	door = Node2D.new()
	door.name = "Door"
	door.position = _level_door_position()
	level_root.add_child(door)

	door_glow = ColorRect.new()
	door_glow.color = Color(0.74, 0.62, 1.0, 1.0)
	door_glow.modulate.a = 0.0
	door_glow.position = Vector2(-42, -125)
	door_glow.size = Vector2(84, 170)
	door.add_child(door_glow)

	door_visual = ColorRect.new()
	door_visual.color = Color(0.075, 0.060, 0.095)
	door_visual.position = Vector2(-27, -116)
	door_visual.size = Vector2(54, 156)
	door.add_child(door_visual)

	var door_column := Sprite2D.new()
	door_column.texture = COLUMN_TEXTURE
	door_column.centered = false
	door_column.position = Vector2(-58, -132)
	door_column.scale = Vector2(1.62, 1.62)
	door_column.modulate = Color(0.50, 0.44, 0.66, 0.80)
	door.add_child(door_column)

	door_area = Area2D.new()
	door_area.name = "ExitArea"
	door_area.add_to_group("exit")
	door_area.position = _level_door_position() + Vector2(0, 10)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(86, 178)
	shape.shape = rect
	door_area.add_child(shape)
	level_root.add_child(door_area)

	_add_paper_note(Vector2(178, FLOOR_Y - 152), _level_note())

func _add_memory_box_visual(parent: Node2D) -> void:
	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.25)
	shadow.position = Vector2(-37, 4)
	shadow.size = Vector2(76, 10)
	parent.add_child(shadow)

	var body := ColorRect.new()
	body.color = Color(0.30, 0.24, 0.42)
	body.position = Vector2(-34, -52)
	body.size = Vector2(68, 54)
	parent.add_child(body)

	var top := ColorRect.new()
	top.color = Color(0.58, 0.48, 0.78)
	top.position = Vector2(-30, -48)
	top.size = Vector2(60, 9)
	parent.add_child(top)

	var label := Label.new()
	label.text = "?"
	label.position = Vector2(-7, -38)
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.88, 0.84, 1.0)
	parent.add_child(label)

func _add_paper_note(pos: Vector2, text: String) -> void:
	var note := PanelContainer.new()
	note.position = pos
	note.custom_minimum_size = Vector2(330, 46)
	note.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.105, 0.14, 0.82), Color(0.46, 0.38, 0.60, 0.50), 6))
	level_root.add_child(note)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	note.add_child(margin)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.79, 0.76, 0.86)
	margin.add_child(label)

func _add_player() -> void:
	player = LiliesPlayerSceneScript.new()
	player.position = PLAYER_SPAWN

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _make_lilith_frames()
	sprite.animation = "idle"
	sprite.scale = Vector2(3.0, 3.0)
	sprite.position = Vector2(0, -4)
	sprite.modulate = Color(1.15, 1.10, 1.23)
	player.add_child(sprite)
	sprite.play("idle")

	var veil := Polygon2D.new()
	veil.name = "WhiteVeil"
	veil.polygon = PackedVector2Array([
		Vector2(-23, -48),
		Vector2(0, -64),
		Vector2(23, -48),
		Vector2(18, -20),
		Vector2(0, -8),
		Vector2(-18, -20),
	])
	veil.color = Color(0.95, 0.93, 1.0, 0.54)
	veil.z_index = 3
	player.add_child(veil)

	var soft_glow := ColorRect.new()
	soft_glow.color = Color(0.78, 0.72, 1.0, 0.12)
	soft_glow.position = Vector2(-28, -58)
	soft_glow.size = Vector2(56, 68)
	soft_glow.z_index = -1
	player.add_child(soft_glow)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 70)
	collision.shape = shape
	player.add_child(collision)

	add_child(player)

	var breath := create_tween().set_loops()
	breath.tween_property(sprite, "position:y", -7.0, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(sprite, "position:y", -4.0, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	player.interacted.connect(_try_pickup)
	player.reached_exit.connect(_finish_room)

func _make_lilith_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 2.0)
	var idle_paths: Array[String] = [
		"res://assets/characters/lilith/Margery_Idle_Right_0.png",
		"res://assets/characters/lilith/Margery_Idle_Right_1.png",
	]
	for i in range(idle_paths.size()):
		var path: String = idle_paths[i]
		frames.add_frame("idle", load(path) as Texture2D)

	frames.add_animation("run")
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 8.0)
	var run_paths: Array[String] = [
		"res://assets/characters/lilith/Margery_Run_Right_0.png",
		"res://assets/characters/lilith/Margery_Run_Right_1.png",
		"res://assets/characters/lilith/Margery_Run_Right_2.png",
		"res://assets/characters/lilith/Margery_Run_Right_3.png",
		"res://assets/characters/lilith/Margery_Run_Right_4.png",
		"res://assets/characters/lilith/Margery_Run_Right_5.png",
	]
	for i in range(run_paths.size()):
		var path: String = run_paths[i]
		frames.add_frame("run", load(path) as Texture2D)

	frames.add_animation("jump")
	frames.set_animation_loop("jump", true)
	frames.set_animation_speed("jump", 1.0)
	frames.add_frame("jump", load("res://assets/characters/lilith/Margery_Jump_Right_0.png") as Texture2D)
	return frames

func _add_pickups() -> void:
	if chapter_level_index == 0:
		_create_missing_pickup("See", Vector2(330, FLOOR_Y - 62), Color(0.56, 0.74, 1.0))
		_create_missing_pickup("Push", Vector2(562, FLOOR_Y - 62), Color(1.0, 0.58, 0.73))
	elif chapter_level_index == 1:
		_create_missing_pickup("Remember", Vector2(520, FLOOR_Y - 62), Color(0.78, 0.66, 1.0))
	else:
		_create_missing_pickup("See", Vector2(318, FLOOR_Y - 62), Color(0.56, 0.74, 1.0))
		_create_missing_pickup("Remember", Vector2(520, FLOOR_Y - 62), Color(0.78, 0.66, 1.0))
		_create_missing_pickup("Push", Vector2(722, FLOOR_Y - 62), Color(1.0, 0.58, 0.73))

func _create_missing_pickup(block_id: String, pos: Vector2, color: Color) -> void:
	if inventory.has_block(block_id):
		return
	_create_pickup(block_id, pos, color)

func _add_friend() -> void:
	friend = FriendActorScript.new()
	friend.name = "Friend"
	friend.visible = false
	add_child(friend)

	_add_friend_visual(friend)
	var pulse := create_tween().set_loops()
	pulse.tween_property(friend, "scale", Vector2(1.06, 1.06), 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(friend, "scale", Vector2.ONE, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	friend.step.connect(_say)
	friend.finished.connect(_on_friend_finished)

func _add_friend_visual(parent: Node2D) -> void:
	var core := ColorRect.new()
	core.color = Color(0.66, 0.88, 1.0, 0.86)
	core.position = Vector2(-13, -30)
	core.size = Vector2(26, 26)
	parent.add_child(core)

	var left := ColorRect.new()
	left.color = Color(0.92, 0.78, 1.0, 0.76)
	left.position = Vector2(-34, -22)
	left.size = Vector2(14, 14)
	parent.add_child(left)

	var right := ColorRect.new()
	right.color = Color(1.0, 0.58, 0.78, 0.76)
	right.position = Vector2(20, -22)
	right.size = Vector2(14, 14)
	parent.add_child(right)

	var halo := ColorRect.new()
	halo.color = Color(0.60, 0.82, 1.0, 0.16)
	halo.position = Vector2(-42, -42)
	halo.size = Vector2(84, 48)
	halo.z_index = -1
	parent.add_child(halo)

func _add_audio() -> void:
	var bgm := AudioStreamPlayer.new()
	bgm.name = "BGM"
	bgm.stream = BGM_STREAM
	bgm.volume_db = -12.0
	bgm.finished.connect(_loop_audio.bind(bgm))
	add_child(bgm)
	bgm.play()

	var ambience := AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.stream = AMBIENCE_STREAM
	ambience.volume_db = -24.0
	ambience.finished.connect(_loop_audio.bind(ambience))
	add_child(ambience)
	ambience.play()

	pickup_sfx = _make_sfx_player("PickupSfx", SFX_PICKUP, -15.0)
	drawer_sfx = _make_sfx_player("DrawerSfx", SFX_DRAWER, -20.0)
	block_sfx = _make_sfx_player("BlockSfx", SFX_BLOCK, -17.0)
	error_sfx = _make_sfx_player("ErrorSfx", SFX_ERROR, -18.0)
	friend_sfx = _make_sfx_player("FriendSfx", SFX_FRIEND, -16.0)
	door_sfx = _make_sfx_player("DoorSfx", SFX_DOOR, -15.0)
	chapter_sfx = _make_sfx_player("ChapterSfx", SFX_CHAPTER, -14.0)

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
	objective_label.size = Vector2(520, 44)
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.modulate = Color(0.92, 0.88, 1.0)
	hud.add_child(objective_label)

	var controls := Label.new()
	controls.text = "A/D移动  W/Space轻跳  E拾取  Tab抽屉  Enter释放  R重开"
	controls.position = Vector2(744, 32)
	controls.size = Vector2(500, 32)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.modulate = Color(0.70, 0.68, 0.82)
	hud.add_child(controls)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(34, 84)
	status_panel.custom_minimum_size = Vector2(640, 86)
	status_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.045, 0.042, 0.060, 0.84), Color(0.38, 0.30, 0.52, 0.72), 8))
	hud.add_child(status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	status_panel.add_child(margin)

	status_label = Label.new()
	status_label.size = Vector2(610, 68)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.modulate = Color(0.93, 0.89, 1.0)
	margin.add_child(status_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 662)
	prompt_label.size = Vector2(1280, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 19)
	prompt_label.modulate = Color(0.86, 0.90, 1.0)
	hud.add_child(prompt_label)

	progress_label = Label.new()
	progress_label.position = Vector2(760, 610)
	progress_label.size = Vector2(470, 38)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.modulate = Color(0.72, 0.76, 0.92)
	hud.add_child(progress_label)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.020, 0.018, 0.030, 1.0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.modulate.a = 0.0
	fade_rect.z_index = 30
	hud.add_child(fade_rect)

	chapter_banner = Label.new()
	chapter_banner.position = Vector2(0, 274)
	chapter_banner.size = Vector2(1280, 120)
	chapter_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_banner.add_theme_font_size_override("font_size", 30)
	chapter_banner.modulate = Color(0.94, 0.90, 1.0, 0.0)
	chapter_banner.z_index = 31
	hud.add_child(chapter_banner)

	builder = FriendBuilderScript.new()
	builder.setup(inventory)
	builder.set_goal_hint(_level_name(), _level_required_text())
	builder.deploy_requested.connect(_deploy_friend)
	builder.status_requested.connect(_say)
	builder.sequence_changed.connect(_on_builder_sequence_changed)
	builder.feedback_requested.connect(_play_feedback)
	add_child(builder)

func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _create_pickup(block_id: String, pos: Vector2, color: Color) -> void:
	var area := Area2D.new()
	area.name = "%sPickup" % block_id
	area.position = pos
	area.set_meta("block_id", block_id)
	level_root.add_child(area)

	var glow := ColorRect.new()
	glow.color = Color(color.r, color.g, color.b, 0.20)
	glow.position = Vector2(-34, -58)
	glow.size = Vector2(68, 68)
	area.add_child(glow)

	var visual := Sprite2D.new()
	visual.texture = _block_texture(block_id)
	visual.scale = Vector2(0.78, 0.78)
	visual.modulate = Color(1.12, 1.10, 1.18)
	area.add_child(visual)

	var label := Label.new()
	label.text = block_id
	label.position = Vector2(-40, 18)
	label.size = Vector2(80, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.95, 0.93, 1.0)
	area.add_child(label)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(78, 90)
	shape.shape = rect
	area.add_child(shape)
	pickups.append(area)

func _block_texture(block_id: String) -> Texture2D:
	if block_id == "See":
		return load("res://assets/placeholder/block_see.svg") as Texture2D
	if block_id == "Remember":
		return load("res://assets/placeholder/block_remember.svg") as Texture2D
	return load("res://assets/placeholder/block_push.svg") as Texture2D

func _try_pickup() -> void:
	var nearest: Area2D = _nearest_pickup(86.0)
	if nearest == null:
		_play_feedback("error")
		_say("这里没有可以捡起的积木。莉莉丝先把手收回来了。")
		return
	var block_id: String = String(nearest.get_meta("block_id"))
	inventory.add_block(block_id)
	pickups.erase(nearest)
	nearest.monitoring = false
	_play_feedback("pickup")
	_say(_pickup_text(block_id))
	_spawn_flash(nearest.global_position, Color(0.86, 0.76, 1.0, 0.30))
	var tween := create_tween()
	tween.tween_property(nearest, "scale", Vector2(1.35, 1.35), 0.14)
	tween.parallel().tween_property(nearest, "modulate:a", 0.0, 0.14)
	await tween.finished
	nearest.queue_free()

func _pickup_text(block_id: String) -> String:
	if block_id == "See":
		return "See 落进掌心。莉莉丝终于能让朋友先看清世界。"
	if block_id == "Push":
		return "Push 有一点点力气。它还需要先被 See 引导。"
	return "Remember 很轻，像一枚不肯丢失的小事实。"

func _nearest_pickup(max_distance: float) -> Area2D:
	if player == null:
		return null
	var nearest: Area2D = null
	var nearest_distance := max_distance
	for i in range(pickups.size()):
		var pickup: Area2D = pickups[i]
		if not is_instance_valid(pickup):
			continue
		var distance := player.global_position.distance_to(pickup.global_position)
		if distance < nearest_distance:
			nearest = pickup
			nearest_distance = distance
	return nearest

func _animate_pickups() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(pickups.size()):
		var pickup: Area2D = pickups[i]
		if not is_instance_valid(pickup):
			continue
		var pulse := 1.0 + sin(t * 3.0 + i * 0.8) * 0.045
		pickup.scale = Vector2(pulse, pulse)

func _deploy_friend(sequence: Array[String]) -> void:
	if friend.active:
		_play_feedback("error")
		_say("上一个朋友还在努力执行，先等等它。")
		return
	var required: Array[String] = _level_required_sequence()
	if not _sequence_has_required_blocks(sequence, required):
		_play_feedback("error")
		_say("这个朋友还不懂这扇门。它想听见：%s。" % _level_required_text())
		return
	if not _sequence_matches_required(sequence, required):
		_play_feedback("error")
		_say("顺序还不对。这里的门想听见：%s。" % _level_required_text())
		return
	builder.visible = false
	_play_feedback("friend")
	_say("朋友从积木之间醒来，像一小段被允许的勇气。")
	_spawn_flash(player.global_position + Vector2(58, -20), Color(0.58, 0.82, 1.0, 0.34))
	friend.begin(sequence, self, player.global_position + Vector2(66, -4))

func _sequence_has_required_blocks(sequence: Array[String], required: Array[String]) -> bool:
	for i in range(required.size()):
		var block_id: String = required[i]
		if not sequence.has(block_id):
			return false
	return true

func _sequence_matches_required(sequence: Array[String], required: Array[String]) -> bool:
	if sequence.size() != required.size():
		return false
	for i in range(required.size()):
		var expected: String = required[i]
		var actual: String = sequence[i]
		if actual != expected:
			return false
	return true

func friend_notice_box(_actor: Node2D) -> void:
	_spawn_flash(box_block.global_position + Vector2(0, -26), Color(0.66, 0.84, 1.0, 0.34))
	_spawn_flash(button.global_position, Color(1.0, 0.58, 0.78, 0.30))
	_play_feedback("block")
	await get_tree().create_timer(0.60).timeout

func friend_recall() -> String:
	if chapter_level_index == 2:
		return "上一扇门等她的光"
	if chapter_level_index == 1:
		return "方块要去按钮那里"
	return "a soft missing fact"

func friend_push_box(actor: Node2D) -> void:
	if door_open:
		return
	var approach := Vector2(box_block.global_position.x - 84, FLOOR_Y - 38)
	var box_end: Vector2 = _level_box_end()
	var actor_end := Vector2(box_end.x - 84, FLOOR_Y - 38)
	var tween := create_tween()
	tween.tween_property(actor, "global_position", approach, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(box_block, "global_position", box_end, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(actor, "global_position", actor_end, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_spawn_flash(button.global_position, Color(1.0, 0.48, 0.82, 0.40))
	_play_feedback("block")
	_open_door()

func _open_door() -> void:
	if door_open:
		return
	door_open = true
	button_lit.color = Color(1.0, 0.44, 0.78, 0.92)
	player.can_finish = true
	_play_feedback("door")
	var tween := create_tween()
	tween.tween_property(door_visual, "modulate:a", 0.24, 0.65)
	tween.parallel().tween_property(door_glow, "modulate:a", 0.54, 0.65)
	_say(_level_success_text())

func _on_friend_finished(success: bool) -> void:
	if success:
		builder.clear_sequence()
		if door_open:
			_say("朋友停在按钮旁，回头等莉莉丝走进门。")
		else:
			_say("朋友停下来，等待莉莉丝给它新的名字。")
	else:
		_play_feedback("error")
		_say("朋友散成几块安静的光。换一种顺序试试。")
		var tween := create_tween()
		tween.tween_property(friend, "modulate:a", 0.0, 0.22)
		await tween.finished
		friend.visible = false
		friend.modulate.a = 1.0

func _finish_room() -> void:
	if room_complete:
		return
	room_complete = true
	transition_in_progress = true
	player.set_movement_locked(true)
	if chapter_level_index >= CHAPTER_LEVEL_COUNT - 1:
		chapter_complete = true
		_play_feedback("chapter")
		_say("莉莉丝穿过最后的门。盒子没有消失，只是终于多了一条出去的边。")
	else:
		_play_feedback("drawer")
		_say("莉莉丝穿过门。下一间房在很远又很近的地方等着她。")
	if fade_rect != null:
		var fade_in := create_tween()
		fade_in.tween_property(fade_rect, "modulate:a", 0.52, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tween := create_tween()
	tween.tween_property(player, "global_position", _level_door_position() + Vector2(16, 53), 0.80).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(player, "modulate:a", 0.24, 0.80)
	await tween.finished
	if not chapter_complete:
		await _load_level(chapter_level_index + 1)
	else:
		_show_chapter_complete_banner()
		transition_in_progress = false
		chapter_completed.emit()

func _restart_chapter() -> void:
	if transition_in_progress:
		_play_feedback("error")
		_say("门的光还在合上。等它安静下来，再重开这一章。")
		return
	chapter_complete = false
	if inventory != null:
		inventory.clear()
	if friend != null:
		friend.cancel()
	_play_feedback("drawer")
	await _load_level(0)

func _load_level(next_level_index: int) -> void:
	chapter_level_index = next_level_index
	room_complete = false
	door_open = false
	transition_in_progress = false
	active_pickup = null
	pickups.clear()
	player.can_finish = false
	player.modulate.a = 1.0
	player.position = PLAYER_SPAWN
	player.set_movement_locked(false)
	friend.cancel()
	builder.visible = false
	builder.clear_sequence()
	builder.set_goal_hint(_level_name(), _level_required_text())
	var child_count: int = level_root.get_child_count()
	for i in range(child_count):
		var node: Node = level_root.get_child(i)
		node.queue_free()
	await get_tree().process_frame
	_add_puzzle_props()
	_add_pickups()
	_say(_level_intro())
	_spawn_flash(player.global_position + Vector2(0, -34), Color(0.70, 0.62, 1.0, 0.22))
	if fade_rect != null:
		fade_rect.modulate.a = 0.52
		var fade_out := create_tween()
		fade_out.tween_property(fade_rect, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_show_room_banner()
	_update_guidance()

func _show_room_banner() -> void:
	if chapter_banner == null:
		return
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	chapter_banner.text = "Prologue\n%s" % _level_name()
	chapter_banner.modulate.a = 0.0
	banner_tween = create_tween()
	banner_tween.tween_property(chapter_banner, "modulate:a", 1.0, 0.22)
	banner_tween.tween_interval(1.25)
	banner_tween.tween_property(chapter_banner, "modulate:a", 0.0, 0.36)

func _show_chapter_complete_banner() -> void:
	if chapter_banner == null:
		return
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	chapter_banner.text = "Prologue 完成\n盒子记住了莉莉丝"
	chapter_banner.modulate.a = 0.0
	banner_tween = create_tween()
	banner_tween.tween_property(chapter_banner, "modulate:a", 1.0, 0.36)

func _spawn_flash(pos: Vector2, color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.position = pos - Vector2(32, 32)
	flash.size = Vector2(64, 64)
	flash.z_index = 30
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.42)
	tween.finished.connect(func(): flash.queue_free())

func _loop_audio(audio_player: AudioStreamPlayer) -> void:
	if is_instance_valid(audio_player):
		audio_player.play()

func _play_feedback(kind: String) -> void:
	var target: AudioStreamPlayer = null
	if kind == "pickup":
		target = pickup_sfx
	elif kind == "drawer":
		target = drawer_sfx
	elif kind == "block":
		target = block_sfx
	elif kind == "error":
		target = error_sfx
	elif kind == "friend":
		target = friend_sfx
	elif kind == "door":
		target = door_sfx
	elif kind == "chapter":
		target = chapter_sfx
	if target != null:
		target.stop()
		target.play()

func _on_inventory_changed(_blocks: Array[String]) -> void:
	_update_guidance()

func _on_builder_sequence_changed(_sequence: Array[String]) -> void:
	_update_guidance()

func _update_guidance() -> void:
	if objective_label == null or inventory == null:
		return
	_update_progress_label()
	if chapter_complete:
		objective_label.text = "章节完成：盒子记住了莉莉丝。按 R 可以重开。"
	elif room_complete:
		objective_label.text = "目标：穿过门，去下一间房。"
	elif door_open:
		objective_label.text = "目标：走进右侧打开的门。"
	elif friend != null and friend.active:
		objective_label.text = "目标：看着朋友完成她不敢做的事。"
	elif _first_missing_required_block() != "":
		objective_label.text = "目标：按 E 捡起 %s。" % _first_missing_required_block()
	elif builder != null and builder.visible:
		if builder.sequence.is_empty():
			objective_label.text = "目标：接成 %s。" % _level_required_text()
		else:
			objective_label.text = "目标：确认顺序后按 Enter 释放朋友。"
	else:
		objective_label.text = "%s：按 Tab 打开抽屉。" % _level_name()

func _update_progress_label() -> void:
	if progress_label == null or inventory == null:
		return
	if chapter_complete:
		progress_label.text = "Prologue 完成   %s" % _inventory_text()
	else:
		progress_label.text = "门 %d/%d   %s" % [chapter_level_index + 1, CHAPTER_LEVEL_COUNT, _inventory_text()]

func _inventory_text() -> String:
	var blocks: Array[String] = inventory.all_blocks()
	if blocks.is_empty():
		return "积木 ..."
	return "积木 " + " / ".join(blocks)

func _update_context_prompt() -> void:
	if prompt_label == null:
		return
	if chapter_complete:
		prompt_label.text = "Prologue 完成   按 R 重开"
	elif room_complete:
		prompt_label.text = ""
	elif builder != null and builder.visible:
		prompt_label.text = "1/2/3 选择积木   Backspace 撤回   Enter 释放"
	elif active_pickup != null:
		prompt_label.text = "按 E 捡起 %s" % String(active_pickup.get_meta("block_id"))
	elif door_open:
		prompt_label.text = "门开了。向右走进光里。"
	elif _first_missing_required_block() == "":
		prompt_label.text = "按 Tab 打开抽屉：%s" % _level_required_text()
	else:
		prompt_label.text = "A/D 移动   W 或 Space 轻跳"

func _first_missing_required_block() -> String:
	var required: Array[String] = _level_required_sequence()
	for i in range(required.size()):
		var block_id: String = required[i]
		if not inventory.has_block(block_id):
			return block_id
	return ""

func _say(text: String) -> void:
	if status_label:
		status_label.text = text
