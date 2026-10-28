class_name QuestionFactory
extends RefCounted
## Builds the right QuestionView subclass for a question dictionary.


static func create(question: Dictionary) -> QuestionView:
	var view: QuestionView = null
	match question.get("type", ""):
		"single_choice":
			view = SingleChoiceView.new()
		"multi_select":
			view = MultiSelectView.new()
		"ordering":
			view = OrderingView.new()
		"dialogue":
			view = DialogueView.new()
		"drag_ppe":
			view = DragPpeView.new()
		"gate_check":
			view = GateCheckView.new()
		"permit_check":
			view = PermitCheckView.new()
		"cause_chain":
			view = CauseChainView.new()
		_:
			push_error(
				(
					"QuestionFactory: unknown question type '%s' (id '%s')"
					% [question.get("type", ""), question.get("id", "?")]
				)
			)
			return null
	view.setup(question)
	return view
