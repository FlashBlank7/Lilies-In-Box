extends CanvasLayer
class_name FriendBuilder

signal deploy_requested(sequence: Array[String])
signal status_requested(text: String)
signal sequence_changed(sequence: Array[String])
signal feedback_requested(kind: String)

const PANEL_TEXTURE := preload("res://assets/ui/button_rectangle_depth_flat.png")
const BLOCK_ORDER: Array[String] = ["See", "Listen", "Remember", "Compare", "Hold", "Wait", "Push", "Quiet", "Refuse", "Stop"]
const MAX_SEQUENCE_SIZE := 6

var inventory: BlockInventory
var sequence: Array[String] = []
var panel: PanelContainer
var inventory_slots: Array[Label] = []
var routine_label: Label
var hint_label: Label
var deploy_label: Label
var workflow_summary_label: Label
var trace_label: Label
var next_hint_label: Label
var goal_text := "See -> Push"
var room_title := "第一扇门"
var workflow_summary := "朋友还没有走过这一遍"
var workflow_trace: Array[String] = []
var next_hint := "运行后，这里会出现下一次可以试试的方向。"

func setup(block_inventory: BlockInventory) -> void:
	inventory = block_inventory
	inventory.changed.connect(_on_inventory_changed)
	_refresh()

func _ready() -> void:
	layer = 12
	_build_ui()
	visible = false
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_builder"):
		visible = not visible
		feedback_requested.emit("drawer")
		if visible:
			status_requested.emit("抽屉轻轻打开。%s 想听见：%s。" % [room_title, goal_text])
		else:
			status_requested.emit("抽屉合上了，积木还在里面等她。")
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_try_add_index(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			_try_add_index(9)
		elif event.keycode == KEY_BACKSPACE:
			_remove_last()
		elif event.is_action_pressed("deploy_friend"):
			_try_deploy()
		get_viewport().set_input_as_handled()

func clear_sequence() -> void:
	sequence.clear()
	sequence_changed.emit(sequence.duplicate())
	_refresh()

func clear_workflow_feedback() -> void:
	workflow_summary = "朋友还没有走过这一遍"
	workflow_trace.clear()
	next_hint = "运行后，这里会出现下一次可以试试的方向。"
	_refresh()

func set_goal_hint(new_room_title: String, new_goal_text: String) -> void:
	room_title = new_room_title
	goal_text = new_goal_text
	_refresh()

func set_workflow_feedback(summary: String, trace: Array[String], next_hint_text: String = "") -> void:
	workflow_summary = summary
	workflow_trace = trace.duplicate()
	if not next_hint_text.is_empty():
		next_hint = next_hint_text
	_refresh()

func _build_ui() -> void:
	var backplate := NinePatchRect.new()
	backplate.texture = PANEL_TEXTURE
	backplate.position = Vector2(26, 286)
	backplate.size = Vector2(626, 380)
	backplate.modulate = Color(0.48, 0.40, 0.74, 0.26)
	add_child(backplate)

	panel = PanelContainer.new()
	panel.position = Vector2(34, 294)
	panel.custom_minimum_size = Vector2(610, 364)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "莉莉丝的回声抽屉"
	title.add_theme_font_size_override("font_size", 23)
	title.modulate = Color(0.94, 0.90, 1.0)
	box.add_child(title)

	var inventory_grid := GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(inventory_grid)
	for i in range(BLOCK_ORDER.size()):
		var slot := _make_slot_label()
		inventory_slots.append(slot)
		inventory_grid.add_child(slot)

	routine_label = Label.new()
	routine_label.add_theme_font_size_override("font_size", 22)
	routine_label.modulate = Color(1.0, 0.95, 0.82)
	box.add_child(routine_label)

	workflow_summary_label = Label.new()
	workflow_summary_label.add_theme_font_size_override("font_size", 18)
	workflow_summary_label.modulate = Color(0.82, 0.94, 1.0)
	box.add_child(workflow_summary_label)

	trace_label = Label.new()
	trace_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trace_label.custom_minimum_size = Vector2(540, 56)
	trace_label.add_theme_font_size_override("font_size", 16)
	trace_label.modulate = Color(0.74, 0.78, 0.92)
	box.add_child(trace_label)

	next_hint_label = Label.new()
	next_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_hint_label.custom_minimum_size = Vector2(540, 34)
	next_hint_label.add_theme_font_size_override("font_size", 16)
	next_hint_label.modulate = Color(0.92, 0.86, 1.0)
	box.add_child(next_hint_label)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(540, 48)
	hint_label.modulate = Color(0.78, 0.76, 0.88)
	box.add_child(hint_label)

	deploy_label = Label.new()
	deploy_label.add_theme_font_size_override("font_size", 18)
	deploy_label.modulate = Color(0.82, 0.94, 1.0)
	box.add_child(deploy_label)

func _make_slot_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(132, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_stylebox_override("normal", _make_slot_style(Color(0.10, 0.10, 0.16, 0.92), Color(0.42, 0.36, 0.58, 0.90)))
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.050, 0.075, 0.90)
	style.border_color = Color(0.45, 0.36, 0.62, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

func _make_slot_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _try_add_index(index: int) -> void:
	var blocks: Array[String] = _ordered_blocks()
	if index >= blocks.size():
		feedback_requested.emit("error")
		status_requested.emit("那个槽位还空着，像一枚没有醒来的名字。")
		return
	if sequence.size() >= MAX_SEQUENCE_SIZE:
		feedback_requested.emit("error")
		status_requested.emit("朋友已经装得满满的了。Backspace 可以拆下最后一块。")
		return
	var block_id: String = blocks[index]
	sequence.append(block_id)
	feedback_requested.emit("block")
	status_requested.emit("%s 接上去了，朋友的轮廓亮了一下。" % block_id)
	sequence_changed.emit(sequence.duplicate())
	_refresh()

func _remove_last() -> void:
	if sequence.is_empty():
		feedback_requested.emit("error")
		status_requested.emit("还没有积木可以拆下。")
		return
	var block_id: String = String(sequence.pop_back())
	feedback_requested.emit("drawer")
	status_requested.emit("%s 回到了抽屉里。" % block_id)
	sequence_changed.emit(sequence.duplicate())
	_refresh()

func _try_deploy() -> void:
	if sequence.is_empty():
		feedback_requested.emit("error")
		status_requested.emit("抽屉里还没有朋友的顺序。")
		return
	deploy_requested.emit(sequence.duplicate())

func _on_inventory_changed(_blocks: Array[String]) -> void:
	_refresh()

func _refresh() -> void:
	if inventory_slots.is_empty():
		return
	var blocks: Array[String] = _ordered_blocks()
	for i in range(inventory_slots.size()):
		var label: Label = inventory_slots[i]
		var key_text := "0" if i == 9 else str(i + 1)
		if i < blocks.size():
			label.text = "%s  %s" % [key_text, blocks[i]]
			label.modulate = Color(0.96, 0.94, 1.0)
		else:
			label.text = "%s  ..." % key_text
			label.modulate = Color(0.45, 0.43, 0.52)
	routine_label.text = "顺序  " + (" -> ".join(sequence) if not sequence.is_empty() else "等待连接")
	workflow_summary_label.text = workflow_summary
	trace_label.text = _trace_text()
	next_hint_label.text = "下一次可以试试：%s" % next_hint
	hint_label.text = "按 1-9/0 选择已拥有的节点，Backspace 撤回，Enter 运行。%s 想听见：%s。" % [room_title, goal_text]
	deploy_label.text = "Enter 释放朋友" if not sequence.is_empty() else "先给朋友接上一块积木"

func _trace_text() -> String:
	if workflow_trace.is_empty():
		return "运行后，这里会留下朋友的回声。"
	var visible_lines: Array[String] = []
	var start_index: int = max(0, workflow_trace.size() - 3)
	for i in range(start_index, workflow_trace.size()):
		var line: String = workflow_trace[i]
		visible_lines.append(line)
	return "\n".join(visible_lines)

func _ordered_blocks() -> Array[String]:
	var raw: Array[String] = []
	if inventory:
		raw = inventory.all_blocks()
	var ordered: Array[String] = []
	for i in range(BLOCK_ORDER.size()):
		var block_id: String = BLOCK_ORDER[i]
		if raw.has(block_id):
			ordered.append(block_id)
	for i in range(raw.size()):
		var block_id: String = raw[i]
		if not ordered.has(block_id):
			ordered.append(block_id)
	return ordered
