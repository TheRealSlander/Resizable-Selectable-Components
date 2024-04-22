@icon("Icon_Container.svg")
class_name SelectionContainer extends Control

# A container used to allow dynamic selection of child nodes inside of it during runtime

#region CONSTANTS
# This defines how the nodes will be selected
const SELECTION_TYPE : Dictionary = {
	REPLACE = 1 << 0, # When a node is selected, all the other nodes in this container are unselected
	UPDATE = 1 << 1, # When a node is selected / unselected, it is updated in the selected nodes list accordingly
}

# The keyboard key used to unselect all the selected nodes of this container
const EVENT_CANCEL : int = KEY_ESCAPE
#endregion

#region EXPORTS
@export var allow_multiple_selections : bool = true ## If set to [code]true[/code], multiple [SelectableNodes] can be selected at the same time
@export var allow_partial_selections : bool = true ## If set to [code]true[/code], the node is considered selected even if it is partially included in the selection box[br][br]If set to [code]false[/code], the node has to be fully included in the selection box to be selected
@export var selection_rectangle_style : StyleBox: ## The style of the selection box (should be a translucent StyleBoxFlat)
	set = _set_selection_rectangle_style
#endregion

#region TREE NODES
# The overlay used to draw the selection box
@onready var _selection_overlay : Control = %"Selection Overlay"
#endregion

#region PRIVATE VARIABLES
# The list of the selected nodes in that selection container
var _selected_nodes : Array[SelectableNode]
# The group of ResizableNodes if the selected ones are ResizableNodes (used to be able to move multiple nodes at once)
var _resizable_group : ResizableNodeGroup
# Used to close the selection box when releasing the mouse button outside the application window
var _is_pressed : bool = false
#endregion


#region METHODS
# Used to add a node to the selection list. Nodes can be added using the Ctrl + Left Click combination
func _add_node_to_selection(a_node : SelectableNode) -> void:
	# Select the node
	a_node.is_selected = true
	# Add this node to the selected nodes list
	_selected_nodes.append(a_node)
	
	# Special case where the node is a ResizableNode
	if a_node._parent_node is ResizableNode:
		# Add it to the corresponding group
		_resizable_group.register(a_node._parent_node)


# Used to create the default stylebox of the selection
func _create_selection_default_style() -> void:
	var l_stylebox : StyleBox = preload("Resources/Selection Rectangle.tres")
	# We use duplicate() to make this stylebox unique
	_selection_overlay._selection_stylebox = l_stylebox.duplicate()


# Called when an input event is triggered above the selection container
func _input(a_event : InputEvent) -> void:
	# Ignore the event if the node is not visible
	if not is_visible_in_tree():
		return
	
	# If the events are blocked for this node
	if Utils.events_are_blocked(self):
		# Ignore this event
		return
	
	# Get the event as a key one or null
	var l_key_event : InputEventKey = a_event as InputEventKey
	
	# If the event exists
	if l_key_event:
		#debug("Key event triggered for %s (edited = %s)!" % [name, is_edited])
		# Depending on the key
		if l_key_event.keycode == EVENT_CANCEL:
			#debug("Cancel event triggered for %s!" % [name])
			_on_cancel_event()
			
			# Indicate we handled the input event
			get_viewport().set_input_as_handled()
	
	# Get the event as a mouse button one or null
	var l_mouse_button : InputEventMouseButton = a_event as InputEventMouseButton
	
	# If the event exists
	if l_mouse_button and l_mouse_button.button_index == MOUSE_BUTTON_LEFT:
		# If the click is over this node
		if get_global_rect().has_point(l_mouse_button.global_position):
			#print("Selection Container Node Input")
			
			# If the button is pressed
			if l_mouse_button.pressed:
				# Indicate we clicked in this node
				_is_pressed = true
				# Initialize the selection box
				_selection_overlay._selection_starting_point = l_mouse_button.global_position
				_selection_overlay._selection_rect = Rect2i()
				
				# Ensure the selection overlay is on top of everything
				_selection_overlay.move_to_front()
			# If the button is released
			else:
				# Ignore if we were not pressed
				if not _is_pressed:
					return
				
				# Indicate we are not pressed anymore
				_is_pressed = false
				
				# If we have a selection box
				if _selection_overlay._selection_rect != Rect2i():
					# Get all the selectable nodes in this container
					var l_nodes : Array[Node] = get_tree().get_nodes_in_group("Selectable Nodes")
					# Clear the selected nodes list
					_selected_nodes.clear()
					_resizable_group.clear()
					
					# For each SelectableNode in the list
					for l_node : SelectableNode in l_nodes:
						#print("%s is selected = %s" % [l_node.name, l_node.is_selected])
						# Ignore if the node is not visible
						if not l_node.is_visible_in_tree():
							continue
						
						# Check if the node is partially in the selection box
						if allow_partial_selections:
							# If the selection box intersect the node rect
							if Utils.rects_intersect(l_node.get_global_rect(), _selection_overlay._selection_rect):
								_add_node_to_selection(l_node)
							# If the node is not in the selection box at all
							else:
								l_node.is_selected = false
						# Check if the node is fully in the selection box
						else:
							# If the selection box contains the node rect
							if Utils.rect_contains_rect(_selection_overlay._selection_rect, l_node.get_global_rect()):
								_add_node_to_selection(l_node)
							# If the node is not in the selection box at all
							else:
								l_node.is_selected = false
				# If we don't have a selection box yet (this was a simple click mostly)
				else:
					# If we have some selected nodes
					if not _selected_nodes.is_empty():
						# Used to know if the click is above a selectable node
						var l_not_above_one : bool = true
						
						# For each selectable node in the list
						for l_node : SelectableNode in _selected_nodes:
							# If the release is performed above this node
							if l_node.get_global_rect().has_point(l_mouse_button.global_position):
								l_not_above_one = false
								break
						
						# If the click was not above one of the selected nodes
						if l_not_above_one:
							_on_cancel_event()
				
				# Stop the selection box drawing anyway
				_selection_overlay._selection_starting_point = Vector2i(-1, -1)
				_selection_overlay._selection_rect = Rect2i()
				# Remove the selection box now
				_selection_overlay.queue_redraw()
		# If we release the mouse button outside the node
		elif _is_pressed:
			# Indicate we are not clicked anymore
			_is_pressed = false
			_on_cancel_event()
			
			# Stop the selection box drawing anyway
			_selection_overlay._selection_starting_point = Vector2i(-1, -1)
			_selection_overlay._selection_rect = Rect2i()
			# Remove the selection box now
			_selection_overlay.queue_redraw()
	
	# Get the event as a mouse motion one or null
	var l_mouse_move : InputEventMouseMotion = a_event as InputEventMouseMotion
	
	# If the event exists and we started a selection box
	if l_mouse_move and _selection_overlay._selection_starting_point != Vector2i(-1, -1):
		# Get the rect origin
		var l_origin : Vector2i = _selection_overlay._selection_starting_point
		# Compute the selection rectangle dimensions
		var l_size : Vector2i = Vector2i(
			int(l_mouse_move.global_position.x - l_origin.x),
			int(l_mouse_move.global_position.y - l_origin.y),
		)
		
		# If the size is lesser than 0 (which means that we moved the mouse to the left or to the top of the initial point)
		if l_size.x < 0:
			# Exchange the points for the rect boundaries
			l_origin.x = int(l_mouse_move.global_position.x)
		
		if l_size.y < 0:
			# Exchange the points for the rect boundaries
			l_origin.y = int(l_mouse_move.global_position.y)
		
		# Ensure the size is positive or null
		l_size.x = abs(l_size.x)
		l_size.y = abs(l_size.y)
		
		# Store the selection rect in the overlay now to draw the rectangle there
		_selection_overlay._selection_rect = Rect2i(l_origin, l_size)


func _on_cancel_event() -> void:
	#print("Cancelling all selections (%s)" % [_selected_nodes])
	# For each node in the list
	for l_node : SelectableNode in _selected_nodes:
		l_node.is_selected = false
	
	# Clear the lists now
	_selected_nodes.clear()
	_resizable_group.clear()


# Triggered when a SelectableNode is selected
func _on_selectable_node_is_selected_signal(a_selectable_node : SelectableNode, a_is_selected : bool, a_selection_type : int) -> void:
	# If we allow multiple selections
	if allow_multiple_selections:
		# According to the selection type
		match a_selection_type:
			# If the provided node should replace all the others
			SELECTION_TYPE.REPLACE:
				# For each node in the list
				for l_node : SelectableNode in _selected_nodes:
					# If this is the target node
					if l_node == a_selectable_node:
						# Ignore it
						continue
					
					# Unselect that node
					l_node.is_selected = false
				
				# Clear the lists
				_selected_nodes.clear()
				_resizable_group.clear()
				
				_add_node_to_selection(a_selectable_node)
			
			# If the provided node is an update to the list
			SELECTION_TYPE.UPDATE:
				# If we want to add the provided node to the list
				if a_is_selected:
					# Add the provided node to the list
					_add_node_to_selection(a_selectable_node)
				# If we want to remove the provided node from the list
				else:
					# Remove the provided node from the list
					_remove_node_from_selection(a_selectable_node)
	# If we only allow 1 selection at a time
	else:
		# For each node in the list
		for l_node : SelectableNode in _selected_nodes:
			# If this is the target node
			if l_node == a_selectable_node:
				# Ignore it
				continue
			
			# Unselect that node
			l_node.is_selected = false
		
		# Clear the lists
		_selected_nodes.clear()
		_resizable_group.clear()
		
		_add_node_to_selection(a_selectable_node)


func _ready() -> void:
	# Ensure the selection overlay is on top of everything
	_selection_overlay.move_to_front()
	
	# Create the ResizableNodes group
	_resizable_group = ResizableNodeGroup.new()
	
	# Connect the needed signals to the proper methods to avoid selection of multiple nodes at the same time
	Signals.components_selectable_node_is_selected.connect(_on_selectable_node_is_selected_signal)
	
	# If we dont have a stylebox defined for the selection box
	if not _selection_overlay._selection_stylebox:
		# Create the default stylebox
		_create_selection_default_style()


func _remove_node_from_selection(a_node : SelectableNode) -> void:
	# Try to find the node in the list first
	var l_index : int = _selected_nodes.find(a_node)
	
	# Ensure the node is in the list if we want to unselect it (should never trigger)
	if not l_index > -1:
		printerr("ERROR: Trying to remove an unknown selected node from the list!")
		return
	
	# Ensure it is unselected
	a_node.is_selected = false
	# Remove this node from the selected nodes list
	_selected_nodes.remove_at(l_index)
	
	# If the node is a ResizableNode
	if a_node._parent_node is ResizableNode:
		# Remove it from the corresponding group
		_resizable_group.unregister(a_node._parent_node)


# a_stylebox can be null or any StyleBox
func _set_selection_rectangle_style(a_stylebox : Variant) -> void:
	if a_stylebox and a_stylebox is StyleBox:
		_selection_overlay._selection_stylebox = a_stylebox
	# If the provided stylebox is null
	else:
		# Create the default stylebox
		_create_selection_default_style()
#endregion
