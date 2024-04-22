class_name ResizableNodeDefaultControlsPanel extends ResizableNodeBasicControls

# The panel class used to edit the ResizableNode component

#region CONSTANTS
# The positions of the controls panel relative to the ResizableNode
const PLACEMENTS : Dictionary = {
	ABOVE = 1 << 0,
	LEFT = 1 << 1,
	BELOW = 1 << 2,
	RIGHT = 1 << 3,
	INSIDE = 1 << 4,
}

const MARGES : int = 4
#endregion

#region TREE NODES
# Get the needed parts
var _position_label : RichTextLabel
var _size_label : RichTextLabel
#endregion

#region PUBLIC VARIABLES
# Used to know if we can position this node freely around the linked node (or if we need to display it inside the linked node directly)
var must_be_incrusted : bool = false
#endregion


#region METHODS
# Method used to add the node as a child of another node, according to the context / space available
func _add_to_tree() -> void:
	# First we get the parent reference
	var l_parent : Control = get_parent()
	
	# If the node already has a parent
	if l_parent:
		# If the node must be inside the linked one
		if must_be_incrusted:
			# Only if the current parent is not already the expected one
			if l_parent != _linked_node._controls_container:
				# Update the node parent
				await get_tree().process_frame
				reparent(_linked_node._controls_container)
				
				_linked_node.controls_placement = PLACEMENTS.INSIDE
		# If the node can be outside the linked one
		else:
			# Only if the current parent is not already the expected one
			if l_parent != _linked_node_parent:
				# Add the node to the linked node parent
				await get_tree().process_frame
				reparent(_linked_node_parent)
	# If the node does not have a parent yet
	else:
		# If the node must be inside the linked one
		if must_be_incrusted:
			_linked_node._controls_container.add_child.call_deferred(self)
			_linked_node.controls_placement = PLACEMENTS.INSIDE
		# If the node can be outside the linked one
		else:
			_linked_node_parent.add_child.call_deferred(self)


func _input(a_event : InputEvent) -> void:
	# Ignore the event if the node is not visible
	if not is_visible_in_tree():
		return
	
	# Get the event as a mouse button one or null
	var l_mouse_event : InputEventMouseButton = a_event as InputEventMouseButton
	
	# Only if the event is a pressed left button click
	if l_mouse_event and l_mouse_event.button_index == MOUSE_BUTTON_LEFT and l_mouse_event.pressed:
		# If the click is above this node
		if get_global_rect().has_point(l_mouse_event.global_position):
			# Ensure we cannot select another node right now
			Utils.block_events(self)


# Method used to link this node with a resizable node and its parent (which should be a non-container Control derived node)
func link_to_node(a_resizable_node : ResizableNode) -> void:
	# Store the linked node
	_linked_node = a_resizable_node
	# And its parent
	_linked_node_parent = _linked_node._parent_node
	# Set a proper name
	name = "%s Edition Controls" % [_linked_node.name]
	
	# Used to indicate if we can position this node around the linked node or if we must add it inside the linked node instead
	must_be_incrusted = _linked_node_parent is Container
	
	# Add / move the node in the tree at the correct place
	_add_to_tree()


# Method called when a resizable node is resized
func _on_resizable_node_is_resized_or_moved_signal(a_resized_node : ResizableNode) -> void:
	# Ensure the needed nodes are set properly first
	if _linked_node == null or _linked_node_parent == null:
		printerr("_on_resizable_node_is_resized_or_moved_signal(): Both linked node and linked node parent must be set in the resizable node first!")
		return
	
	# All is fine
	# Now check if the calling node is the linked one
	if a_resized_node == _linked_node:
		# This is for us, do our job
		# Ensure the node is properly positioned
		_update_position()


# Method called when the node is ready
func _ready() -> void:
	# Get the added nodes
	_position_label = %"Position Label"
	_size_label = %"Size Label"
	
	# Call the inherited method now
	super()
	
	# Enable / disable the movable feature parts
	_left_edit.editable = _linked_node.is_movable
	_top_edit.editable = _linked_node.is_movable
	_left_edit.focus_mode = FOCUS_ALL if _linked_node.is_movable else FOCUS_NONE
	_top_edit.focus_mode = FOCUS_ALL if _linked_node.is_movable else FOCUS_NONE
	# Enable / disable the resizable feature parts
	_width_edit.editable = _linked_node.is_resizable and _linked_node.use_horizontal_resizing
	_height_edit.editable = _linked_node.is_resizable and _linked_node.use_vertical_resizing
	_width_edit.focus_mode = FOCUS_ALL if _linked_node.is_resizable and _linked_node.use_horizontal_resizing else FOCUS_NONE
	_height_edit.focus_mode = FOCUS_ALL if _linked_node.is_resizable and _linked_node.use_vertical_resizing else FOCUS_NONE
	
	# Set the initial node position
	_update_position()
	
	# Ensure we are not visible until desired
	hide()


# Method used to adjust the node position according to the linked node position in the linked parent one
func _update_position() -> void:
	# Ensure the needed nodes are set properly first
	if _linked_node == null or _linked_node_parent == null:
		printerr("_update_position(): Both linked node and linked node parent must be set in the resizable node first!")
		return
	
#	# If the linked node parent is a container (which means we cannot position / resize this node in it)
#	if linked_node_parent is Container:
#		error("_update_position(): Linked node parent is a container! Impossible to position the edition buttons!")
#		return
	
	# Add / move the node in the tree at the correct place
	_add_to_tree()
	
	# Only if the node is not forced to be inside the linked one
	if not must_be_incrusted:
		# Used to ensure the sizes are correct
		var l_final_width : int = int(size.x) + MARGES
		var l_final_height : int = int(size.y) + MARGES
		
		# If there is not enough space to put the panel above the linked node
		if _linked_node.position.y < l_final_height:
			# If there is not enough space on the left side of the linked node neither
			if _linked_node.position.x < l_final_width:
				# If there is not enough space on the right side of the linked node neither
				if _linked_node_parent.size.x - (_linked_node.position.x + _linked_node.size.x) < l_final_width:
					# If there is not enough space below the linked node at last
					if _linked_node_parent.size.y - (_linked_node.position.y + _linked_node.size.y) < l_final_height:
						# Put the panel inside the linked node (there should be enough space there!)
						#reparent.call_deferred(linked_node.controls_container)
						
						await get_tree().process_frame
						reparent(_linked_node._controls_container)
						
						_linked_node.controls_placement = PLACEMENTS.INSIDE
					# If there is enough space below the linked node
					else:
						# Put the panel below the linked node
						position.x = _linked_node.position.x
						position.y = _linked_node.position.y + _linked_node.size.y + MARGES
						_linked_node.controls_placement = PLACEMENTS.BELOW
				# If there is enough space on the right side of the linked node
				else:
					# Put the panel on the right side of the linked node (at the top of the node as well)
					position.x = _linked_node.position.x + _linked_node.size.x + MARGES
					position.y = _linked_node.position.y
					_linked_node.controls_placement = PLACEMENTS.RIGHT
			# If there is enough space on the left side of the linked node
			else:
				# Put the panel on the left side of the linked node (at the top of the node as well)
				position.x = _linked_node.position.x - l_final_width
				position.y = _linked_node.position.y
				_linked_node.controls_placement = PLACEMENTS.LEFT
		# If there is enough space above the linked node (default behaviour)
		else:
			# Put the panel above the linked node (at the left side of the node as well)
			position.x = _linked_node.position.x
			position.y = _linked_node.position.y - l_final_height
			_linked_node.controls_placement = PLACEMENTS.ABOVE
		
		# Only if the panel is above or below the linked node
		if _linked_node.controls_placement == PLACEMENTS.BELOW or _linked_node.controls_placement == PLACEMENTS.ABOVE:
			# If the panel width is larger than the linked node width and there is not enough space at the right of the linked node
			if size.x > _linked_node.size.x and (_linked_node_parent.size.x - _linked_node.position.x) < size.x:
				# Align the right side of the controls with the right side of the linked node
				position.x = _linked_node.position.x - (size.x - _linked_node.size.x)
		# Only if the panel is on the left or on the right of the linked node
		elif _linked_node.controls_placement == PLACEMENTS.LEFT or _linked_node.controls_placement == PLACEMENTS.RIGHT:
			# If the panel height is larger than the linked node height and there is not enough space at the bottom of the linked node
			if size.y > _linked_node.size.y and (_linked_node_parent.size.y - _linked_node.position.y) < size.y:
				# Align the bottom side of the controls with the bottom side of the linked node
				position.y = _linked_node.position.y - (size.y - _linked_node.size.y)
	
	# At last, update the labels according to the linked node position / size
	_left_edit.text = "%s" % [_linked_node.position.x]
	_top_edit.text = "%s" % [_linked_node.position.y]
	_width_edit.text = "%s" % [_linked_node.size.x]
	_height_edit.text = "%s" % [_linked_node.size.y]



#endregion
