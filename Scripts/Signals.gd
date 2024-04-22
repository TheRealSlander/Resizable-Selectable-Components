extends Node

# Autoload (singleton) used to treat signals for our components

# Signal triggered when the main window size / disposition changes drastically
signal application_update_interface_disposition()

# The resizable node relative signals
signal components_resizable_node_is_edited(a_resizable_node : ResizableNode, a_is_edited : bool)
signal components_resizable_node_is_resized_or_moved(a_resizable_node : ResizableNode)
signal components_selectable_node_is_selected(a_selectable_node : SelectableNode, a_is_selected : bool, a_selection_type : int)
