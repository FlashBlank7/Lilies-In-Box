extends Node
class_name BlockInventory

signal changed(blocks: Array[String])

var blocks: Array[String] = []

func add_block(block_id: String) -> void:
	if blocks.has(block_id):
		return
	blocks.append(block_id)
	changed.emit(blocks.duplicate())

func clear() -> void:
	if blocks.is_empty():
		return
	blocks.clear()
	changed.emit(blocks.duplicate())

func has_block(block_id: String) -> bool:
	return blocks.has(block_id)

func all_blocks() -> Array[String]:
	return blocks.duplicate()
