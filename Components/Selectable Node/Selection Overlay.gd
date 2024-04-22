extends Control

# This script is only used to draw a rectangle above everything as we cannot do it from the SelectionContainer script!

# Used to draw the doted lines for the multi-selection
var _selection_starting_point : Vector2i = Vector2i(-1, -1)
var _selection_rect : Rect2i = Rect2i()
var _selection_stylebox : StyleBox


# Tricky maner of drawing in any node as we are only allowed to draw in _draw() methods
# Lines coordinates are relative to the node's origin point
func _draw() -> void:
	# Draw the line accross the window
	draw_style_box(_selection_stylebox, _selection_rect)


func _process(_a_delta : float) -> void:
	if _selection_starting_point != Vector2i(-1, -1):
		queue_redraw()


