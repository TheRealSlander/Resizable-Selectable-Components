class_name ResizableNodeGroup

## ResizableNodeGroup class used to create groups for the [ResizableNode] class
##
## It aims to create a group of nodes to be able to move them at once using the ResizableNode features (like magnetism and helpers)

#region PRIVATE VARIABLES
## The list of ResizableNodes in this group
var _nodes : Array[ResizableNode]
#endregion


#region METHODS
## Clears the nodes list
func clear() -> void:
	#print("Clearing ResizableNodes group")
	# For each node already registered
	for l_node : ResizableNode in _nodes:
		# Clear the stored group
		l_node.moving_group = null
	
	_nodes.clear()


## Returns the list of the registered nodes in that group
func get_nodes() -> Array[ResizableNode]:
	return _nodes


func _init() -> void:
	# Connect the special resizable node as well (as they can be moved at once if multiple selection is enabled)
	Signals.components_resizable_node_is_resized_or_moved.connect(_on_resizable_node_is_resized_or_moved_signal)


func _on_resizable_node_is_resized_or_moved_signal(a_resizable_node : ResizableNode) -> void:
	#print("Moving offsets = %s" % [a_resizable_node.position_offsets])
	# For each selected node in the list
	for l_node : ResizableNode in _nodes:
		# If the current node is the moved node, ignore
		if l_node == a_resizable_node:
			continue
		
		# Move the node according to the group leader
		l_node.position += Vector2(a_resizable_node.position_offsets)
		
		# If the node should not be outside the parent
		if not l_node.is_allowed_outside_parent_rect:
			# Ensure the node is not outside the parent
			l_node.position.x = clamp(l_node.position.x, 0, l_node._parent_node.get_rect().end.x - l_node.size.x)
			l_node.position.y = clamp(l_node.position.y, 0, l_node._parent_node.get_rect().end.y - l_node.size.y)


## Method used to register a node to this group (this is done directly from the [SelectableContainer] class when selecting multiple nodes)
func register(a_node : ResizableNode) -> void:
	# If the provided node is not already in the list
	if not _nodes.has(a_node):
		#print("Node \"%s\" added to the ResizableNodes group" % [a_node.name])
		_nodes.append(a_node)
		# Store this group to the node itself (to be able to ignore the magnetism when moving nodes)
		a_node.moving_group = self


## Method used to unregister a node from this group (this is done directly from the [SelectableContainer] class when unselecting a node)
func unregister(a_node : ResizableNode) -> void:
	# If the provided node is indeed in the list
	if _nodes.has(a_node):
		# Remove it from the list
		#print("Node \"%s\" removed from the ResizableNodes group" % [a_node.name])
		_nodes.erase(a_node)
		# Clear the stored group
		a_node.moving_group = null
#endregion
