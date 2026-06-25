extends Node2D

signal chapter_completed

const LiliesPlayerSceneScript := preload("res://scripts/player.gd")
const BlockInventoryScript := preload("res://scripts/block_inventory.gd")
const FriendBuilderScript := preload("res://scripts/friend_builder.gd")
const FriendActorScript := preload("res://scripts/friend_actor.gd")
const BG_TEXTURE := preload("res://assets/environment/gothicvania/backgrounds.png")
const COLUMN_TEXTURE := preload("res://assets/environment/gothicvania/column.png")
const BGM_STREAM := preload("res://assets/audio/heavenly_loop.ogg")
const SFX_PICKUP := preload("res://assets/audio/sfx/pickup_chime.wav")
const SFX_DRAWER := preload("res://assets/audio/sfx/drawer_tick.wav")
const SFX_BLOCK := preload("res://assets/audio/sfx/block_place.wav")
const SFX_ERROR := preload("res://assets/audio/sfx/soft_error.wav")
const SFX_FRIEND := preload("res://assets/audio/sfx/friend_wake.wav")
const SFX_DOOR := preload("res://assets/audio/sfx/door_open.wav")
const SFX_CHAPTER := preload("res://assets/audio/sfx/chapter_complete.wav")

const FLOOR_Y := 586.0
const PLAYER_SPAWN := Vector2(132.0, 551.0)
const CHAPTER_TASK_COUNT := 4

var inventory: BlockInventory
var level_root: Node2D
var player: LiliesPlayer
var friend: FriendActor
var builder: FriendBuilder
var status_label: Label
var objective_label: Label
var prompt_label: Label
var progress_label: Label
var target_label: Label
var confidence_label: Label
var target_card_label: Label
var fade_rect: ColorRect
var chapter_banner: Label
var target_node: Node2D
var target_glow: ColorRect
var door: Node2D
var door_visual: ColorRect
var door_glow: ColorRect
var pickup_sfx: AudioStreamPlayer
var drawer_sfx: AudioStreamPlayer
var block_sfx: AudioStreamPlayer
var error_sfx: AudioStreamPlayer
var friend_sfx: AudioStreamPlayer
var door_sfx: AudioStreamPlayer
var chapter_sfx: AudioStreamPlayer
var targets: Array[EncounterTarget] = []
var pickups: Array[Area2D] = []
var active_pickup: Area2D = null
var task_index := 0
var task_resolved := false
var transition_in_progress := false
var chapter_complete := false
var last_result: WorkflowResult
var initial_task_index := 0
var initial_blocks: Array[String] = []
var intro_tip_shown := false

func configure_stage(next_task_index: int, blocks: Array[String]) -> void:
	initial_task_index = clampi(next_task_index, 0, CHAPTER_TASK_COUNT - 1)
	initial_blocks = blocks.duplicate()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_targets()
	_build_world()
	_load_task(initial_task_index)

func _process(_delta: float) -> void:
	_animate_pickups()
	_animate_target()
	active_pickup = _nearest_pickup(86.0)
	_update_prompt()
	_update_guidance()
	if task_resolved and not transition_in_progress and player.global_position.distance_to(door.global_position) < 96.0:
		await _finish_task()

func _unhandled_input(event: InputEvent) -> void:
	if chapter_complete or transition_in_progress:
		return
	if event.is_action_pressed("deploy_friend") and (builder == null or not builder.visible):
		_play_feedback("error")
		_say("朋友需要先在 workflow 抽屉里被接好。")
		get_viewport().set_input_as_handled()

func _build_targets() -> void:
	targets.clear()
	_add_target(
		"fearful_door",
		"1-1 会害怕的门",
		"door",
		"Push",
		["visual", "relation"],
		70,
		24,
		60,
		"门在轻轻发抖。它不是锁住了，只是不确定自己是不是门。",
		"朋友让门明白：它可以先打开一点点。",
		"看见它，再比较它和出口之间的关系。",
		Color(0.72, 0.74, 1.0),
		Vector2(842, FLOOR_Y - 88)
	)
	_add_target(
		"whisper_flower",
		"1-2 低声花",
		"flower",
		"Quiet",
		["visual", "audio"],
		75,
		32,
		62,
		"花里有很轻的噪声。它不伤人，只让门忘记怎么安静。",
		"低声花把噪声收回花心，留下一点温柔的空白。",
		"只看见不够。朋友还要听见它为什么低声。",
		Color(0.86, 0.66, 1.0),
		Vector2(820, FLOOR_Y - 70)
	)
	_add_target(
		"uncertain_step",
		"1-3 不确定的台阶",
		"step",
		"Push",
		["visual", "memory", "steady"],
		64,
		76,
		48,
		"台阶一会儿出现，一会儿退回雾里。朋友如果太急，会把风险带回来。",
		"朋友稳住自己，轻轻把台阶推成一条可以走的线。",
		"先记住、再看见、再 Hold。风险降下来以后才行动。",
		Color(0.62, 0.86, 1.0),
		Vector2(820, FLOOR_Y - 118)
	)
	_add_target(
		"question_shadow",
		"1-4 疑问的影子",
		"shadow",
		"Quiet",
		["audio", "memory", "relation"],
		82,
		54,
		58,
		"影子不是敌意。它只是把所有问题都问得太响。",
		"影子被听见、记住、比较，于是慢慢安静下来。",
		"它需要被听见，也需要被放进记忆里比较。",
		Color(0.50, 0.46, 0.74),
		Vector2(832, FLOOR_Y - 86)
	)

func _add_target(
	target_id: String,
	title: String,
	kind: String,
	required_action: String,
	required_evidence: Array[String],
	confidence_required: int,
	base_risk: int,
	risk_limit: int,
	intro_text: String,
	success_text: String,
	unresolved_text: String,
	color: Color,
	position: Vector2
) -> void:
	var target: EncounterTarget = EncounterTarget.new()
	target.configure(target_id, title, kind, required_action, required_evidence, confidence_required, base_risk, risk_limit, intro_text, success_text, unresolved_text, color, position)
	target.evidence_text = _evidence_text(required_evidence)
	target.action_text = _action_text(required_action)
	target.first_hint = unresolved_text
	target.failure_hint = unresolved_text
	targets.append(target)

func _evidence_text(evidence: Array[String]) -> String:
	var names: Array[String] = []
	for i in range(evidence.size()):
		var evidence_id: String = evidence[i]
		if evidence_id == "visual":
			names.append("视觉证据")
		elif evidence_id == "audio":
			names.append("声音证据")
		elif evidence_id == "memory":
			names.append("记忆证据")
		elif evidence_id == "relation":
			names.append("关系比较")
		elif evidence_id == "steady":
			names.append("稳定风险")
		else:
			names.append(evidence_id)
	return " + ".join(names)

func _action_text(action: String) -> String:
	if action == "Quiet":
		return "Quiet：把噪声收回来"
	return "Push：轻轻推动世界"

func _build_world() -> void:
	inventory = BlockInventoryScript.new()
	inventory.changed.connect(_on_inventory_changed)
	add_child(inventory)
	for i in range(initial_blocks.size()):
		var block_id: String = initial_blocks[i]
		inventory.add_block(block_id)

	_add_background()
	level_root = Node2D.new()
	level_root.name = "WorkflowTask"
	add_child(level_root)
	_add_player()
	_add_friend()
	_add_audio()
	_add_ui()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.020, 0.034)
	bg.size = Vector2(1280, 720)
	bg.z_index = -100
	add_child(bg)

	var chapel := Sprite2D.new()
	chapel.texture = BG_TEXTURE
	chapel.centered = false
	chapel.position = Vector2(-48, 74)
	chapel.scale = Vector2(2.24, 2.24)
	chapel.modulate = Color(0.46, 0.50, 0.72, 0.48)
	chapel.z_index = -92
	add_child(chapel)

	_add_column(Vector2(80, 226), 2.16, 0.36)
	_add_column(Vector2(430, 214), 1.72, 0.30)
	_add_column(Vector2(950, 198), 2.02, 0.40)

	for i in range(5):
		var veil := ColorRect.new()
		veil.color = Color(0.58, 0.72, 1.0, 0.045)
		veil.position = Vector2(64 + i * 250, 202 + i * 28)
		veil.size = Vector2(220, 16)
		veil.z_index = -82
		add_child(veil)

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector2(640, FLOOR_Y + 24)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1500, 48)
	shape.shape = rect
	floor_body.add_child(shape)
	add_child(floor_body)

	var floor_visual := ColorRect.new()
	floor_visual.color = Color(0.078, 0.068, 0.106)
	floor_visual.position = Vector2(0, FLOOR_Y - 18)
	floor_visual.size = Vector2(1280, 74)
	floor_visual.z_index = -70
	add_child(floor_visual)

func _add_column(pos: Vector2, scale_value: float, alpha: float) -> void:
	var column := Sprite2D.new()
	column.texture = COLUMN_TEXTURE
	column.centered = false
	column.position = pos
	column.scale = Vector2(scale_value, scale_value)
	column.modulate = Color(0.50, 0.50, 0.72, alpha)
	column.z_index = -86
	add_child(column)

func _add_player() -> void:
	player = LiliesPlayerSceneScript.new()
	player.position = PLAYER_SPAWN
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
	var player_shape := RectangleShape2D.new()
	player_shape.size = Vector2(32, 70)
	collision.shape = player_shape
	player.add_child(collision)
	add_child(player)
	player.interacted.connect(_try_pickup)

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

func _add_friend() -> void:
	friend = FriendActorScript.new()
	friend.name = "WorkflowFriend"
	friend.visible = false
	add_child(friend)
	_add_friend_visual(friend)
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
	bgm.stream = BGM_STREAM
	bgm.volume_db = -14.0
	bgm.finished.connect(func(): bgm.play())
	add_child(bgm)
	bgm.play()
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
	objective_label.position = Vector2(34, 26)
	objective_label.size = Vector2(760, 38)
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.modulate = Color(0.92, 0.90, 1.0)
	hud.add_child(objective_label)

	target_label = Label.new()
	target_label.position = Vector2(34, 66)
	target_label.size = Vector2(720, 32)
	target_label.modulate = Color(0.70, 0.74, 0.92)
	hud.add_child(target_label)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(34, 106)
	status_panel.custom_minimum_size = Vector2(690, 96)
	status_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.042, 0.044, 0.064, 0.86), Color(0.34, 0.38, 0.58, 0.70), 8))
	hud.add_child(status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	status_panel.add_child(margin)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.modulate = Color(0.90, 0.90, 1.0)
	margin.add_child(status_label)

	confidence_label = Label.new()
	confidence_label.position = Vector2(754, 34)
	confidence_label.size = Vector2(480, 32)
	confidence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	confidence_label.add_theme_font_size_override("font_size", 18)
	confidence_label.modulate = Color(0.80, 0.88, 1.0)
	hud.add_child(confidence_label)

	progress_label = Label.new()
	progress_label.position = Vector2(754, 70)
	progress_label.size = Vector2(480, 32)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.modulate = Color(0.66, 0.70, 0.86)
	hud.add_child(progress_label)

	var target_card := PanelContainer.new()
	target_card.position = Vector2(754, 112)
	target_card.custom_minimum_size = Vector2(480, 236)
	target_card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.040, 0.060, 0.88), Color(0.32, 0.40, 0.62, 0.78), 8))
	hud.add_child(target_card)

	var target_margin := MarginContainer.new()
	target_margin.add_theme_constant_override("margin_left", 12)
	target_margin.add_theme_constant_override("margin_right", 12)
	target_margin.add_theme_constant_override("margin_top", 10)
	target_margin.add_theme_constant_override("margin_bottom", 10)
	target_card.add_child(target_margin)

	target_card_label = Label.new()
	target_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_card_label.add_theme_font_size_override("font_size", 16)
	target_card_label.modulate = Color(0.86, 0.88, 1.0)
	target_margin.add_child(target_card_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 662)
	prompt_label.size = Vector2(1280, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 19)
	prompt_label.modulate = Color(0.86, 0.90, 1.0)
	hud.add_child(prompt_label)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.012, 0.014, 0.024, 1.0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.modulate.a = 0.0
	fade_rect.z_index = 30
	hud.add_child(fade_rect)

	chapter_banner = Label.new()
	chapter_banner.position = Vector2(0, 252)
	chapter_banner.size = Vector2(1280, 130)
	chapter_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_banner.add_theme_font_size_override("font_size", 30)
	chapter_banner.modulate = Color(0.94, 0.92, 1.0, 0.0)
	chapter_banner.z_index = 31
	hud.add_child(chapter_banner)

	builder = FriendBuilderScript.new()
	builder.setup(inventory)
	builder.deploy_requested.connect(_deploy_friend)
	builder.status_requested.connect(_say)
	builder.feedback_requested.connect(_play_feedback)
	add_child(builder)

func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _load_task(next_index: int) -> void:
	task_index = next_index
	task_resolved = false
	transition_in_progress = false
	active_pickup = null
	pickups.clear()
	last_result = null
	player.can_finish = false
	player.modulate.a = 1.0
	player.global_position = PLAYER_SPAWN
	player.set_movement_locked(false)
	friend.cancel()
	builder.visible = false
	builder.clear_sequence()
	builder.clear_workflow_feedback()

	var child_count: int = level_root.get_child_count()
	for i in range(child_count - 1, -1, -1):
		var node: Node = level_root.get_child(i)
		level_root.remove_child(node)
		node.queue_free()

	var target: EncounterTarget = _current_target()
	target.resolved = false
	_add_task_target(target)
	_add_pickups_for_task()
	_add_task_door()
	_add_guidance_note(target)
	builder.set_goal_hint(target.title, "运行 workflow，读 trace，再调整节点")
	_say(target.intro_text)
	_show_room_banner(target.title)
	if not intro_tip_shown:
		intro_tip_shown = true
		_show_chapter_tip()
	_update_guidance()

func _current_target() -> EncounterTarget:
	return targets[task_index]

func _add_guidance_note(target: EncounterTarget) -> void:
	var note := PanelContainer.new()
	note.position = Vector2(146, FLOOR_Y - 156)
	note.custom_minimum_size = Vector2(360, 58)
	note.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.105, 0.145, 0.82), Color(0.40, 0.46, 0.68, 0.58), 6))
	level_root.add_child(note)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	note.add_child(margin)

	var label := Label.new()
	label.text = target.first_hint
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.80, 0.82, 0.94)
	margin.add_child(label)

func _show_chapter_tip() -> void:
	var tip := Label.new()
	tip.text = "运行不是答案，trace 才是答案的影子。\n失败后读 trace，再改 workflow。"
	tip.position = Vector2(0, 292)
	tip.size = Vector2(1280, 82)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 24)
	tip.modulate = Color(0.92, 0.92, 1.0, 0.0)
	tip.z_index = 32
	add_child(tip)
	var tween := create_tween()
	tween.tween_property(tip, "modulate:a", 1.0, 0.28)
	tween.tween_interval(1.80)
	tween.tween_property(tip, "modulate:a", 0.0, 0.40)
	tween.finished.connect(func(): tip.queue_free())

func _add_task_target(target: EncounterTarget) -> void:
	target_node = Node2D.new()
	target_node.name = "EncounterTarget"
	target_node.position = target.position
	level_root.add_child(target_node)

	target_glow = ColorRect.new()
	target_glow.color = Color(target.color.r, target.color.g, target.color.b, 0.20)
	target_glow.position = Vector2(-58, -72)
	target_glow.size = Vector2(116, 116)
	target_glow.z_index = -2
	target_node.add_child(target_glow)

	if target.kind == "flower":
		_add_flower_target(target_node, target.color)
	elif target.kind == "step":
		_add_step_target(target_node, target.color)
	elif target.kind == "shadow":
		_add_shadow_target(target_node, target.color)
	else:
		_add_door_target(target_node, target.color)

	var label := Label.new()
	label.text = target.kind
	label.position = Vector2(-64, 34)
	label.size = Vector2(128, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.78, 0.80, 0.94)
	target_node.add_child(label)

func _add_door_target(parent: Node2D, color: Color) -> void:
	var body := ColorRect.new()
	body.color = Color(color.r * 0.32, color.g * 0.32, color.b * 0.38, 0.92)
	body.position = Vector2(-28, -92)
	body.size = Vector2(56, 124)
	parent.add_child(body)
	var seam := ColorRect.new()
	seam.color = Color(1.0, 1.0, 1.0, 0.22)
	seam.position = Vector2(-2, -82)
	seam.size = Vector2(4, 104)
	parent.add_child(seam)

func _add_flower_target(parent: Node2D, color: Color) -> void:
	for i in range(5):
		var petal := Polygon2D.new()
		petal.polygon = PackedVector2Array([
			Vector2(0, -48),
			Vector2(18, -18),
			Vector2(0, -4),
			Vector2(-18, -18),
		])
		petal.color = Color(color.r, color.g, color.b, 0.55)
		petal.rotation = i * TAU / 5.0
		parent.add_child(petal)
	var core := ColorRect.new()
	core.color = Color(1.0, 0.94, 0.82, 0.92)
	core.position = Vector2(-12, -12)
	core.size = Vector2(24, 24)
	parent.add_child(core)

func _add_step_target(parent: Node2D, color: Color) -> void:
	for i in range(3):
		var step := ColorRect.new()
		step.color = Color(color.r, color.g, color.b, 0.38 + i * 0.10)
		step.position = Vector2(-72 + i * 52, -20 - i * 28)
		step.size = Vector2(82, 18)
		parent.add_child(step)

func _add_shadow_target(parent: Node2D, color: Color) -> void:
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(0, -88),
		Vector2(46, -36),
		Vector2(24, 20),
		Vector2(-20, 30),
		Vector2(-48, -34),
	])
	shadow.color = Color(color.r, color.g, color.b, 0.72)
	parent.add_child(shadow)
	var eye := ColorRect.new()
	eye.color = Color(0.90, 0.88, 1.0, 0.82)
	eye.position = Vector2(-9, -42)
	eye.size = Vector2(18, 6)
	parent.add_child(eye)

func _add_task_door() -> void:
	door = Node2D.new()
	door.name = "TaskExit"
	door.position = Vector2(1136, FLOOR_Y - 88)
	level_root.add_child(door)

	door_glow = ColorRect.new()
	door_glow.color = Color(0.72, 0.76, 1.0, 1.0)
	door_glow.modulate.a = 0.0
	door_glow.position = Vector2(-42, -112)
	door_glow.size = Vector2(84, 144)
	door.add_child(door_glow)

	door_visual = ColorRect.new()
	door_visual.color = Color(0.055, 0.060, 0.096)
	door_visual.position = Vector2(-25, -104)
	door_visual.size = Vector2(50, 136)
	door.add_child(door_visual)

func _add_pickups_for_task() -> void:
	var nodes: Array[String] = []
	if task_index == 0:
		nodes = ["See", "Compare", "Push"]
	elif task_index == 1:
		nodes = ["Listen", "Quiet"]
	elif task_index == 2:
		nodes = ["Remember", "Hold"]
	for i in range(nodes.size()):
		var block_id: String = nodes[i]
		if not inventory.has_block(block_id):
			_create_pickup(block_id, Vector2(286 + i * 142, FLOOR_Y - 62), _block_color(block_id))

func _create_pickup(block_id: String, pos: Vector2, color: Color) -> void:
	var area := Area2D.new()
	area.name = "%sPickup" % block_id
	area.position = pos
	area.set_meta("block_id", block_id)
	level_root.add_child(area)

	var glow := ColorRect.new()
	glow.color = Color(color.r, color.g, color.b, 0.20)
	glow.position = Vector2(-32, -52)
	glow.size = Vector2(64, 64)
	area.add_child(glow)

	var body := ColorRect.new()
	body.color = Color(color.r, color.g, color.b, 0.78)
	body.position = Vector2(-21, -42)
	body.size = Vector2(42, 42)
	area.add_child(body)

	var label := Label.new()
	label.text = block_id
	label.position = Vector2(-46, 12)
	label.size = Vector2(92, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.95, 0.94, 1.0)
	area.add_child(label)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(72, 86)
	shape.shape = rect
	area.add_child(shape)
	pickups.append(area)

func _block_color(block_id: String) -> Color:
	if block_id == "See":
		return Color(0.56, 0.74, 1.0)
	if block_id == "Listen":
		return Color(0.70, 0.90, 1.0)
	if block_id == "Remember":
		return Color(0.78, 0.66, 1.0)
	if block_id == "Compare":
		return Color(0.84, 0.84, 0.98)
	if block_id == "Hold":
		return Color(0.64, 0.90, 0.84)
	if block_id == "Quiet":
		return Color(0.90, 0.76, 1.0)
	return Color(1.0, 0.58, 0.73)

func _try_pickup() -> void:
	var nearest: Area2D = _nearest_pickup(86.0)
	if nearest == null:
		_play_feedback("error")
		_say("这里没有新的节点。她先读一读上次运行留下的 trace。")
		return
	var block_id: String = String(nearest.get_meta("block_id"))
	inventory.add_block(block_id)
	pickups.erase(nearest)
	nearest.monitoring = false
	_play_feedback("pickup")
	_say("%s 节点落进抽屉。它不是技能，只是一种让朋友判断世界的方法。" % block_id)
	var tween := create_tween()
	tween.tween_property(nearest, "scale", Vector2(1.34, 1.34), 0.14)
	tween.parallel().tween_property(nearest, "modulate:a", 0.0, 0.14)
	await tween.finished
	nearest.queue_free()

func _nearest_pickup(max_distance: float) -> Area2D:
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
		var pulse := 1.0 + sin(t * 3.0 + i) * 0.045
		pickup.scale = Vector2(pulse, pulse)

func _animate_target() -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var t := Time.get_ticks_msec() / 1000.0
	target_node.position.y = _current_target().position.y + sin(t * 1.6 + task_index) * 3.0
	if target_glow != null:
		target_glow.modulate.a = 0.72 + sin(t * 2.4) * 0.18

func _deploy_friend(sequence: Array[String]) -> void:
	if friend.active:
		_play_feedback("error")
		_say("上一个 workflow 还在运行。先等 trace 写完。")
		return
	builder.visible = false
	_play_feedback("friend")
	_say("朋友从节点之间醒来。它会运行一次，然后把原因留给莉莉丝。")
	friend.begin(sequence, self, player.global_position + Vector2(66, -4))

func run_friend_workflow(actor: Node2D, sequence: Array[String]) -> bool:
	var target: EncounterTarget = _current_target()
	var result: WorkflowResult = WorkflowEvaluator.evaluate(sequence, target)
	last_result = result
	builder.set_workflow_feedback(result.summary(), result.trace, result.next_hint)

	var approach := target.position + Vector2(-90, 28)
	var move_tween := create_tween()
	move_tween.tween_property(actor, "global_position", approach, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await move_tween.finished

	for i in range(result.steps.size()):
		var step: Dictionary = result.steps[i]
		await _play_workflow_step(actor, step)

	if not result.trace.is_empty():
		var final_line: String = result.trace[result.trace.size() - 1]
		_say(final_line)
		await get_tree().create_timer(0.20).timeout

	if result.success:
		await _resolve_target(target)
	else:
		_play_feedback("error")
		_spawn_flash(target.position, Color(0.95, 0.40, 0.72, 0.28))
	return result.success

func _play_workflow_step(actor: Node2D, step: Dictionary) -> void:
	var block_id: String = String(step["block_id"])
	var text: String = String(step["text"])
	_say(text)
	if block_id == "See":
		await _animate_see(actor)
	elif block_id == "Listen":
		await _animate_listen(actor)
	elif block_id == "Remember":
		await _animate_remember(actor)
	elif block_id == "Compare":
		await _animate_compare(actor)
	elif block_id == "Hold":
		await _animate_hold(actor)
	elif block_id == "Push":
		await _animate_push(actor)
	elif block_id == "Quiet":
		await _animate_quiet(actor)
	else:
		_spawn_flash(actor.global_position, Color(0.85, 0.72, 1.0, 0.24))
		await get_tree().create_timer(0.22).timeout

func _animate_see(_actor: Node2D) -> void:
	var scan := ColorRect.new()
	scan.color = Color(0.56, 0.74, 1.0, 0.24)
	scan.position = _current_target().position - Vector2(64, 78)
	scan.size = Vector2(128, 156)
	scan.z_index = 18
	add_child(scan)
	var tween := create_tween()
	tween.tween_property(scan, "size:x", 168.0, 0.18)
	tween.parallel().tween_property(scan, "position:x", scan.position.x - 20.0, 0.18)
	tween.tween_property(scan, "modulate:a", 0.0, 0.18)
	await tween.finished
	scan.queue_free()

func _animate_listen(_actor: Node2D) -> void:
	for i in range(3):
		var ring := ColorRect.new()
		ring.color = Color(0.70, 0.90, 1.0, 0.18)
		ring.position = _current_target().position - Vector2(18 + i * 12, 18 + i * 12)
		ring.size = Vector2(36 + i * 24, 36 + i * 24)
		ring.z_index = 18
		add_child(ring)
		var tween := create_tween()
		tween.tween_property(ring, "scale", Vector2(1.55, 1.55), 0.24)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
		tween.finished.connect(func(): ring.queue_free())
	await get_tree().create_timer(0.30).timeout

func _animate_remember(actor: Node2D) -> void:
	for i in range(4):
		var shard := ColorRect.new()
		shard.color = Color(0.78, 0.66, 1.0, 0.70)
		shard.position = actor.global_position + Vector2(-28 + i * 18, -48)
		shard.size = Vector2(8, 8)
		shard.z_index = 18
		add_child(shard)
		var tween := create_tween()
		tween.tween_property(shard, "position", actor.global_position + Vector2(-4, -22), 0.30)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.30)
		tween.finished.connect(func(): shard.queue_free())
	await get_tree().create_timer(0.34).timeout

func _animate_compare(actor: Node2D) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.86, 0.86, 1.0, 0.62)
	line.points = PackedVector2Array([actor.global_position, _current_target().position, door.global_position])
	line.z_index = 18
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.34)
	await tween.finished
	line.queue_free()

func _animate_hold(actor: Node2D) -> void:
	var ring := ColorRect.new()
	ring.color = Color(0.64, 0.90, 0.84, 0.22)
	ring.position = actor.global_position - Vector2(44, 54)
	ring.size = Vector2(88, 88)
	ring.z_index = 18
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2(1.28, 1.28), 0.30)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.30)
	await tween.finished
	ring.queue_free()

func _animate_push(actor: Node2D) -> void:
	var start_pos := actor.global_position
	var tween := create_tween()
	tween.tween_property(actor, "global_position", start_pos + Vector2(24, 0), 0.16)
	tween.tween_property(actor, "global_position", start_pos, 0.16)
	tween.parallel().tween_property(target_node, "position:x", target_node.position.x + 8.0, 0.16)
	await tween.finished

func _animate_quiet(_actor: Node2D) -> void:
	for i in range(5):
		var mote := ColorRect.new()
		mote.color = Color(0.90, 0.76, 1.0, 0.46)
		mote.position = _current_target().position + Vector2(-54 + i * 22, -56 + (i % 2) * 24)
		mote.size = Vector2(10, 10)
		mote.z_index = 18
		add_child(mote)
		var tween := create_tween()
		tween.tween_property(mote, "position", _current_target().position + Vector2(-5, -18), 0.32)
		tween.parallel().tween_property(mote, "modulate:a", 0.0, 0.32)
		tween.finished.connect(func(): mote.queue_free())
	await get_tree().create_timer(0.36).timeout

func _resolve_target(target: EncounterTarget) -> void:
	if task_resolved:
		return
	target.resolved = true
	task_resolved = true
	player.can_finish = true
	_play_feedback("door")
	_say(target.success_text)
	_spawn_flash(target.position, Color(target.color.r, target.color.g, target.color.b, 0.40))
	var tween := create_tween()
	tween.tween_property(door_visual, "modulate:a", 0.24, 0.55)
	tween.parallel().tween_property(door_glow, "modulate:a", 0.58, 0.55)
	tween.parallel().tween_property(target_node, "modulate:a", 0.42, 0.55)
	if target.kind == "flower":
		tween.parallel().tween_property(target_node, "scale", Vector2(0.82, 0.82), 0.55)
	elif target.kind == "step":
		tween.parallel().tween_property(target_node, "modulate", Color(0.82, 0.96, 1.0, 0.78), 0.55)
	elif target.kind == "shadow":
		tween.parallel().tween_property(target_node, "scale", Vector2(1.20, 0.72), 0.55)
	await tween.finished

func _on_friend_finished(success: bool) -> void:
	if success:
		builder.clear_sequence()
		_say("workflow 跑完了。朋友把结果留在抽屉里，等莉莉丝走向门。")
	else:
		_say("workflow 没有完成任务，但 trace 留下来了。改一枚节点再试。")
		var tween := create_tween()
		tween.tween_property(friend, "modulate:a", 0.0, 0.22)
		await tween.finished
		friend.visible = false
		friend.modulate.a = 1.0

func _finish_task() -> void:
	if transition_in_progress:
		return
	transition_in_progress = true
	player.set_movement_locked(true)
	var tween := create_tween()
	tween.tween_property(player, "global_position", door.global_position + Vector2(18, 52), 0.64).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(player, "modulate:a", 0.24, 0.64)
	if fade_rect != null:
		tween.parallel().tween_property(fade_rect, "modulate:a", 0.52, 0.64)
	await tween.finished
	if task_index >= CHAPTER_TASK_COUNT - 1:
		chapter_complete = true
		_play_feedback("chapter")
		_say("寂静的概率花园安静下来。莉莉丝学会了读 workflow 留下的原因。")
		_show_room_banner("Chapter 1 完成\n寂静的概率花园")
		await get_tree().create_timer(1.2).timeout
		chapter_completed.emit()
	else:
		_load_task(task_index + 1)
		if fade_rect != null:
			fade_rect.modulate.a = 0.52
			var fade_out := create_tween()
			fade_out.tween_property(fade_rect, "modulate:a", 0.0, 0.42)

func _show_room_banner(text: String) -> void:
	if chapter_banner == null:
		return
	chapter_banner.text = "Chapter 1\n%s" % text
	chapter_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(chapter_banner, "modulate:a", 1.0, 0.22)
	tween.tween_interval(1.24)
	tween.tween_property(chapter_banner, "modulate:a", 0.0, 0.36)

func _update_guidance() -> void:
	var target: EncounterTarget = _current_target()
	objective_label.text = "目标：搭建 workflow，运行后根据 trace 调整。"
	target_label.text = "%s  需要终端动作：%s" % [target.title, target.required_action]
	progress_label.text = "任务 %d/%d" % [task_index + 1, CHAPTER_TASK_COUNT]
	if last_result != null:
		confidence_label.text = last_result.summary()
	else:
		confidence_label.text = "置信度 --   风险 --"
	if target_card_label != null:
		var last_text := "上次运行：尚未运行"
		var next_text := "下一次：%s" % target.first_hint
		if last_result != null:
			last_text = "上次运行：%s" % (last_result.failure_reason if not last_result.success else "任务完成")
			next_text = "下一次：%s" % last_result.next_hint
		target_card_label.text = "%s\n%s\n需要：%s\n终端：%s\n阈值：%d%%  风险上限：%d\n%s\n%s" % [
			target.title,
			target.description_text,
			target.evidence_text,
			target.action_text,
			target.confidence_required,
			target.risk_limit,
			last_text,
			next_text,
		]

func _update_prompt() -> void:
	if prompt_label == null:
		return
	if active_pickup != null:
		prompt_label.text = "按 E 拾取 workflow 节点"
	elif task_resolved:
		prompt_label.text = "任务完成。走向右侧的门。"
	elif builder != null and builder.visible:
		prompt_label.text = "按 1-7 接节点，Enter 运行，读 trace 后再调整。"
	else:
		prompt_label.text = "Tab 打开 workflow 抽屉。失败不是惩罚，是新的反馈。"

func _on_inventory_changed(_blocks: Array[String]) -> void:
	if builder != null:
		builder.set_goal_hint(_current_target().title, "运行 workflow，读 trace，再调整节点")

func _play_feedback(kind: String) -> void:
	if kind == "pickup":
		pickup_sfx.play()
	elif kind == "drawer":
		drawer_sfx.play()
	elif kind == "block":
		block_sfx.play()
	elif kind == "friend":
		friend_sfx.play()
	elif kind == "door":
		door_sfx.play()
	elif kind == "chapter":
		chapter_sfx.play()
	else:
		error_sfx.play()

func _spawn_flash(pos: Vector2, color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.position = pos - Vector2(42, 42)
	flash.size = Vector2(84, 84)
	flash.z_index = 20
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(1.45, 1.45), 0.28)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.28)
	tween.finished.connect(func(): flash.queue_free())

func _say(text: String) -> void:
	if status_label != null:
		status_label.text = text
