extends RefCounted
class_name WorkflowResult

var confidence := 0
var risk := 0
var cost := 0
var silence := 0
var action_intent := ""
var success := false
var failure_reason := ""
var next_hint := "读回声，再换一枚节点试试。"
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
	var extra_text := ""
	if cost > 0:
		extra_text += "  代价 %d" % cost
	if silence > 0:
		extra_text += "  沉默 %d" % silence
	return "置信度 %d%%  风险 %s%s  %s" % [confidence, risk_text, extra_text, state_text]
