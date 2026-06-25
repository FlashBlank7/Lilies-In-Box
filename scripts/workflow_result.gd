extends RefCounted
class_name WorkflowResult

var confidence := 0
var risk := 0
var action_intent := ""
var success := false
var failure_reason := ""
var next_hint := "读 trace，再换一枚节点试试。"
var trace: Array[String] = []
var steps: Array[Dictionary] = []

func add_step(block_id: String, confidence_delta: int, risk_delta: int, text: String, terminal: bool) -> void:
	steps.append({
		"block_id": block_id,
		"confidence_delta": confidence_delta,
		"risk_delta": risk_delta,
		"text": text,
		"terminal": terminal,
	})
	trace.append(text)

func summary() -> String:
	var risk_text := "低"
	if risk > 70:
		risk_text = "高"
	elif risk > 45:
		risk_text = "中"
	var state_text := "完成" if success else "未完成"
	return "置信度 %d%%  风险 %s  %s" % [confidence, risk_text, state_text]
