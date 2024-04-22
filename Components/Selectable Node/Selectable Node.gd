@icon("Icon_Node.svg")
class_name SelectableNode extends PanelContainer

# Class defining a selectable node. This node MUST be used inside a SelectionContainer node!

#region TREE NODES
@onready var _styling : PanelContainer = %"Styling"
#endregion

#region PUBLIC VARIABLES
# If the node is currently selected
var is_selected : bool = false:
	set = _set_is_selected
#endregion

#region PRIVATE VARIABLES
# Used to ensure this node was clicked before we release it (as it can be a release from a selection box which was not started over this node)
var _was_pressed : bool = false 
# The direct parent node (used to bring that node in front of the other nodes when selected)
var _parent_node : Control
# The selected stylebox style
var _selected_stylebox : StyleBox
#endregion


#region METHODS
# Called when an input event is triggered above the node
func _input(a_event : InputEvent) -> void:
	# Ignore the event if the node is not visible
	if not visible:
		return
	
	# If the events are blocked
	if Utils.events_are_blocked(self):
		#print("Selectable Node \"%s\" Input is blocked!" % [name])
		# Ignore this event
		return
	
	# Get the event as a mouse button one or null
	var l_mouse_event : InputEventMouseButton = a_event as InputEventMouseButton
	
	# If the event exists
	if l_mouse_event and l_mouse_event.button_index == MOUSE_BUTTON_LEFT:
		# If the click is over this node
		if get_global_rect().has_point(l_mouse_event.global_position):
			#print("Selectable Node \"%s\" Input" % [name])
			# If the button is pressed
			if l_mouse_event.pressed:
				# Indicate we initiated the click over this node
				_was_pressed = true
				
				# If the Ctrl key is also pressed
				if l_mouse_event.ctrl_pressed:
					# Ensure we cannot select another node right now
					Utils.block_events(self)
					is_selected = not is_selected
					Signals.components_selectable_node_is_selected.emit(self, is_selected, SelectionContainer.SELECTION_TYPE.UPDATE)
				# If we don't have Ctrl pressed
				else:
					# If this node is not already selected
					if not is_selected:
						# If the Alt key is not pressed (as we can have a ResizableNode below this node)
						if not l_mouse_event.alt_pressed:
							# Ensure we cannot select another node right now
							Utils.block_events(self)
						
						# Indicate this node is now selected
						is_selected = true
						Signals.components_selectable_node_is_selected.emit(self, is_selected, SelectionContainer.SELECTION_TYPE.REPLACE)
					# If the node is already selected
					else:
						# If we use this node directly inside a SelectionContainer
						if _parent_node is SelectionContainer:
							# Make this node to be in front of its siblings
							move_to_front() 
						# If we use this node inside another node which is not a SelectionContainer
						else:
							# Bring the parent node to front instead
							_parent_node.move_to_front()
			# If the button is released
			else:
				# Only if we initiated the click over this node
				if _was_pressed:
					# Ensure we cannot select another node right now
					Utils.block_events(self)
				
				_was_pressed = false


# Setter method for the is_selected flag
func _set_is_selected(a_value : bool) -> void:
	is_selected = a_value
	
	# Make sure the node is above the others if selected
	if is_selected:
		# If we use this node directly inside a SelectionContainer
		if _parent_node is SelectionContainer:
			# Make this node to be in front of its siblings
			move_to_front() 
		# If we use this node inside another node which is not a SelectionContainer
		else:
			# Bring the parent node to front instead
			_parent_node.move_to_front()
			
			# If the parent is a ResizableNode and is edited
			if _parent_node is ResizableNode and _parent_node.is_edited:
				# If the Controls Panel is the default node
				if _parent_node._controls_panel is ResizableNodeDefaultControlsPanel:
					# Ensure the Controls Panel is moved to front now
					_parent_node._controls_panel.move_to_front()
	
	#print("Node %s is now %s" % [name, "selected" if is_selected else "unselected"])
	_update_styling()


func _ready() -> void:
	# Get the parent node
	_parent_node = get_parent_control()
	
	# If we don't have a special style for our edited node
	if not _selected_stylebox:
		var l_stylebox : StyleBox = preload("Resources/Selected Overlay.tres")
		# Load the default stylebox theme
		_selected_stylebox = l_stylebox.duplicate()
	
	# Make sure the styling is on top of everything in the node
	_styling.move_to_front()


# Method used to draw the stylebox for the selected node (if applicable)
func _update_styling() -> void:
	# If we are selected
	if is_selected:
		# Make the edited node more visible
		_styling.add_theme_stylebox_override("panel", _selected_stylebox)
	# If we are not edited
	else:
		# Restore the edited node normal visibility
		_styling.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

#endregion
