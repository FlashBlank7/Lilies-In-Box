extends RefCounted
class_name EncounterTarget

var id := ""
var title := ""
var kind := ""
var required_action := ""
var required_evidence: Array[String] = []
var confidence_required := 70
var base_risk := 24
var risk_limit := 60
var cost_limit := 100
var silence_required := 0
var intro_text := ""
var success_text := ""
var unresolved_text := ""
var description_text := ""
var evidence_text := ""
var action_text := ""
var first_hint := ""
var failure_hint := ""
var resolved := false
var color := Color(0.76, 0.78, 1.0)
var position := Vector2.ZERO

func configure(
	new_id: String,
	new_title: String,
	new_kind: String,
	new_required_action: String,
	new_required_evidence: Array[String],
	new_confidence_required: int,
	new_base_risk: int,
	new_risk_limit: int,
	new_intro_text: String,
	new_success_text: String,
	new_unresolved_text: String,
	new_color: Color,
	new_position: Vector2
) -> void:
	id = new_id
	title = new_title
	kind = new_kind
	required_action = new_required_action
	required_evidence = new_required_evidence.duplicate()
	confidence_required = new_confidence_required
	base_risk = new_base_risk
	risk_limit = new_risk_limit
	intro_text = new_intro_text
	success_text = new_success_text
	unresolved_text = new_unresolved_text
	description_text = new_intro_text
	first_hint = new_unresolved_text
	failure_hint = new_unresolved_text
	color = new_color
	position = new_position

func requires_evidence(evidence_id: String) -> bool:
	return required_evidence.has(evidence_id)
