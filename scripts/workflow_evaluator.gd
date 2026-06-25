extends RefCounted
class_name WorkflowEvaluator

const TERMINAL_ACTIONS: Array[String] = ["Push", "Quiet"]

static func evaluate(sequence: Array[String], target: EncounterTarget) -> WorkflowResult:
	var result: WorkflowResult = WorkflowResult.new()
	var evidence: Array[String] = []
	var terminal_index := -1
	result.risk = target.base_risk

	if sequence.is_empty():
		result.failure_reason = "工作流还是空的。朋友没有醒来。"
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
		elif TERMINAL_ACTIONS.has(block_id):
			if terminal_index >= 0:
				result.trace.append("%s：朋友已经发出过一个终端动作，新的动作只让它更困惑。" % block_id)
				result.risk += 12
			else:
				terminal_index = i
				result.action_intent = block_id
				_apply_terminal(result, target, block_id)
		else:
			result.trace.append("%s：这枚节点还没有被莉莉丝理解。" % block_id)
			result.risk += 10

	result.confidence = clampi(result.confidence, 0, 100)
	result.risk = clampi(result.risk, 0, 100)
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
	result.trace.append("See：朋友看见目标轮廓，置信度 +%d%%。" % gain)

static func _apply_listen(result: WorkflowResult, target: EncounterTarget, evidence: Array[String]) -> void:
	_add_evidence(evidence, "audio")
	var gain := 34
	if target.kind == "flower":
		gain = 45
	elif target.kind == "shadow":
		gain = 36
	result.confidence += gain
	result.trace.append("Listen：朋友听见低声的原因，置信度 +%d%%。" % gain)

static func _apply_remember(result: WorkflowResult, _target: EncounterTarget, evidence: Array[String]) -> void:
	_add_evidence(evidence, "memory")
	result.confidence += 24
	result.risk -= 8
	result.trace.append("Remember：朋友抱住刚才的事实，置信度 +24%，风险 -8。")

static func _apply_compare(result: WorkflowResult, evidence: Array[String]) -> void:
	if evidence.is_empty():
		result.confidence += 8
		result.risk += 8
		result.trace.append("Compare：还没有证据可以比较，置信度只 +8%，风险 +8。")
		return
	_add_evidence(evidence, "relation")
	var gain := 34 if evidence.has("visual") else 24
	result.confidence += gain
	result.trace.append("Compare：朋友把证据放在一起，置信度 +%d%%。" % gain)

static func _apply_hold(result: WorkflowResult, evidence: Array[String]) -> void:
	_add_evidence(evidence, "steady")
	result.confidence += 10
	result.risk -= 38
	result.trace.append("Hold：朋友先稳住自己，置信度 +10%，风险 -38。")

static func _apply_terminal(result: WorkflowResult, target: EncounterTarget, block_id: String) -> void:
	if block_id == target.required_action:
		result.trace.append("%s：朋友准备执行终端动作，当前置信度 %d%%。" % [block_id, result.confidence])
	else:
		result.trace.append("%s：这个动作碰不到“%s”的核心。" % [block_id, target.title])

static func _finalize_result(result: WorkflowResult, target: EncounterTarget, evidence: Array[String], terminal_index: int, sequence_size: int) -> void:
	var missing: Array[String] = []
	for i in range(target.required_evidence.size()):
		var evidence_id: String = target.required_evidence[i]
		if not evidence.has(evidence_id):
			missing.append(evidence_id)

	if terminal_index < 0:
		result.failure_reason = "还没有终端动作。朋友理解了一些东西，却没有决定怎么触碰世界。"
	elif terminal_index < sequence_size - 1:
		result.failure_reason = "终端动作来得太早。朋友行动之后，后面的节点已经来不及帮它。"
	elif result.action_intent != target.required_action:
		result.failure_reason = "%s 不是这里需要的终端动作。" % result.action_intent
	elif not missing.is_empty():
		result.failure_reason = "缺少证据：%s。" % ", ".join(missing)
	elif result.confidence < target.confidence_required:
		result.failure_reason = "置信度还不够。需要 %d%%，现在只有 %d%%。" % [target.confidence_required, result.confidence]
	elif result.risk > target.risk_limit:
		result.failure_reason = "风险太高。朋友退回来了，避免把莉莉丝带进更深的噪声。"
	else:
		result.success = true

	if result.success:
		result.trace.append("%s：置信度足够，朋友轻轻完成了任务。" % result.action_intent)
	else:
		result.trace.append(result.failure_reason)

static func _add_evidence(evidence: Array[String], evidence_id: String) -> void:
	if not evidence.has(evidence_id):
		evidence.append(evidence_id)
