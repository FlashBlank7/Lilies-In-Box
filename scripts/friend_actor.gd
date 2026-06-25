extends CharacterBody2D
class_name FriendActor

signal step(text: String)
signal finished(success: bool)

@export var move_speed := 180.0

var sequence: Array[String] = []
var room: Node
var active := false
var remembered_fact := ""
var run_token := 0

func begin(new_sequence: Array[String], owner_room: Node, start_position: Vector2) -> void:
	if active:
		return
	run_token += 1
	sequence = new_sequence.duplicate()
	room = owner_room
	remembered_fact = ""
	global_position = start_position
	visible = true
	modulate.a = 1.0
	active = true
	_run_sequence(run_token)

func cancel() -> void:
	run_token += 1
	active = false
	visible = false
	modulate.a = 1.0
	remembered_fact = ""
	sequence.clear()
	room = null

func _run_sequence(token: int) -> void:
	var success := true
	for i in range(sequence.size()):
		if token != run_token:
			return
		var block_id: String = sequence[i]
		if block_id == "See":
			success = await _do_see()
		elif block_id == "Remember":
			success = await _do_remember()
		elif block_id == "Push":
			success = await _do_push()
		else:
			step.emit("朋友摸到了一块陌生积木：%s。" % block_id)
			success = false
		if not success:
			break
		if token != run_token:
			return
	active = false
	if token == run_token:
		finished.emit(success)

func _do_see() -> bool:
	step.emit("See：朋友先看见方块，也看见按钮旁边发着微光。")
	remembered_fact = "box_to_button"
	if room != null and room.has_method("friend_notice_box"):
		await room.friend_notice_box(self)
	else:
		await get_tree().create_timer(0.55).timeout
	return true

func _do_remember() -> bool:
	if remembered_fact.is_empty():
		if room != null and room.has_method("friend_recall"):
			remembered_fact = String(room.friend_recall())
		else:
			remembered_fact = "a soft missing fact"
	step.emit("Remember：朋友把“%s”小心抱住。" % remembered_fact)
	await get_tree().create_timer(0.55).timeout
	return true

func _do_push() -> bool:
	if room == null or not room.has_method("friend_push_box"):
		step.emit("Push：朋友有力气，但世界没有给它把手。")
		return false
	if remembered_fact != "box_to_button":
		step.emit("Push：朋友推了一下空气。它还没有先看见方块。")
		await get_tree().create_timer(0.45).timeout
		return false
	step.emit("Push：朋友把方块推向按钮。")
	await room.friend_push_box(self)
	return true
