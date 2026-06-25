extends RefCounted
class_name WorkflowEvaluator

const TERMINAL_ACTIONS: Array[String] = ["Push", "Quiet", "Refuse", "Stop"]

static func evaluate(sequence: Array[String], target: EncounterTarget) -> WorkflowResult:
	var result: WorkflowResult = WorkflowResult.new()
	var evidence: Array[String] = []
	var terminal_index := -1
	result.risk = target.base_risk

	if sequence.is_empty():
		result.failure_reason = "工作流还是空的。朋友没有醒来。"
		result.next_hint = "先接上一个观察节点，再把终端动作放在最后。"
		result.trace.append(result.failure_reason)
		return result

	for i in range(sequence.size()):
		var block_id: String = sequence[i]
		if block_id == "See":
			_apply_see(result, target, evidence)
		elif block_id == "Listen":
			_apply_listen(result, target, evidence)
		elif block_id == "Remember":
			_apply_remember(result, target, evidence)
		elif block_id == "Compare":
			_apply_compare(result, evidence)
		elif block_id == "Hold":
			_apply_hold(result, evidence)
		elif block_id == "Wait":
			_apply_wait(result, evidence)
		elif TERMINAL_ACTIONS.has(block_id):
			if terminal_index >= 0:
				var duplicate_text := "%s：朋友已经发出过一个终端动作，新的动作只让它更困惑。" % block_id
				result.add_step(block_id, 0, 12, duplicate_text, true)
				result.risk += 12
				result.cost += 10
			else:
				terminal_index = i
				result.action_intent = block_id
				_apply_terminal(result, target, block_id)
		else:
			var unknown_text := "%s：这枚节点还没有被莉莉丝理解。" % block_id
			result.add_step(block_id, 0, 10, unknown_text, false)
			result.risk += 10

	result.confidence = clampi(result.confidence, 0, 100)
	result.risk = clampi(result.risk, 0, 100)
	result.cost = clampi(result.cost, 0, 100)
	result.silence = clampi(result.silence, 0, 100)
	_finalize_result(result, target, evidence, terminal_index, sequence.size())
	return result

static func _apply_see(result: WorkflowResult, target: EncounterTarget, evidence: Array[String]) -> void:
	_add_evidence(evidence, "visual")
	var gain := 30
	if target.id == "fearful_door":
		gain = 36
	elif target.kind == "shadow":
		gain = 18
	result.confidence += gain
	result.add_step("See", gain, 0, "See：朋友看见目标轮廓，置信度 +%d%%。" % gain, false)

static func _apply_listen(result: WorkflowResult, target: EncounterTarget, evidence: Array[String]) -> void:
	_add_evidence(evidence, "audio")
	var gain := 34
	if target.kind == "flower":
		gain = 45
	elif target.kind == "shadow":
		gain = 36
	result.confidence += gain
	result.add_step("Listen", gain, 0, "Listen：朋友听见低声的原因，置信度 +%d%%。" % gain, false)

static func _apply_remember(result: WorkflowResult, _target: EncounterTarget, evidence: Array[String]) -> void:
	_add_evidence(evidence, "memory")
	result.confidence += 24
	result.risk -= 8
	result.add_step("Remember", 24, -8, "Remember：朋友抱住刚才的事实，置信度 +24%，风险 -8。", false)

static func _apply_compare(result: WorkflowResult, evidence: Array[String]) -> void:
	if evidence.is_empty():
		result.confidence += 8
		result.risk += 8
		result.add_step("Compare", 8, 8, "Compare：还没有证据可以比较，置信度只 +8%，风险 +8。", false)
		return
	_add_evidence(evidence, "relation")
	var gain := 34 if evidence.has("visual") else 28
	result.confidence += gain
	result.add_step("Compare", gain, 0, "Compare：朋友把证据放在一起，置信度 +%d%%。" % gain, false)

static func _apply_hold(result: WorkflowResult, evidence: Array[String]) -> void:
	_add_evidence(evidence, "steady")
	result.confidence += 10
	result.risk -= 38
	result.add_step("Hold", 10, -38, "Hold：朋友先稳住自己，置信度 +10%，风险 -38。", false)

static func _apply_wait(result: WorkflowResult, evidence: Array[String]) -> void:
	_add_evidence(evidence, "waiting")
	_add_evidence(evidence, "silence")
	result.confidence += 16
	result.risk -= 16
	result.cost -= 16
	result.silence += 28
	result.add_step("Wait", 16, -16, "Wait：朋友没有立刻伸手，房间安静了一点，置信度 +16%，风险 -16。", false)

static func _apply_terminal(result: WorkflowResult, target: EncounterTarget, block_id: String) -> void:
	if block_id == "Push":
		result.cost += 22
	elif block_id == "Quiet":
		result.cost += 6
	elif block_id == "Refuse":
		result.cost -= 18
		result.silence += 12
	elif block_id == "Stop":
		result.cost -= 10
		result.silence += 22
	if block_id == target.required_action:
		result.add_step(block_id, 0, 0, "%s：朋友准备执行终端动作，当前置信度 %d%%。" % [block_id, result.confidence], true)
	else:
		result.add_step(block_id, 0, 0, "%s：这个动作碰不到“%s”的核心。" % [block_id, target.title], true)

static func _finalize_result(result: WorkflowResult, target: EncounterTarget, evidence: Array[String], terminal_index: int, sequence_size: int) -> void:
	var missing: Array[String] = []
	for i in range(target.required_evidence.size()):
		var evidence_id: String = target.required_evidence[i]
		if not evidence.has(evidence_id):
			missing.append(evidence_id)

	if terminal_index < 0:
		result.failure_reason = "还没有终端动作。朋友理解了一些东西，却没有决定怎么触碰世界。"
		result.next_hint = "把目标卡写着的终端动作放到 workflow 最后。"
	elif terminal_index < sequence_size - 1:
		result.failure_reason = "终端动作来得太早。朋友行动之后，后面的节点已经来不及帮它。"
		result.next_hint = "把终端动作放到最后，让证据节点先运行。"
	elif result.action_intent != target.required_action:
		result.failure_reason = "%s 不是这里需要的终端动作。" % result.action_intent
		result.next_hint = "换成目标卡里写着的终端动作。"
	elif not missing.is_empty():
		result.failure_reason = "缺少证据：%s。" % ", ".join(missing)
		result.next_hint = _hint_for_missing(missing)
	elif result.confidence < target.confidence_required:
		result.failure_reason = "置信度还不够。需要 %d%%，现在只有 %d%%。" % [target.confidence_required, result.confidence]
		result.next_hint = "多接一个能补证据的节点，再运行一次。"
	elif result.risk > target.risk_limit:
		result.failure_reason = "风险太高。朋友退回来了，避免把莉莉丝带进更深的噪声。"
		result.next_hint = "加入 Hold，让朋友先稳住自己。"
	elif result.cost > target.cost_limit:
		result.failure_reason = "代价太重。朋友的光暗了一下，又慢慢退回来。"
		result.next_hint = "加一个 Wait，或者换成更轻的终端动作。"
	elif result.silence < target.silence_required:
		result.failure_reason = "房间还太响。朋友听不见那块空白。"
		result.next_hint = "先 Wait，让沉默多留一会儿。"
	else:
		result.success = true
		result.next_hint = "任务完成了。走向右侧的门。"

	if result.success:
		result.trace.append("%s：置信度足够，朋友轻轻完成了任务。" % result.action_intent)
	else:
		result.trace.append(result.failure_reason)

static func _add_evidence(evidence: Array[String], evidence_id: String) -> void:
	if not evidence.has(evidence_id):
		evidence.append(evidence_id)

static func _hint_for_missing(missing: Array[String]) -> String:
	if missing.has("audio"):
		return "加一个 Listen，再让朋友安静下来。"
	if missing.has("relation"):
		return "先 Compare，再使用终端动作。"
	if missing.has("steady"):
		return "加入 Hold，让朋友先稳住自己。"
	if missing.has("waiting") or missing.has("silence"):
		return "加一个 Wait，让房间先安静下来。"
	if missing.has("memory"):
		return "加一个 Remember，让朋友抱住刚才的事实。"
	if missing.has("visual"):
		return "先用 See 看清目标轮廓。"
	return "读 trace，再换一枚节点试试。"
