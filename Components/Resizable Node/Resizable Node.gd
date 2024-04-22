@icon("Icon.svg")
class_name ResizableNode extends PanelContainer

## The ResizableNode class used to create a dynamically resizable node at runtime
## Features:
##[br]    - Resizable
##[br]    - Movable
##[br]    - Use magnetic feature to snap to near nodes or to parent grid (if the parent is a grid interface)
##[br]    - Can be edited via a controls panel (Alt + Left Clic)
##[br]    - Can be moved / resized outside of the parent boundaries or constrained to them
##[br]    - Can display help lines to ease the placement of nodes (alignment with other ResizableNodes)
##[br]    - If used in combination with SelectableNode and SelectionContainer it can be moved with multiple nodes

#region CONSTANTS
# The list of keyboard shortcuts for the basic actions of the explorer (editing, cancelling)
const EVENT_CANCEL : int = KEY_ESCAPE
const EVENT_EDIT : int = MOUSE_BUTTON_LEFT
#endregion

#region EXPORTED VARIABLES
@export var is_movable : bool = true: ## If set to [code]true[/code], the node is movable by clicking and dragging it accross the parent
	set = _set_is_movable
@export var is_resizable : bool = true: ## If set to [code]true[/code], the node is resizable by clicking and dragging one of the sides / corners
	set = _set_is_resizable
# Used to allow the node to be outside of the parent bouding rect
@export var is_allowed_outside_parent_rect : bool = false: ## If set to [code]true[/code], the node can be moved / resized outside of the parent rect
	set = _set_is_allowed_outside_parent_rect
@export var editable_only : bool = false: ## If set to [code]true[/code], the node will not be resizable / movable until being edited
	set = _set_editable_only
@export var bring_up_on_edition : bool = true ## If set to [code]true[/code], the node is put in front of all its siblings when edited

#region MOVER EXPORTS
@export_group("Mover options", "mover_")
@export var mover_size : int = 0: ## The height of the mover Control if no Control is selected below. 0 means the entire node's height
	set = _set_mover_size
@export var mover_control : Control: ## A custom Control used as the mover. If no control is provided, the node has its own one and its size can be adjusted above
	set = _set_mover_control
#endregion

#region RESIZER EXPORTS
@export_group("Resizer options")
@export var use_horizontal_resizing : bool = true: ## If set to [code]false[/code], the node will not be resizable horizontally
	set = _set_use_horizontal_resizing
@export var use_vertical_resizing : bool = true: ## If set to [code]false[/code], the node will not be resizable vertically
	set = _set_use_vertical_resizing
@export var handles_size : int = 4: ## The size in pixels of the handles zone that can be clicked on the node's borders to resize it
	set = _set_handles_size
@export var handles_color : Color = "#007FFF": ## The color of the handles zone that can be clicked on the node's borders. Can be a translucent color as well
	set = _set_handles_color
#endregion

#region HELPERS EXPORTS
@export_group("Helpers", "helpers_")
@export var helpers_enabled : bool = true ## If set to [code]true[/code], it shows helpers dotted lines for the node's placement / sizing when alignment with other nodes is found
@export var helpers_color : Color = Color("#FF00FF", 0.5) ## The color of the helpers dotted lines
@export var helpers_use_controls_panel : bool = true ## If set to [code]true[/code], the node will use a Controls Panel to be able to enter values for the position and size of the node
@export var helpers_controls_panel : ResizableNodeBasicControls: ## Used to define a custom Controls Panel used to edit the ResizableNode
	set = _set_helpers_controls_panel
@export var helpers_only_editable_from_controls_panel : bool = false ## If set to [code]true[/code], the node will be forced to use the Controls Panel to be able to edit the ResizableNode attributes
@export var helpers_edited_stylebox : StyleBox: ## The style of the overlay when the node is edited (should be a translucent StyleBoxFlat)
	set = _set_helpers_edited_stylebox
#endregion
#endregion

#region TREE NODES
# WARNING: As we will use this node dynamically, we have to populate the nodes in the _ready() method!
# Get the needed nodes
# The styling overlay used to color the node when edited
var _styling : PanelContainer
# The global overlay
var _overlays : PanelContainer
var _mover_overlay : VBoxContainer
var _mover_button : Button # The default mover control (can be overridden by a custom control)
var _mover_spacer : Control
# The resizing handles
var _handles_overlay : VBoxContainer
var _top_left_handle_button : Button
var _top_handle_button : Button
var _top_right_handle_button : Button
var _left_handle_button : Button
var _right_handle_button : Button
var _bottom_left_handle_button : Button
var _bottom_handle_button : Button
var _bottom_right_handle_button : Button
# The controls container
var _controls_container : PanelContainer
#endregion

#region PUBLIC VARIABLES
# Used to know if the controls panel is above, below, to the left, to the right or inside the node (according to the available space around / inside)
var controls_placement : int = ResizableNodeDefaultControlsPanel.PLACEMENTS.ABOVE

# Used to provide design helpers at runtime between resizable nodes (like alignments and snapping)
var local_rect : Rect2:
	get: return get_rect()

# Useful flags
var _can_move : bool = true # If the node is not in a container
var can_move : bool: # Used to create a read-only variable
	set(a_value): printerr("ResizableNode.can_move is read-only!")
	get: return _can_move
var is_edited : bool = false # If the node is currently in edition mode
#var is_selected : bool = false # If the node is currently selected
var is_moved : bool = false # If the node is currently moved
# Or if the node is currently resized
var is_top_left_resized : bool = false
var is_top_resized : bool = false
var is_top_right_resized : bool = false
var is_right_resized : bool = false
var is_bottom_right_resized : bool = false
var is_bottom_resized : bool = false
var is_bottom_left_resized : bool = false
var is_left_resized : bool = false
# To simplify the above
var is_horizontally_resized : bool = false
var is_vertically_resized : bool = false
# Global for the above
var is_resized : bool = false

# Used to avoid the edition of this node when another node is already edited
var avoid_edition : bool = false
# To use the snapping function of the node with other nodes
var use_snapping : bool = true
# The distance in pixel from where this node will snap to any other ResizableNode
var snapping_threshold : int = 4
# Used to be able to move more than one node at the same time
var moving_group : ResizableNodeGroup
var position_offsets : Vector2i = Vector2i.ZERO
var _starting_position : Vector2i = Vector2i.ZERO
#endregion

#region PRIVATE VARIABLES
# Used to store the last validated (or known) position / size of the node before edition (so we can cancel the edition)
var _last_position : Vector2i
var _last_size : Vector2i
# Used to avoid resizing when content is condensed
var _previous_position : Vector2i
var _previous_size : Vector2i

# Used to store the cursor of the mouse when moving the node
var _last_mouse_cursor : CursorShape

# The minimum size of the node (according to the flags)
var _minimum_width : int = 0
var _minimum_height : int = 0

# Used to know if the node is ready (as we use the @export keyword)
var _is_ready : bool = false

# The guide lines used to help resize / move the node
var _helper_lines : Dictionary = {
	left = {visible = false, value = 0},
	top = {visible = false, value = 0},
	right = {visible = false, value = 0},
	bottom = {visible = false, value = 0}
}
# The panel used to edit the node (optional)
var _controls_panel : ResizableNodeBasicControls
# The direct parent of this node
var _parent_node : Control
# The handles list
var _handles : Array[Button]
# The mover Control
var _mover : Control
# This is the list of all the other resizable nodes that share a border position with this node
var _sharing_border_nodes : Dictionary = {}
# The edited stylebox style
var _edited_stylebox : StyleBox
#endregion


#region METHODS
# Method used to compute the offsets of the moved node since the last position
func _compute_offsets() -> void:
	position_offsets = Vector2i(int(position.x) - _starting_position.x, int(position.y) - _starting_position.y)
	_starting_position = Vector2i(position)


# Tricky maner of drawing in any node as we are only allowed to draw in _draw() methods
# Lines coordinates are relative to the node's origin point
func _draw() -> void:
	# If we are editing the node and we want the helpers
	if (is_edited or is_resized or is_moved) and helpers_enabled:
		# If we have the left line to draw
		if _helper_lines.left.visible:
			# Draw the line accross the window
			draw_dashed_line(
				Vector2(_helper_lines.left.value, -local_rect.position.y),
				Vector2(_helper_lines.left.value, (Utils.window_size.height - local_rect.position.y)),
				helpers_color
			)
		
		# If we have the top line to draw
		if _helper_lines.top.visible:
			# Draw the line accross the parent
			draw_dashed_line(
				Vector2(-local_rect.position.x, _helper_lines.top.value),
				Vector2((Utils.window_size.width - local_rect.position.x), _helper_lines.top.value),
				helpers_color
			)
		
		# If we have the right line to draw
		if _helper_lines.right.visible:
			# Draw the line accross the parent
			draw_dashed_line(
				Vector2(_helper_lines.right.value, -local_rect.position.y),
				Vector2(_helper_lines.right.value, (Utils.window_size.height - local_rect.position.y)),
				helpers_color
			)
		
		# If we have the bottom line to draw
		if _helper_lines.bottom.visible:
			# Draw the line accross the parent
			draw_dashed_line(
				Vector2(-local_rect.position.x, _helper_lines.bottom.value),
				Vector2((Utils.window_size.width - local_rect.position.x), _helper_lines.bottom.value),
				helpers_color
			)


# Method used to get the borders in common with the other resizable nodes
func get_common_borders() -> void:
	# Clear the list first
	_sharing_border_nodes.clear()
	
	# Store the node boundaries to access them more easily in the loop below
	var l_left : int = int(local_rect.position.x)
	var l_top : int = int(local_rect.position.y)
	var l_right : int = int(local_rect.end.x)
	var l_bottom : int = int(local_rect.end.y)
	
	#print("This node (%s) boundaries = %s, %s, %s, %s" % [name, l_left, l_top, l_right, l_bottom])
	
	# For each ResizableNode in the scene
	for l_other_node : ResizableNode in get_tree().get_nodes_in_group("Resizable Nodes"):
		# If the node is not this one and is visible
		if l_other_node != self and l_other_node.visible and ((moving_group and moving_group != l_other_node.moving_group) or not moving_group):
			# Get the unique ID of this other node
			var l_node_id : int = l_other_node.get_instance_id()
			# This other node boundaries
			var l_o_n_left : int = int(l_other_node.local_rect.position.x)
			var l_o_n_top : int = int(l_other_node.local_rect.position.y)
			var l_o_n_right : int = int(l_other_node.local_rect.end.x)
			var l_o_n_bottom : int = int(l_other_node.local_rect.end.y)
			# Used to know if we share a common border with this other node
			var l_share_left : bool = l_left == l_o_n_left
			var l_share_top : bool = l_top == l_o_n_top
			var l_share_right : bool = l_right == l_o_n_right
			var l_share_bottom : bool = l_bottom == l_o_n_bottom
			# Used to now if we have an opposite border with this other node
			var l_neighbor_by_left : bool = l_left == l_o_n_right
			var l_neighbor_by_top : bool = l_top == l_o_n_bottom
			var l_neighbor_by_right : bool = l_right == l_o_n_left
			var l_neighbor_by_bottom : bool = l_bottom == l_o_n_top
			# Get the magnetized zone around the boundaries of this other node
			var l_min_left : int = l_o_n_left - snapping_threshold
			var l_max_left : int = l_o_n_left + snapping_threshold
			var l_min_top : int = l_o_n_top - snapping_threshold
			var l_max_top : int = l_o_n_top + snapping_threshold
			var l_min_right : int = l_o_n_right - snapping_threshold
			var l_max_right : int = l_o_n_right + snapping_threshold
			var l_min_bottom : int = l_o_n_bottom - snapping_threshold
			var l_max_bottom : int = l_o_n_bottom + snapping_threshold
			
			# The offset of the common border position
			var l_left_shared_offset : int = 0
			var l_top_shared_offset : int = 0
			var l_right_shared_offset : int = 0
			var l_bottom_shared_offset : int = 0
			var l_left_neighbored_offset : int = 0
			var l_top_neighbored_offset : int = 0
			var l_right_neighbored_offset : int = 0
			var l_bottom_neighbored_offset : int = 0
			
			# The strength of the magnetism for each side
			var l_strength : int = snapping_threshold + 1
			var l_left_shared_snapping_strength : int = l_strength
			var l_top_shared_snapping_strength : int = l_strength
			var l_right_shared_snapping_strength : int = l_strength
			var l_bottom_shared_snapping_strength : int = l_strength
			var l_left_neighbored_snapping_strength : int = l_strength
			var l_top_neighbored_snapping_strength : int = l_strength
			var l_right_neighbored_snapping_strength : int = l_strength
			var l_bottom_neighbored_snapping_strength : int = l_strength
			
			# If the snapping is used and we are not moving multiple nodes at the same time
			if use_snapping:
				# Update the flags according to the magnetized zone (if needed)
				l_share_left = l_share_left or (l_left >= l_min_left and l_left <= l_max_left)
				l_share_top = l_share_top or (l_top >= l_min_top and l_top <= l_max_top)
				l_share_right = l_share_right or (l_right >= l_min_right and l_right <= l_max_right)
				l_share_bottom = l_share_bottom or (l_bottom >= l_min_bottom and l_bottom <= l_max_bottom)
				l_neighbor_by_left = l_neighbor_by_left or (l_left >= l_min_right and l_left <= l_max_right)
				l_neighbor_by_top = l_neighbor_by_top or (l_top >= l_min_bottom and l_top <= l_max_bottom)
				l_neighbor_by_right = l_neighbor_by_right or (l_right >= l_min_left and l_right <= l_max_left)
				l_neighbor_by_bottom = l_neighbor_by_bottom or (l_bottom >= l_min_top and l_bottom <= l_max_top)
			
				# Now compute the offsets from this other node boundaries where applicable
				l_left_shared_offset = l_o_n_left - l_left if l_share_left else 0
				l_top_shared_offset = l_o_n_top - l_top if l_share_top else 0
				l_right_shared_offset = l_o_n_right - l_right if l_share_right else 0
				l_bottom_shared_offset = l_o_n_bottom - l_bottom if l_share_bottom else 0
				l_left_neighbored_offset = l_o_n_right - l_left if l_neighbor_by_left else 0
				l_top_neighbored_offset = l_o_n_bottom - l_top if l_neighbor_by_top else 0
				l_right_neighbored_offset = l_o_n_left - l_right if l_neighbor_by_right else 0
				l_bottom_neighbored_offset = l_o_n_top - l_bottom if l_neighbor_by_bottom else 0
			
				# Finally compute the magnetism strengths from this other node boundaries where applicable
				l_left_shared_snapping_strength = l_left_shared_snapping_strength - abs(l_left_shared_offset) if l_share_left else 0
				l_top_shared_snapping_strength = l_top_shared_snapping_strength - abs(l_top_shared_offset) if l_share_top else 0
				l_right_shared_snapping_strength = l_right_shared_snapping_strength - abs(l_right_shared_offset) if l_share_right else 0
				l_bottom_shared_snapping_strength = l_bottom_shared_snapping_strength - abs(l_bottom_shared_offset) if l_share_bottom else 0
				l_left_neighbored_snapping_strength = l_left_neighbored_snapping_strength - abs(l_left_neighbored_offset) if l_neighbor_by_left else 0
				l_top_neighbored_snapping_strength = l_top_neighbored_snapping_strength - abs(l_top_neighbored_offset) if l_neighbor_by_top else 0
				l_right_neighbored_snapping_strength = l_right_neighbored_snapping_strength - abs(l_right_neighbored_offset) if l_neighbor_by_right else 0
				l_bottom_neighbored_snapping_strength = l_bottom_neighbored_snapping_strength - abs(l_bottom_neighbored_offset) if l_neighbor_by_bottom else 0
			
			#print("Other node (%s) boundaries = %s, %s, %s, %s, shared = %s, %s, %s, %s, neighbored = %s, %s, %s, %s" % [
				#l_other_node.name, l_o_n_left, l_o_n_top, l_o_n_right, l_o_n_bottom,
				#l_share_left, l_share_top, l_share_right, l_share_bottom,
				#l_neighbor_by_left, l_neighbor_by_top, l_neighbor_by_right, l_neighbor_by_bottom
			#])
			
			# If this other node shares a boundary with the current node
			if l_share_left or l_share_top or l_share_right or l_share_bottom \
			or l_neighbor_by_left or l_neighbor_by_top or l_neighbor_by_right or l_neighbor_by_bottom:
				# Create a dictionary with relevant infos
				var l_other_node_infos : Dictionary = {
					node = l_other_node,
					shared_borders = {
						left = l_share_left,
						top = l_share_top,
						right = l_share_right,
						bottom = l_share_bottom
					},
					shared_snapping_strengths = {
						left = l_left_shared_snapping_strength,
						top = l_top_shared_snapping_strength,
						right = l_right_shared_snapping_strength,
						bottom = l_bottom_shared_snapping_strength
					},
					shared_snapping_offsets = {
						left = l_left_shared_offset,
						top = l_top_shared_offset,
						right = l_right_shared_offset,
						bottom = l_bottom_shared_offset
					},
					neighbored_borders = {
						left = l_neighbor_by_left,
						top = l_neighbor_by_top,
						right = l_neighbor_by_right,
						bottom = l_neighbor_by_bottom
					},
					neighbored_snapping_strengths = {
						left = l_left_neighbored_snapping_strength,
						top = l_top_neighbored_snapping_strength,
						right = l_right_neighbored_snapping_strength,
						bottom = l_bottom_neighbored_snapping_strength
					},
					neighbored_snapping_offsets = {
						left = l_left_neighbored_offset,
						top = l_top_neighbored_offset,
						right = l_right_neighbored_offset,
						bottom = l_bottom_neighbored_offset
					},
				}
				
				# Update or add the node to the list
				_sharing_border_nodes[l_node_id] = l_other_node_infos


# Method called when a another resizable node is resized / moved to show some design helpers
func _handle_helpers() -> void:
	# If we don't use the default Controls Panel
	if not _controls_panel is ResizableNodeDefaultControlsPanel:
		# Ensure the Controls Panel is linked again
		_controls_panel.link_to_node(self)
	
	# Here we handle the design helpers
	# Get the common borders from any other resizable node (according to the snapping option as well)
	get_common_borders()
	
	# Used to get the more suitable node (if more than one is close to the sharing border and we use snapping helper)
	var l_final_left : int = -1
	var l_final_top : int = -1
	var l_final_right : int = -1
	var l_final_bottom : int = -1
	var l_strongest_left : int = 0
	var l_strongest_top : int = 0
	var l_strongest_right : int = 0
	var l_strongest_bottom : int = 0
	# The offset used to move / resize the node correctly
	var l_left_offset : int = 0
	var l_top_offset : int = 0
	var l_right_offset : int = 0
	var l_bottom_offset : int = 0
	
	#print("Sharing borders = %s" % [_sharing_border_nodes])
	# For each node sharing a border position in the list
	for l_sharing_node : int in _sharing_border_nodes:
		# For each shared border
		if _sharing_border_nodes[l_sharing_node].shared_borders.left:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.left > l_strongest_left:
					# Consider the sharing node as the final one
					l_final_left = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.x)
					# Store the strength as well
					l_strongest_left = _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.left
					# And the offset
					l_left_offset = _sharing_border_nodes[l_sharing_node].shared_snapping_offsets.left
			# If we don't use the snapping helper
			else:
				l_final_left = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.x)
		
		if _sharing_border_nodes[l_sharing_node].shared_borders.top:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.top > l_strongest_top:
					# Consider the sharing node as the final one
					l_final_top = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.y)
					# Store the strength as well
					l_strongest_top = _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.top
					# And the offset
					l_top_offset = _sharing_border_nodes[l_sharing_node].shared_snapping_offsets.top
			# If we don't use the snapping helper
			else:
				l_final_top = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.y)
		
		if _sharing_border_nodes[l_sharing_node].shared_borders.right:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.right > l_strongest_right:
					# Consider the sharing node as the final one
					l_final_right = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.x)
					# Store the strength as well
					l_strongest_right = _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.right
					# And the offset
					l_right_offset = _sharing_border_nodes[l_sharing_node].shared_snapping_offsets.right
			# If we don't use the snapping helper
			else:
				l_final_right = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.x)
		
		if _sharing_border_nodes[l_sharing_node].shared_borders.bottom:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.bottom > l_strongest_bottom:
					# Consider the sharing node as the final one
					l_final_bottom = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.y)
					# Store the strength as well
					l_strongest_bottom = _sharing_border_nodes[l_sharing_node].shared_snapping_strengths.bottom
					# And the offset
					l_bottom_offset = _sharing_border_nodes[l_sharing_node].shared_snapping_offsets.bottom
			# If we don't use the snapping helper
			else:
				l_final_bottom = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.y)
	
		# For each neighbored border
		if _sharing_border_nodes[l_sharing_node].neighbored_borders.left:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.left > l_strongest_left:
					# Consider the sharing node as the final one
					l_final_left = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.x)
					# Store the strength as well
					l_strongest_left = _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.left
					# And the offset
					l_left_offset = _sharing_border_nodes[l_sharing_node].neighbored_snapping_offsets.left
			# If we don't use the snapping helper
			else:
				l_final_left = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.x)
		
		if _sharing_border_nodes[l_sharing_node].neighbored_borders.top:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.top > l_strongest_top:
					# Consider the sharing node as the final one
					l_final_top = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.y)
					# Store the strength as well
					l_strongest_top = _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.top
					# And the offset
					l_top_offset = _sharing_border_nodes[l_sharing_node].neighbored_snapping_offsets.top
			# If we don't use the snapping helper
			else:
				l_final_top = int(_sharing_border_nodes[l_sharing_node].node.local_rect.end.y)
		
		if _sharing_border_nodes[l_sharing_node].neighbored_borders.right:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.right > l_strongest_right:
					# Consider the sharing node as the final one
					l_final_right = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.x)
					# Store the strength as well
					l_strongest_right = _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.right
					# And the offset
					l_right_offset = _sharing_border_nodes[l_sharing_node].neighbored_snapping_offsets.right
			# If we don't use the snapping helper
			else:
				l_final_right = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.x)
		
		if _sharing_border_nodes[l_sharing_node].neighbored_borders.bottom:
			# If we use the snapping helper
			if use_snapping:
				# If the sharing node has a stronger strength than the actual stored value (meaning it is closer to the resized node)
				if _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.bottom > l_strongest_bottom:
					# Consider the sharing node as the final one
					l_final_bottom = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.y)
					# Store the strength as well
					l_strongest_bottom = _sharing_border_nodes[l_sharing_node].neighbored_snapping_strengths.bottom
					# And the offset
					l_bottom_offset = _sharing_border_nodes[l_sharing_node].neighbored_snapping_offsets.bottom
			# If we don't use the snapping helper
			else:
				l_final_bottom = int(_sharing_border_nodes[l_sharing_node].node.local_rect.position.y)
	
	#print("Finals = %s, %s, %s, %s" % [l_final_left, l_final_top, l_final_right, l_final_bottom])
	
	# If we finally share a border
	if l_final_left != -1:
		# If we use the snapping helper
		if use_snapping:
			# Move the node to the sharing border coordinates
			position.x = l_final_left
			
			# If we are resizing the node
			if is_resized:
				# Move the right border to the final one, resizing the node accordingly
				size.x -= l_left_offset
		
		# Enable the left line
		_helper_lines.left.value = 0
		_helper_lines.left.visible = true
	# Disable the left line
	else:
		# Disable the left line
		_helper_lines.left.value = 0
		_helper_lines.left.visible = false
	
	if l_final_top != -1:
		# If we use the snapping helper
		if use_snapping:
			# Move the node to the sharing border coordinates
			position.y = l_final_top
			
			# If we are resizing the node
			if is_resized:
				# Move the right border to the final one, resizing the node accordingly
				size.y -= l_top_offset
		
		# Enable the top line
		_helper_lines.top.value = 0
		_helper_lines.top.visible = true
	else:
		# Disable the top line
		_helper_lines.top.value = 0
		_helper_lines.top.visible = false
	
	if l_final_right != -1:
		# If we use the snapping helper
		if use_snapping:
			# If we are moving the node
			if is_moved:
				# Move the node to the sharing border coordinates
				position.x = l_final_right - int(local_rect.size.x)
			# If we are resizing the node
			elif is_resized:
				# Move the right border to the final one, resizing the node accordingly
				size.x += l_right_offset
		
		# Enable the right line
		_helper_lines.right.value = int(size.x) + 1
		_helper_lines.right.visible = true
	else:
		# Disable the right line
		_helper_lines.right.value = 0
		_helper_lines.right.visible = false
	
	if l_final_bottom != -1:
		# If we use the snapping helper
		if use_snapping:
			# If we are moving the node
			if is_moved:
				# Move the node to the sharing border coordinates
				position.y = l_final_bottom - int(local_rect.size.y)
			# If we are resizing the node
			elif is_resized:
				# Move the right border to the final one, resizing the node accordingly
				size.y += l_bottom_offset
		
		# Enable the bottom line
		_helper_lines.bottom.value = int(size.y) + 1
		_helper_lines.bottom.visible = true
	else:
		# Disable the bottom line
		_helper_lines.bottom.value = 0
		_helper_lines.bottom.visible = false
	
	# Ensure the helper lines are updated
	queue_redraw()


func _input(a_event : InputEvent) -> void:
	# Ignore the event if the node is not visible
	if not visible:
		return
	
	# If the events are blocked
	if Utils.events_are_blocked(self):
		#print("Resizable Node \"%s\" Input is blocked!" % [name])
		# Ignore this event
		return
	
	# Get the event as a key one or null
	var l_key_event : InputEventKey = a_event as InputEventKey
	
	# If the event exists
	if l_key_event:
		#debug("Key event triggered for %s (edited = %s)!" % [name, is_edited])
		# Depending on the key
		if is_edited and l_key_event.keycode == EVENT_CANCEL:
			#debug("Cancel event triggered for %s!" % [name])
			_on_cancel_event()
			# Indicate we handled the input event
			get_viewport().set_input_as_handled()
			
	# Get the event as a mouse button one or null
	var l_mouse_event : InputEventMouseButton = a_event as InputEventMouseButton
	
	# If the event exists
	if l_mouse_event and l_mouse_event.button_index == EVENT_EDIT and l_mouse_event.pressed:
		#print("Resizable Node \"%s\" Input" % [name])
		# If the click is over this node
		if get_global_rect().has_point(l_mouse_event.global_position):
			# Ensure we cannot select another node right now
			Utils.block_events(self)
			
			#debug("Clicked the \"%s\" node" % [name])
			# If the node can be edited and we use the edit shortcut
			if not avoid_edition and l_mouse_event.alt_pressed:
				#debug("    %s node is not selectable or is editable only" % [name])
				#debug("%s node should be edited now" % [name])
				_on_toggle_edit_event()
		# If the click is not over this node, we want to unedit this node if the click is over another ResizableNode
		else:
			#debug("Not over the \"%s\" node" % [name])
			# Get all the resizable nodes
			var l_other_nodes : Array[Node] = get_tree().get_nodes_in_group("Resizable Nodes")
			# Used to know if we found another ResizableNode under the mouse cursor
			var l_found_node : Variant = null
			
			# For each ResizableNode
			for l_node : ResizableNode in l_other_nodes:
				# If this is us
				if l_node == self:
					# Ignore
					continue
				
				# If the mouse click was on the current node
				if l_node.get_global_rect().has_point(l_mouse_event.global_position):
					# Indicate we found one and exit the loop
					l_found_node = l_node
					break
			
			# If we found at least 1 ResizableNode under the mouse click
			if l_found_node:
				# Only if this node is edited
				if is_edited:
					# Unedit it
					_on_toggle_edit_event()


# Triggered when the application window size is modified
func _on_application_update_interface_disposition() -> void:
	# We simply force the helper lines to redraw
	queue_redraw()


# Method called when the cancel event is triggered
func _on_cancel_event() -> void:
	# If this node is edited
	if is_edited:
		#debug("Unselecting %s (cancel)" % [name])
		
		_on_toggle_edit_event()
		
		# Restore the last position / size of the node
		position = _last_position
		custom_minimum_size = _last_size
		# We need to delay the resizing of the node by 1 frame to ensure the proper size is applied (fixes a bug)
		await get_tree().process_frame
		size = custom_minimum_size


# Method called when the height edit value is changed
func _on_height_value_submitted(a_value : String) -> void:
	# Used to handle the operators feature
	var l_add : bool = false
	var l_subtract : bool = false
	var l_multiply : bool = false
	var l_divide : bool = false
	
	# If the first character is a + sign
	if a_value[0] == "+":
		l_add = true
	# If the first character is a - sign
	elif a_value[0] == "-":
		l_subtract = true
	# If the first character is a * sign
	elif a_value[0] == "*":
		l_multiply = true
	# If the first character is a / sign
	elif a_value[0] == "/":
		l_divide = true
	
	# If there is an operator
	if l_add or l_subtract or l_multiply or l_divide:
		# Get rid of the sign now
		a_value = a_value.substr(1)
	
	# Ensure the new value string is a number
	if a_value.is_valid_int():
		# Ensure we can resize the node
		custom_minimum_size.y = 0
		
		# If we want to add the value to the current one
		if l_add:
			size.y += a_value.to_int()
		# If we want to subtract the value from the current one
		elif l_subtract:
			size.y -= a_value.to_int()
		# If we want to multiply the current value by the provided one
		elif l_multiply:
			size.y *= a_value.to_int()
		# If we want to divide the current value by the provided one
		elif l_divide:
			size.y = roundi(size.y / a_value.to_int())
		# If we provide a new value
		else:
			# Set the position of the node accordingly
			size.y = a_value.to_int()
		
		# Ensure the minimum height is preserved
		size.y = max(size.y, _minimum_height)
		
		# If the node cannot be outside its parent rect
		if not is_allowed_outside_parent_rect:
			# Ensure the size is bound to the max possible
			size.y  = min(size.y, int(_parent_node.size.y) - int(position.y))
		
		# Update the previous position and size accordingly
		_previous_position = position
		_previous_size = size
		
		# Handle the magnetism if applicable
		_handle_helpers()
	
		# Compute the position offsets
		_compute_offsets()
		
		# Update the Controls
		Signals.components_resizable_node_is_resized_or_moved.emit(self)


# Method called when the left edit value is changed
func _on_left_value_submitted(a_value : String) -> void:
	# Used to handle the operators feature
	var l_add : bool = false
	var l_subtract : bool = false
	var l_negate : bool = false
	var l_multiply : bool = false
	var l_divide : bool = false
	
	# If the first character is a + sign
	if a_value[0] == "+":
		l_add = true
	# If the first character is a - sign
	elif a_value[0] == "-":
		# Here we check if there is not another - sign as we can have 2 different capabilities with this sign (subtracting or offsetting)
		if a_value[1] == "-":
			l_negate = true
		else:
			l_subtract = true
	# If the first character is a * sign
	elif a_value[0] == "*":
		l_multiply = true
	# If the first character is a / sign
	elif a_value[0] == "/":
		l_divide = true
	
	# If there is negate signs
	if l_negate:
		# Get rid of the signs now
		a_value = a_value.substr(2)
	# If there is a single operator
	elif l_add or l_subtract or l_multiply or l_divide:
		# Get rid of the sign now
		a_value = a_value.substr(1)
	
	# Ensure the new value string is a number
	if a_value.is_valid_int():
		# If we want to add the value to the current one
		if l_add:
			position.x += a_value.to_int()
		# If we want to subtract the value from the current one
		elif l_subtract:
			position.x -= a_value.to_int()
		# If we want to set a negative value
		elif l_negate:
			position.x = -a_value.to_int()
		# If we want to multiply the current value by the provided one
		elif l_multiply:
			position.x *= a_value.to_int()
		# If we want to divide the current value by the provided one
		elif l_divide:
			position.x = roundi(position.x / a_value.to_int())
		# If we provide a new value
		else:
			# Set the position of the node accordingly
			position.x = a_value.to_int()
		
		# If the node cannot be outside the parent rect
		if not is_allowed_outside_parent_rect:
			# Ensure the minimum left is provided
			position.x = min(max(int(position.x), 0), int(_parent_node.size.x - size.x))
		
		# Update the previous position and size accordingly
		_previous_position = position
		_previous_size = size
		
		# Handle the magnetism if applicable
		_handle_helpers()
	
		# Compute the position offsets
		_compute_offsets()
		# Update the Controls
		Signals.components_resizable_node_is_resized_or_moved.emit(self)


# Method called when an input is triggered on the mover or a handle button
func _on_overlay_controls_input(a_event : InputEvent, a_control : Control) -> void:
	# Get the input event as a mouse button or null
	var l_mouse_button : InputEventMouseButton = a_event as InputEventMouseButton
	# Get the input event as a mouse motion or null
	var l_mouse_motion : InputEventMouseMotion = a_event as InputEventMouseMotion
	
	# If we have a left mouse button event
	if l_mouse_button and l_mouse_button.button_index == MOUSE_BUTTON_LEFT and (not editable_only or is_edited):
		# If the passed control is the mover
		if a_control == _mover:
			# If the button is pressed
			if l_mouse_button.pressed:
				#debug("Starting to move...")
				
				is_moved = true
				# Store the current mouse cursor
				_last_mouse_cursor = _mover.mouse_default_cursor_shape
				# Set the mouse cursor to a move one now
				_mover.mouse_default_cursor_shape = Control.CURSOR_MOVE
				
				# If we use the control panel
				if helpers_use_controls_panel:
					# Ensure the focus is removed from the edits (we pass it to a label, which will not change its visual)
					_controls_panel.clear_focus()
				
				# Set the previous position / size from the actual ones
				_previous_position = Vector2i(position)
				_previous_size = Vector2i(size)
				
				_starting_position = _previous_position
				
				# Handle the magnetism if applicable
				_handle_helpers()
				
				# Compute the position offsets
				_compute_offsets()
				
				# Update the Controls
				Signals.components_resizable_node_is_resized_or_moved.emit(self)
			# If the button is released
			else:
				#debug("Stopping the move")
				is_moved = false
				# Restore the mouse cursor
				_mover.mouse_default_cursor_shape = _last_mouse_cursor
				# We need to update the helper lines (show or hide them if any)
				queue_redraw()
				
				# If the node is not edited
				if not is_edited:
					# If the controls panel is the default one
					if _controls_panel is ResizableNodeDefaultControlsPanel:
						# Hide the controls panel now
						_controls_panel.hide()
					# If the controls panel is a custom one
					else:
						# Disable the default controls
						_controls_panel.disable()
		# If the passed control is a handle
		elif a_control == _top_left_handle_button or a_control == _top_handle_button or a_control == _top_right_handle_button \
		or a_control == _left_handle_button or a_control == _right_handle_button or a_control == _bottom_left_handle_button \
		or a_control == _bottom_handle_button or a_control == _bottom_right_handle_button:
			# If the button is pressed
			if l_mouse_button.pressed:
				#debug("Starting to resize...")
				# According to the provided button
				match a_control:
					_top_left_handle_button: is_top_left_resized = true
					_top_handle_button: is_top_resized = true
					_top_right_handle_button: is_top_right_resized = true
					_left_handle_button: is_left_resized = true
					_right_handle_button: is_right_resized = true
					_bottom_left_handle_button: is_bottom_left_resized = true
					_bottom_handle_button: is_bottom_resized = true
					_bottom_right_handle_button: is_bottom_right_resized = true
				
				# If we use the controls panel
				if helpers_use_controls_panel:
					# Ensure the focus is removed from the edits
					_controls_panel.clear_focus()
				
				# Update the grip flags accordingly
				_update_resizing_flags()
				# Store the actual position and size as well
				_previous_position = Vector2i(position)
				_previous_size = Vector2i(size)
				
				# Handle the magnetism if applicable
				_handle_helpers()
				# Update the Controls
				Signals.components_resizable_node_is_resized_or_moved.emit(self)
			# If the button is released
			else:
				#debug("Stopping the resize")
				# According to the provided button
				match a_control:
					_top_left_handle_button: is_top_left_resized = false
					_top_handle_button: is_top_resized = false
					_top_right_handle_button: is_top_right_resized = false
					_left_handle_button: is_left_resized = false
					_right_handle_button: is_right_resized = false
					_bottom_left_handle_button: is_bottom_left_resized = false
					_bottom_handle_button: is_bottom_resized = false
					_bottom_right_handle_button: is_bottom_right_resized = false
				
				# Update the grip flags accordingly
				_update_resizing_flags()
				# We need to update the helper lines (show or hide them if any)
				queue_redraw()
				
				# If the node is not edited
				if not is_edited:
					# If the controls panel is the default one
					if _controls_panel is ResizableNodeDefaultControlsPanel:
						# Hide the controls panel now
						_controls_panel.hide()
					# If the controls panel is a custom one
					else:
						# Disable the default controls
						_controls_panel.disable()
	# If we have a mouse motion event
	elif l_mouse_motion:
		# If we are moving the node
		if can_move and is_moved:
			#debug("Moving...")
			# Set the mouse cursor to a move one
			_mover.mouse_default_cursor_shape = Control.CURSOR_MOVE
			
			# Used to compute the node position
			var l_position : Vector2i = _previous_position
			# Move the node according to the mouse relative position (from the last frame)
			l_position += Vector2i(l_mouse_motion.relative)
			
			# If the node is not allowed outside the parent rect
			if not is_allowed_outside_parent_rect:
				# Ensure the node is inside the parent rect
				l_position.x = clamp(l_position.x, 0, _parent_node.size.x - size.x)
				l_position.y = clamp(l_position.y, 0, _parent_node.size.y - size.y)
			
			# Set the new position of the node now
			position = l_position
			# Update the previous position accordingly
			_previous_position = position
			
			# Handle the magnetism if applicable
			_handle_helpers()
			
			# Compute the position offsets
			_compute_offsets()
			
			# Update the Controls
			Signals.components_resizable_node_is_resized_or_moved.emit(self)
		# If we are resizing the node in any direction
		elif is_resized:
			#debug("Resizing...")
			# Reset the minimum size so we can resize the node easilly
			custom_minimum_size = Vector2i.ZERO
			
			# Used to compute the node position
			var l_position : Vector2i = _previous_position
			# Used to compute the node size
			var l_size : Vector2i = _previous_size
			
			# The simple cases
			if is_right_resized:
				l_size.x += int(l_mouse_motion.relative.x)
				
				# If the node is not allowed outside the parent rect
				if not is_allowed_outside_parent_rect:
					# Ensure the new value is not outside the parent rect
					l_size.x = clamp(l_size.x, _minimum_width, int(_parent_node.size.x) - l_position.x)
			elif is_bottom_resized:
				l_size.y += int(l_mouse_motion.relative.y)
				
				# If the node is not allowed outside the parent rect
				if not is_allowed_outside_parent_rect:
					l_size.y = clamp(l_size.y, _minimum_height, int(_parent_node.size.y) - l_position.y)
			elif is_bottom_right_resized:
				l_size.x += int(l_mouse_motion.relative.x)
				l_size.y += int(l_mouse_motion.relative.y)
				
				# If the node is not allowed outside the parent rect
				if not is_allowed_outside_parent_rect:
					l_size.x = clamp(l_size.x, _minimum_width, int(_parent_node.size.x) - l_position.x)
					l_size.y = clamp(l_size.y, _minimum_height, int(_parent_node.size.y) - l_position.y)
			# The complex cases
			elif is_top_resized:
				l_position.y += int(l_mouse_motion.relative.y)
				l_size.y += -int(l_mouse_motion.relative.y)
				
				# If the height is smaller than the minimum height or if the position is outside the parent rect and this is not allowed
				if l_size.y < _minimum_height or (l_position.y <= 0 and not is_allowed_outside_parent_rect):
					# Cancel the movement
					l_size.y = _previous_size.y
					l_position.y = _previous_position.y
			elif is_left_resized:
				l_position.x += int(l_mouse_motion.relative.x)
				l_size.x += -int(l_mouse_motion.relative.x)
				
				# If the width is smaller than the minimum width or if the position is outside the parent rect and this is not allowed
				if l_size.x < _minimum_width or (l_position.x <= 0 and not is_allowed_outside_parent_rect):
					# Cancel the movement
					l_size.x = _previous_size.x
					l_position.x = _previous_position.x
			elif is_top_left_resized:
				l_position.y += int(l_mouse_motion.relative.y)
				l_size.y += -int(l_mouse_motion.relative.y)
				l_position.x += int(l_mouse_motion.relative.x)
				l_size.x += -int(l_mouse_motion.relative.x)
				
				# If the width is smaller than the minimum width or if the position is outside the parent rect and this is not allowed
				if l_size.x < _minimum_width or (l_position.x <= 0 and not is_allowed_outside_parent_rect):
					# Cancel the movement
					l_size.x = _previous_size.x
					l_position.x = _previous_position.x
				
				# If the height is smaller than the minimum height or if the position is outside the parent rect and this is not allowed
				if l_size.y < _minimum_height or (l_position.y <= 0 and not is_allowed_outside_parent_rect):
					# Cancel the movement
					l_size.y = _previous_size.y
					l_position.y = _previous_position.y
			# The semi-complex cases
			elif is_top_right_resized:
				l_position.y += int(l_mouse_motion.relative.y)
				l_size.y += -int(l_mouse_motion.relative.y)
				l_size.x += int(l_mouse_motion.relative.x)
				
				# If the height is smaller than the minimum height or if the position is outside the parent rect and this is not allowed
				if l_size.y < _minimum_height or (l_position.y <= 0 and not is_allowed_outside_parent_rect):
					# Cancel the movement
					l_size.y = _previous_size.y
					l_position.y = _previous_position.y
				
				# If the node is not allowed outside the parent rect
				if not is_allowed_outside_parent_rect:
					# Ensure the node is not outside the parent rect
					l_size.x = clamp(l_size.x, _minimum_width, int(_parent_node.size.x) - l_position.x)
			elif is_bottom_left_resized:
				l_position.x += int(l_mouse_motion.relative.x)
				l_size.x += -int(l_mouse_motion.relative.x)
				l_size.y += int(l_mouse_motion.relative.y)
				
				# If the width is smaller than the minimum width or if the position is outside the parent rect and this is not allowed
				if l_size.x < _minimum_width or (l_position.x <= 0 and not is_allowed_outside_parent_rect):
					# Cancel the movement
					l_size.x = _previous_size.x
					l_position.x = _previous_position.x
				
				# If the node is not allowed outside the parent rect
				if not is_allowed_outside_parent_rect:
					l_size.y = clamp(l_size.y, l_size.y, int(_parent_node.size.y) - l_position.y)
			
			# Set the new position and size of the node now
			position = l_position
			size = l_size
			
			# Update the previous position and size accordingly
			_previous_position = position
			_previous_size = size
			
			# Handle the magnetism if applicable
			_handle_helpers()
			
			# Update the Controls
			Signals.components_resizable_node_is_resized_or_moved.emit(self)


# Methods used to avoid edition of multiple nodes at the same time
func _on_resizable_node_is_edited_signal(a_resizable_node : ResizableNode, a_is_edited : bool) -> void:
	# If the provided node is this one
	if a_resizable_node == self:
		# If we shouldn't be able to edit the node without the controls
		if helpers_only_editable_from_controls_panel:
			_mover_overlay.visible = a_is_edited and is_movable and ((editable_only and is_edited) or not editable_only)
			_handles_overlay.visible = a_is_edited and is_resizable and ((editable_only and is_edited) or not editable_only) \
			and (use_horizontal_resizing or use_vertical_resizing)
		else:
			_mover_overlay.visible = is_movable and ((editable_only and is_edited) or not editable_only)
			_handles_overlay.visible = is_resizable and ((editable_only and is_edited) or not editable_only) \
			and (use_horizontal_resizing or use_vertical_resizing)
		
		# If we are edited
		if a_is_edited:
			# Make the edited node more visible
			_styling.add_theme_stylebox_override("panel", _edited_stylebox)
		# If we are not edited
		else:
			# Restore the edited node normal visibility
			_styling.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		
		# We need to update the helper lines (show or hide them if any)
		queue_redraw()
		# We return now
		return
	
	# If the other node is edited
	if a_is_edited:
		# Unedit this one
		is_edited = false
		
		# If this node is selected
		#if is_selected:
			#debug("%s should be deselected" % [name])
			# Unselect the node
			#is_selected = false
		# Ensure the overlays style is reset
		_styling.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		# We need to update the helper lines (show or hide them if any)
		queue_redraw()
		
	# We need to avoid (or allow) this node edition if the provided node is edited or not anymore
	avoid_edition = a_is_edited


# Method called when the edit button is pressed
func _on_toggle_edit_event() -> void:
	#debug("Toggling %s node edited value (current = %s)" % [name, is_edited])
	
	# If the node is not already edited
	if not is_edited:
		# Set the edited flag according to the editable one (just in case we are not supposed to edit this node)
		is_edited = true
		
		# If we want the node to be above its siblings
		if bring_up_on_edition:
			# Ensure this node is above the others
			move_to_front()
		
		# If we use a Controls Panel and that panel is the default one
		if helpers_use_controls_panel and _controls_panel is ResizableNodeDefaultControlsPanel:
			# Ensure that the Controls Panel is above everything as well
			_controls_panel.move_to_front()
		
		# If we don't use the default control panel
		if not _controls_panel is ResizableNodeDefaultControlsPanel:
			# Ensure the Controls Panel is linked again (as it can be linked to another node)
			_controls_panel.link_to_node(self)
		
		# Produce the signal to avoid another node to be edited
		Signals.components_resizable_node_is_edited.emit(self, true)
		
		# If the controls panel is the default one
		if _controls_panel is ResizableNodeDefaultControlsPanel:
			# Show the controls panel as well
			_controls_panel.show()
		# If the controls panel is a custom one
		else:
			# Enable the default controls
			_controls_panel.enable()
		
		# Ensure the current size is matching the minimal counterpart
		custom_minimum_size = size
		
		# Fine tune the resizing capabilities
		if not use_horizontal_resizing:
			custom_minimum_size.x = 0
		
		if not use_vertical_resizing:
			custom_minimum_size.y = 0
		
		# Get the current node position and size values
		_last_position = position
		_last_size = custom_minimum_size
		
		# Set the previous ones as well
		_previous_position = position
		_previous_size = custom_minimum_size
		
		# Handle the magnetism if applicable
		_handle_helpers()
		
		# Compute the position offsets
		_compute_offsets()
		
		# Update the Controls
		Signals.components_resizable_node_is_resized_or_moved.emit(self)
		
		# Get the nodes sharing a border with this node
		#get_common_borders()
	# If the node is already edited
	else:
		# Set the edited flag to false
		is_edited = false
		
		# If the controls panel is the default one
		if _controls_panel is ResizableNodeDefaultControlsPanel:
			# Hide the controls panel now
			_controls_panel.hide()
		# If the controls panel is a custom one
		else:
			# Disable the default controls
			_controls_panel.disable()
		
		# Produce the signal to allow other nodes to be edited
		Signals.components_resizable_node_is_edited.emit(self, false)
	
	# Update the overlay now
	var l_visible : bool = not helpers_only_editable_from_controls_panel and ((editable_only and is_edited) or not editable_only)
	_mover_overlay.visible = is_movable and l_visible
	_handles_overlay.visible = is_resizable and l_visible
	#print("From control = %s, Edit only = %s, is_edited = %s -> %s" % [helpers_only_editable_from_controls_panel, editable_only, is_edited, overlays.visible])
	
	#debug("    %s node edited value is now = %s" % [name, is_edited])


# Method called when the top edit value is changed
func _on_top_value_submitted(a_value : String) -> void:
	# Used to handle the operators feature
	var l_add : bool = false
	var l_subtract : bool = false
	var l_negate : bool = false
	var l_multiply : bool = false
	var l_divide : bool = false
	
	# If the first character is a + sign
	if a_value[0] == "+":
		l_add = true
	# If the first character is a - sign
	elif a_value[0] == "-":
		# Here we check if there is not another - sign as we can have 2 different capabilities with this sign (subtracting or offsetting)
		if a_value[1] == "-":
			l_negate = true
		else:
			l_subtract = true
	# If the first character is a * sign
	elif a_value[0] == "*":
		l_multiply = true
	# If the first character is a / sign
	elif a_value[0] == "/":
		l_divide = true
	
	# If there is negate signs
	if l_negate:
		# Get rid of the sign now
		a_value = a_value.substr(2)
	# If there is a single operator
	elif l_add or l_subtract or l_multiply or l_divide:
		# Get rid of the sign now
		a_value = a_value.substr(1)
	
	# Ensure the new value string is a number
	if a_value.is_valid_int():
		# If we want to add the value to the current one
		if l_add:
			position.y += a_value.to_int()
		# If we want to subtract the value from the current one
		elif l_subtract:
			position.y -= a_value.to_int()
		# If we want to set a negative value
		elif l_negate:
			position.y = -a_value.to_int()
		# If we want to multiply the current value by the provided one
		elif l_multiply:
			position.y *= a_value.to_int()
		# If we want to divide the current value by the provided one
		elif l_divide:
			position.y = roundi(position.y / a_value.to_int())
		# If we provide a new value
		else:
			# Set the position of the node accordingly
			position.y = a_value.to_int()
		
		# If the node cannot be outside the parent rect
		if not is_allowed_outside_parent_rect:
			# Ensure the minimum top is provided
			position.y = min(max(int(position.y), 0), int(_parent_node.size.y - size.y))
		
		# Update the previous position and size accordingly
		_previous_position = position
		_previous_size = size
		
		# Handle the magnetism if applicable
		_handle_helpers()
		
		# Compute the position offsets
		_compute_offsets()
	
		# Update the Controls
		Signals.components_resizable_node_is_resized_or_moved.emit(self)


# Method called when the width edit value is changed
func _on_width_value_submitted(a_value : String) -> void:
	# Used to handle the operators feature
	var l_add : bool = false
	var l_subtract : bool = false
	var l_multiply : bool = false
	var l_divide : bool = false
	
	# If the first character is a + sign
	if a_value[0] == "+":
		l_add = true
	# If the first character is a - sign
	elif a_value[0] == "-":
		l_subtract = true
	# If the first character is a * sign
	elif a_value[0] == "*":
		l_multiply = true
	# If the first character is a / sign
	elif a_value[0] == "/":
		l_divide = true
	
	# If there an operator
	if l_add or l_subtract or l_multiply or l_divide:
		# Get rid of the sign now
		a_value = a_value.substr(1)
	
	# Ensure the new value string is a number
	if a_value.is_valid_int():
		# Ensure we can resize the node
		custom_minimum_size.x = 0
		
		# If we want to add the value to the current one
		if l_add:
			size.x += a_value.to_int()
		# If we want to subtract the value from the current one
		elif l_subtract:
			size.x -= a_value.to_int()
		# If we want to multiply the current value by the provided one
		elif l_multiply:
			size.x *= a_value.to_int()
		# If we want to divide the current value by the provided one
		elif l_divide:
			size.x = roundi(size.x / a_value.to_int())
		# If we provide a new value
		else:
			# Set the position of the node accordingly
			size.x = a_value.to_int()
		
		# Ensure the minimum width is provided
		size.x = max(size.x, _minimum_width)
		
		# If the node cannot be outside its parent rect
		if not is_allowed_outside_parent_rect:
			# Ensure the size is bound to the max possible
			size.x  = min(size.x, int(_parent_node.size.x) - int(position.x))
		
		# Update the previous position and size accordingly
		_previous_position = position
		_previous_size = size
		
		# Handle the magnetism if applicable
		_handle_helpers()
	
		# Compute the position offsets
		_compute_offsets()
		
		# Update the Controls
		Signals.components_resizable_node_is_resized_or_moved.emit(self)


func _ready() -> void:
	# Get the parent node to know if this is a container or not (as we cannot move nodes inside containers)
	_parent_node = get_parent_control()
	# Populate the needed nodes now
	# The overlay
	_overlays = %"Overlays"
	_styling = %"Styling"
	_mover_overlay = %"Mover Overlay"
	_mover_button = %"Mover Button"
	_mover_spacer = %"Mover Spacer"
	# The resizing handles
	_handles_overlay = %"Handles Overlay"
	_top_left_handle_button = %"Top Left Handle Button"
	_top_handle_button = %"Top Handle Button"
	_top_right_handle_button = %"Top Right Handle Button"
	_left_handle_button = %"Left Handle Button"
	_right_handle_button = %"Right Handle Button"
	_bottom_left_handle_button = %"Bottom Left Handle Button"
	_bottom_handle_button = %"Bottom Handle Button"
	_bottom_right_handle_button = %"Bottom Right Handle Button"
	# The controls container used to add the control panel inside if there is not enough room outside the node
	_controls_container = %"Controls Container"
	
	# If we want to use the controls panel
	if helpers_use_controls_panel:
		# If we didn't provide a control panel
		if not _controls_panel:
			# Create the default control panel
			var l_controls_panel_scene : PackedScene = preload("Resizable Node Default Controls Panel.tscn")
			_controls_panel = l_controls_panel_scene.instantiate()
			# Link that panel to the ResizableNode now
			_controls_panel.link_to_node(self)
		else:
			# Link the provided panel to the ResizableNode
			_controls_panel.link_to_node(self)
			# Disable the default controls
			_controls_panel.disable()
	
	# Set the move flag according to the node's parent type
	_can_move = not _parent_node is Container
	
	# Create the handles list to ease the acces later
	_handles = [
		_top_left_handle_button,
		_top_handle_button,
		_top_right_handle_button,
		_left_handle_button,
		_right_handle_button,
		_bottom_left_handle_button,
		_bottom_handle_button,
		_bottom_right_handle_button,
	]
	
	# Connect the needed signals to the proper methods to avoid edition of multiple nodes at the same time
	Signals.components_resizable_node_is_edited.connect(_on_resizable_node_is_edited_signal)
	
	# If we don't specify a custom mover control
	if not _mover:
		# Get the default mover button instead
		_mover = _mover_button
		# Show the mover now
		_mover.show()
	# If we have specified a mover control
	else:
		# Ensure the default buton is hidden
		_mover_button.hide()
	
	# If we don't have a special style for our edited node
	if not _edited_stylebox:
		var l_stylebox : StyleBox = preload("Resources/Edited Overlay.tres")
		# Load the default stylebox theme
		_edited_stylebox = l_stylebox.duplicate()
	
	# Link the move button to the desired method
	_mover.gui_input.connect(_on_overlay_controls_input.bind(_mover))
	
	# Link all the grips to the corresponding methods
	_top_left_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_top_left_handle_button))
	_top_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_top_handle_button))
	_top_right_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_top_right_handle_button))
	_left_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_left_handle_button))
	_right_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_right_handle_button))
	_bottom_left_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_bottom_left_handle_button))
	_bottom_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_bottom_handle_button))
	_bottom_right_handle_button.gui_input.connect(_on_overlay_controls_input.bind(_bottom_right_handle_button))
	
	# Used to redraw the helper lines when the application is resized
	Signals.application_update_interface_disposition.connect(_on_application_update_interface_disposition)
	
	# Get the position / size of the node now (relative to its container)
	_last_position = Vector2i(position)
	_last_size = Vector2i(size)
	# Set the previous ones as well
	_previous_position = _last_position
	_previous_size = _last_size
	
	# Make sure the overlays are on top of everything in the parent node
	_overlays.move_to_front()
	
	# Indicate the node is ready now
	_is_ready = true
	
	# Update all the aspects of the node
	_update_mover_visibility()
	_update_handles_size()
	_update_handles_style()
	_update_handles_visibility()


func _set_editable_only(a_value : bool) -> void:
	editable_only = a_value
	
	if _is_ready:
		var l_visible : bool = not helpers_only_editable_from_controls_panel and ((editable_only and is_edited) or not editable_only)
		_mover_overlay.visible = is_movable and l_visible
		_handles_overlay.visible = is_resizable and l_visible

func _set_handles_color(a_color : Color) -> void:
	handles_color = a_color
	
	if _is_ready:
		_update_handles_style()


func _set_handles_size(a_value : int) -> void:
	handles_size = a_value
	
	if _is_ready:
		_update_handles_size()


# a_stylebox can be null or a StyleBox
func _set_helpers_edited_stylebox(a_stylebox : Variant) -> void:
	if a_stylebox and a_stylebox is StyleBox:
		_edited_stylebox = a_stylebox
	else:
		# Create the default control panel
		var l_stylebox : StyleBox = preload("Resources/Edited Overlay.tres")
		_edited_stylebox = l_stylebox.duplicate()


# a_control can be null, a ResizableNodeBasicControls or a PackedScene derived from the ResizableNodeBasicControls class
func _set_helpers_controls_panel(a_control : Variant) -> void:
	if a_control and a_control is ResizableNodeBasicControls:
		_controls_panel = a_control
	else:
		# Create the default control panel
		var l_controls_panel_scene : PackedScene = preload("Resizable Node Default Controls Panel.tscn")
		_controls_panel = l_controls_panel_scene.instantiate()
		
	# Only if the node is ready
	if _is_ready:
		# Link that panel to the ResizableNode now
		_controls_panel.link_to_node(self)


# Method used to set the corresponding flag
func _set_is_allowed_outside_parent_rect(a_value : bool) -> void:
	is_allowed_outside_parent_rect = a_value
	
	# TODO: move the node inside the parent if false and the node is already outside


func _set_is_movable(a_value : bool) -> void:
	is_movable = a_value and can_move
	
	if _is_ready:
		_update_mover_visibility()


func _set_is_resizable(a_value : bool) -> void:
	is_resizable = a_value
	
	if _is_ready:
		_update_handles_visibility()


func _set_mover_control(a_control : Variant) -> void:
	if a_control and a_control is Control:
		_mover = a_control
		
		if _is_ready:
			# Hide the default mover button now
			_mover_button.hide()
	else:
		_mover = _mover_button
		
		if _is_ready:
			# Ensure this button is shown then
			_mover.show()


func _set_mover_size(a_value : int) -> void:
	mover_size = a_value
	
	if _is_ready:
		_update_mover_visibility()


func _set_use_horizontal_resizing(a_value : bool) -> void:
	use_horizontal_resizing = a_value
	
	if _is_ready:
		_update_handles_visibility()


func _set_use_vertical_resizing(a_value : bool) -> void:
	use_vertical_resizing = a_value
	
	if _is_ready:
		_update_handles_visibility()


# Method used to update the handles visual according to the configuration
func _update_handles_size() -> void:
	_update_minimum_size()
	
	# For each handle
	for l_handle : Button in _handles:
		# Reset the custom minimum size for that handle first
		l_handle.custom_minimum_size = Vector2i.ZERO
		
		# If the handle is at the top or bottom
		if l_handle.name.contains("Top") or l_handle.name.contains("Bottom"):
			# Set the minimum height to the desized size
			l_handle.custom_minimum_size.y = handles_size
		
		# If the handle is at the left or right
		if l_handle.name.contains("Left") or l_handle.name.contains("Right"):
			# Set the minimum width to the desized size
			l_handle.custom_minimum_size.x = handles_size


func _update_handles_style() -> void:
	# For each handle
	for l_handle : Button in _handles:
		# Get the styleboxes for the hover and pressed states (using duplicates to avoid modifying all the nodes)
		var l_hover_style : StyleBoxFlat = l_handle.get_theme_stylebox("hover").duplicate()
		var l_pressed_style : StyleBoxFlat = l_handle.get_theme_stylebox("pressed").duplicate()
		
		# Change the background color to the desired one
		l_hover_style.bg_color = handles_color
		l_pressed_style.bg_color = handles_color
		
		# Replace the styleboxes now
		l_handle.add_theme_stylebox_override("hover", l_hover_style)
		l_handle.add_theme_stylebox_override("pressed", l_pressed_style)


func _update_handles_visibility() -> void:
	_handles_overlay.visible = is_resizable and not helpers_only_editable_from_controls_panel and ((editable_only and is_edited) or not editable_only) and (use_horizontal_resizing or use_vertical_resizing)
	
	if _handles_overlay.visible:
		_top_left_handle_button.visible = use_horizontal_resizing and use_vertical_resizing
		_top_handle_button.visible = use_vertical_resizing
		_top_right_handle_button.visible = use_horizontal_resizing and use_vertical_resizing
		_left_handle_button.visible = use_horizontal_resizing
		_right_handle_button.visible = use_horizontal_resizing
		_bottom_left_handle_button.visible = use_horizontal_resizing and use_vertical_resizing
		_bottom_handle_button.visible = use_vertical_resizing
		_bottom_right_handle_button.visible = use_horizontal_resizing and use_vertical_resizing
	
	# If the horizontal resize is not used, ensure the minimum node width is reset
	if not use_horizontal_resizing:
		custom_minimum_size.x = 0
	
	# If the vertical resize is not used, ensure the minimum node height is reset
	if not use_vertical_resizing:
		custom_minimum_size.y = 0


# Method used to update the minimum size of the node
func _update_minimum_size() -> void:
	# Compute the smallest minimum size for the node, according to flags
	_minimum_width = handles_size * 2
	_minimum_height = max(handles_size * 2, mover_size if is_movable else 0)
	# Used to skip unwanted nodes
	var l_index : int = 0
	
	# Get the first child of the node
	var l_content : Node = get_child(l_index)
	
	# Ensure the node is not a CanvasLayer (used for blur effect)
	if l_content is CanvasLayer:
		l_index += 1
		l_content = get_child(l_index)
	
	# Ensure the node is not a SelectableNode (used for selection purpose)
	if l_content is SelectableNode:
		l_index += 1
		l_content = get_child(l_index)
	
	# Only if the found node is not the overlays
	if l_content != _overlays and l_content.visible:
		# Update this minimum size for the node, according to the node's content
		_minimum_width = max(_minimum_width, l_content.size.x)
		_minimum_height = max(_minimum_height, l_content.size.y)
	
	#debug("%s minimum size = %s x %s" % [name, _minimum_width, _minimum_height])


func _update_mover_visibility() -> void:
	# Do we want the node to be movable (if it can be moved)
	_mover_overlay.visible = is_movable and not helpers_only_editable_from_controls_panel and ((editable_only and is_edited) or not editable_only)
	#_update_minimum_size()
	
	# If we use the mover
	if _mover_overlay.visible:
		# Update the mover button size
		_mover_button.custom_minimum_size.y = mover_size
		
		# If the mover button size is not specified
		if _mover_button.custom_minimum_size.y == 0:
			# Hide the mover spacer
			_mover_spacer.hide()
			# Make the mover button to take all the vertical space
			_mover_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# If some size has been provided
		else:
			# Show the mover spacer
			_mover_spacer.show()
			# Make the mover button to take only the desired space
			_mover_button.size_flags_vertical = Control.SIZE_FILL


# Method used to update the resizing flags according to the dragged grip (if any)
func _update_resizing_flags() -> void:
	# Set the flags according to the resizing grips states
	is_horizontally_resized = is_top_left_resized or is_top_right_resized or is_bottom_left_resized or is_bottom_right_resized \
	or is_left_resized or is_right_resized
	
	is_vertically_resized = is_top_left_resized or is_top_right_resized or is_bottom_left_resized or is_bottom_right_resized \
	or is_top_resized or is_bottom_resized
	
	is_resized = is_horizontally_resized or is_vertically_resized


#endregion
