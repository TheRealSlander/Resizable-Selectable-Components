class_name ResizableNodeBasicControls extends Control

# The basic class for the ResizableNode Controls
# This class provides the minimum required nodes to control the ResizableNode properties
# When designing a panel, we MUST have the 6 following controls:
# - 4 LineEdits with names %"Left Edit", %"Top Edit", %"Width Edit" and %"Height Edit"
# - 2 Buttons with names %"Snapping Button" and %"Free Button"
#
# ATTENTION: These controls MUST use the Unique Name feature!

#region TREE NODES
# The position edits
var _left_edit : LineEdit
var _top_edit : LineEdit
# The size edits
var _width_edit : LineEdit
var _height_edit : LineEdit
# The snapping / free buttons
var _snapping_button : Button
var _free_button : Button
#endregion

#region LINK TO THE ResizableNode
# The linked ResizableNode (must be set in the ResizableNode itself using the link_to_node() method)
var _linked_node : ResizableNode
# The parent node of the linked ResizableNode
var _linked_node_parent : Control
#endregion


#region METHODS
# Method used to ensure the focused edit is released
func clear_focus() -> void:
	_left_edit.release_focus()
	_top_edit.release_focus()
	_width_edit.release_focus()
	_height_edit.release_focus()
	_free_button.release_focus()
	_snapping_button.release_focus()


# Method used to disable the edit fields and buttons
func disable() -> void:
	# Make the nodes uneditable
	_left_edit.editable = false
	_top_edit.editable = false
	_width_edit.editable = false
	_height_edit.editable = false
	# Make the nodes unfocusable as well
	_left_edit.focus_mode = FOCUS_NONE
	_top_edit.focus_mode = FOCUS_NONE
	_width_edit.focus_mode = FOCUS_NONE
	_height_edit.focus_mode = FOCUS_NONE
	# Remove the values from the edits to clean things up
	_left_edit.clear()
	_top_edit.clear()
	_width_edit.clear()
	_height_edit.clear()
	# Disable the buttons now
	_free_button.disabled = true
	_snapping_button.disabled = true
	#print("Disabling controller")


# Method used to enable the edit fields and buttons
func enable() -> void:
	# Make the nodes editable
	_left_edit.editable = true
	_top_edit.editable = true
	_width_edit.editable = true
	_height_edit.editable = true
	# Make the nodes focusable as well
	_left_edit.focus_mode = FOCUS_ALL
	_top_edit.focus_mode = FOCUS_ALL
	_width_edit.focus_mode = FOCUS_ALL
	_height_edit.focus_mode = FOCUS_ALL
	# Enable the buttons now
	_free_button.disabled = false
	_snapping_button.disabled = false
	#print("Enabling controller")


# Method used to ensure the provided value is in a valid format
# Rules are:
# - Not be longuer than 5 or 6 characters (handled by the LineEdit itself)
# - Only contains numerical characters and operators (-, +, *, /)
# - Operator is only the first character (cannot have an operator elsewhere)
# - Can have a double hyphen (--) if the string is a negate one
func is_valid_value(a_value : String, a_can_negate : bool = false, a_ignore_empty : bool = false) -> bool:
	# If we want to ignore an empty provided string
	if a_ignore_empty and a_value.is_empty():
		# Quit without error
		return true
	
	# Used to avoid a bug with the double hyphen (--) case
	var l_negate_is_treated : bool = false
	
	# The characters which are allowed in the string is before the @ symbol, after it is the domain)string
	for l_operator : String in ["--", "-", "+", "*", "/"]:
		# Get the index of the first occurence of the operators (if any)
		var l_operator_index : int = a_value.find(l_operator)
		var l_operator_count : int = 0
		var l_cleaned_value : String = a_value
		
		# First we check if we can have a negate operator if we found one
		if l_operator == "--" and l_operator_index > -1 and not a_can_negate:
			# Indicate the provided string is not legit
			return false
		
		# As long as we have this operator in the string
		while l_operator_index > -1:
			# Indicate we have found 1 operator of this kind
			l_operator_count += 1
			# Remove the operator from the string
			l_cleaned_value = l_cleaned_value.substr(l_operator_index + 1)
			# Look for another occurence of the operator
			l_operator_index = l_cleaned_value.find(l_operator)
			
			# If the next occurence is not at the beggining of the string
			if l_operator_index > 0:
				# Indicate the provided string is not legit
				return false
		
		# If the current operator is the hyphen (-)
		if l_operator == "-":
			# If we have more than 2 occurences of this character
			if l_operator_count > 2:
				# Indicate the provided string is not legit
				return false
			# If there is more than 1 hyphen (-) and we don't have already treated the double hyphen case (meaning the hyphens are separated by 1 or more characters)
			elif l_operator_count > 1 and not l_negate_is_treated:
				# Indicate the provided string is not legit
				return false
		# If we have more than 1 occurence of the operator
		elif l_operator_count > 1:
			# Indicate the provided string is not legit
			return false
		
		# If the negate operator is legit
		if l_operator == "--":
			# Indicate we handled it
			l_negate_is_treated = true
	
	# Set the operators and digits to the allowed characters
	var l_allowed_chars : PackedStringArray = ["-", "+", "*", "/"]
	l_allowed_chars.append_array(Utils.DIGITS)
	
	# Check each character of the password
	for l_char in a_value:
		# Do we have an allowed character there
		var l_char_is_allowed : bool = false
		
		# Compare it to the allowed ones
		for l_allowed_char in l_allowed_chars:
			# If the compared characters match
			if l_char == l_allowed_char:
				# We have found a matching allowed character
				l_char_is_allowed = true
				# Continue with the next character
				break
			
		# If we have found an allowed character
		if l_char_is_allowed:
			# Get to the next character
			continue
			
		# If we reach there, indicate there is a problem as the character is not in the allowed list
		return false
	
	return true


# Method used to link this node with a resizable node and its parent (which should be a non-container Control derived node)
func link_to_node(a_resizable_node : ResizableNode) -> void:
	# Store the linked node
	_linked_node = a_resizable_node
	# And its parent
	_linked_node_parent = _linked_node._parent_node
	
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
	
	# Update the snapping buttons as well
	if a_resizable_node.use_snapping:
		# Hide the snapping button now and show the free one instead
		_snapping_button.hide()
		_free_button.show()
	else:
		# Hide the free button now and show the snapping one instead
		_free_button.hide()
		_snapping_button.show()


# Method called when the free button is pressed
func _on_free_button_pressed() -> void:
	# Call the linked node method as well
	_linked_node.use_snapping = false
	# Hide this button now and show the snapping one instead
	_free_button.hide()
	_snapping_button.show()
	# Ensure the snapping button is focused now
	_snapping_button.grab_focus()


# Method called when the height value edit is focused
func _on_height_value_focused() -> void:
	# Select all the text
	_height_edit.select_all.call_deferred()


# Method called when the height value edit text is submitted
func _on_height_value_submitted(a_value : String) -> void:
	# Ensure the provided value is legit first
	if not is_valid_value(a_value):
		# TODO: Change the text color to indicate there is a problem?
		# Restore the last legit value
		_height_edit.text = "%s" % [_linked_node.size.y]
		# Exit the method now
		return
	
	# Call the linked node method as well
	_linked_node._on_height_value_submitted(a_value)
	# Ensure the text is now selected
	_height_edit.select_all()


# Method called when the left value edit is focused
func _on_left_value_focused() -> void:
	# Select all the text
	_left_edit.select_all.call_deferred()


# Method called when the left value edit text is submitted
func _on_left_value_submitted(a_value : String) -> void:
	# Ensure the provided value is legit first
	if not is_valid_value(a_value, true):
		# TODO: Change the text color to indicate there is a problem?
		# Restore the last legit value
		_left_edit.text = "%s" % [_linked_node.position.x]
		# Exit the method now
		return
	
	# Call the linked node method as well
	_linked_node._on_left_value_submitted(a_value)
	# Ensure the text is now selected
	_left_edit.select_all()


# Method called when a resizable node is resized
func _on_resizable_node_is_resized_or_moved_signal(a_resizable_node : ResizableNode) -> void:
	# Ensure the needed nodes are set properly first
	if _linked_node == null or _linked_node_parent == null:
		printerr("_on_resizable_node_is_resized_or_moved_signal(): Both linked node and linked node parent must be set in the resizable node first!")
		return
	
	# Only if the provided node is this node
	if a_resizable_node == _linked_node:
		# At last, update the labels according to the linked node position / size
		_left_edit.text = "%s" % [_linked_node.position.x]
		_top_edit.text = "%s" % [_linked_node.position.y]
		_width_edit.text = "%s" % [_linked_node.size.x]
		_height_edit.text = "%s" % [_linked_node.size.y]


# Method called when the snapping button is pressed
func _on_snapping_button_pressed() -> void:
	# Call the linked node method as well
	_linked_node.use_snapping = true
	# Hide this button now and show the free one instead
	_snapping_button.hide()
	_free_button.show()
	# Ensure the free button is focused now
	_free_button.grab_focus()


# Method called when the top value edit is focused
func _on_top_value_focused() -> void:
	# Select all the text
	_top_edit.select_all.call_deferred()


# Method called when the top value edit text is submitted
func _on_top_value_submitted(a_value : String) -> void:
	# Ensure the provided value is legit first
	if not is_valid_value(a_value, true):
		# TODO: Change the text color to indicate there is a problem?
		# Restore the last legit value
		_top_edit.text = "%s" % [_linked_node.position.y]
		# Exit the method now
		return
	
	# Call the linked node method as well
	_linked_node._on_top_value_submitted(a_value)
	# Ensure the text is now selected
	_top_edit.select_all()


# Method called when the width value edit is focused
func _on_width_value_focused() -> void:
	# Select all the text
	_width_edit.select_all.call_deferred()


# Method called when the width value edit text is submitted
func _on_width_value_submitted(a_value : String) -> void:
	# Ensure the provided value is legit first
	if not is_valid_value(a_value):
		# TODO: Change the text color to indicate there is a problem?
		# Restore the last legit value
		_width_edit.text = "%s" % [_linked_node.size.x]
		# Exit the method now
		return
	
	# Call the linked node method as well
	_linked_node._on_width_value_submitted(a_value)
	# Ensure the text is now selected
	_width_edit.select_all()


# Method called when the node is ready
func _ready() -> void:
	# Get the needed nodes
	_left_edit = %"Left Edit"
	_top_edit = %"Top Edit"
	_width_edit = %"Width Edit"
	_height_edit = %"Height Edit"
	_snapping_button = %"Snapping Button"
	_free_button = %"Free Button"
	
	# Link the buttons signals to the corresponding methods
	_snapping_button.pressed.connect(_on_snapping_button_pressed)
	_free_button.pressed.connect(_on_free_button_pressed)
	
	# Connect the edit text changed methods to the corresponding signal
	_left_edit.text_submitted.connect(_on_left_value_submitted)
	_top_edit.text_submitted.connect(_on_top_value_submitted)
	_width_edit.text_submitted.connect(_on_width_value_submitted)
	_height_edit.text_submitted.connect(_on_height_value_submitted)
	# Connect the edit text focused methods to the corresponding signal
	_left_edit.focus_entered.connect(_on_left_value_focused)
	_top_edit.focus_entered.connect(_on_top_value_focused)
	_width_edit.focus_entered.connect(_on_width_value_focused)
	_height_edit.focus_entered.connect(_on_height_value_focused)
	
	# Connect the needed signals to the proper methods
	Signals.components_resizable_node_is_resized_or_moved.connect(_on_resizable_node_is_resized_or_moved_signal)


#endregion
