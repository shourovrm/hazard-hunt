extends RefCounted
## Assertion helper handed to every test as `t`. Records failures for the runner.

var root: Node
var current_test := ""
var failures: Array[String] = []


func fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s expected <%s> but got <%s>" % [message, expected, actual])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("%s did not expect <%s>" % [message, unexpected])


func assert_not_null(value: Variant, message: String = "expected a value") -> void:
	if value == null:
		fail(message)


func assert_same_items(actual: Array, expected: Array, message: String = "") -> void:
	var sorted_actual := actual.duplicate()
	var sorted_expected := expected.duplicate()
	sorted_actual.sort()
	sorted_expected.sort()
	if sorted_actual != sorted_expected:
		fail("%s expected items %s but got %s" % [message, expected, actual])


## Collects the visible text of every Label, Button and RichTextLabel under `node`.
func collect_text(node: Node) -> String:
	var pieces: Array[String] = []
	_collect_text_into(node, pieces)
	return "\n".join(pieces)


func _collect_text_into(node: Node, pieces: Array[String]) -> void:
	if node is Label or node is Button:
		pieces.append(node.text)
	elif node is RichTextLabel:
		pieces.append(node.get_parsed_text())
	for child in node.get_children():
		_collect_text_into(child, pieces)
