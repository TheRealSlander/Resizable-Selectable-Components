extends Node

# Utility class used to ease the components job. This is an autoload (singleton).

#region CONSTANTS
# The delay used to block the events in milliseconds
const BLOCKED_EVENTS_DELAY : int = 200
# The allowed digits in the position / size edits
const DIGITS : PackedStringArray = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
#endregion

#region PUBLIC VARIABLES
# Returns the main window dimensions without the decorations (borders). This is a readonly variable
var window_size : Dictionary:
	get = _get_window_size
#endregion

#region PRIVATE VARIABLES
# Used to know when a node is already treating an _input() event
var _events_blocker : Node

# Used to compute elapsed time since the last tick (mainly used to avoid _input() events when undesired)
var _last_tick_time : int = Time.get_ticks_msec()
#endregion


#region METHODS
# Method used to allow the _input() events back to being triggered
func allow_events() -> void:
	#print("Events are not blocked anymore")
	# Allow the event to be passed through again
	_events_blocker = null
	# Stop processing now
	set_process(false)


# Method used to block the _input() events from being triggered for 200 milliseconds (by default)
func block_events(a_blocker_control : Node) -> void:
	#print("Events blocked by %s" % [a_blocker_control.name])
	# Store the current tick
	_last_tick_time = Time.get_ticks_msec()
	# Ensure any unhandled input is treated as handled
	#get_viewport().set_input_as_handled()
	# Indicate the event processing is blocked now
	_events_blocker = a_blocker_control
	# Activate the _process() method
	set_process(true)


# Method used to block events for some controls
func events_are_blocked(a_for_node : Node = null) -> bool:
	#print("Events are %sblocked for %s" % ["" if _events_blocker != a_for_node else "not ", a_for_node.name])
	return _events_blocker != null and (_events_blocker != a_for_node or a_for_node == null)


# Method used to get the size of the main window for the application / game, without the decorations (borders)
func _get_window_size() -> Dictionary:
	var l_window_size : Vector2i = DisplayServer.window_get_size()
	return {width = l_window_size.x, height = l_window_size.y, as_vector2i = l_window_size}


## Method called when the window size is changed manually.
func _on_window_size_changed_signal() -> void:
	# We need to wait for the interface to update
	await get_tree().process_frame
	
	# Finally we can send the message to all the listeners
	Signals.application_update_interface_disposition.emit()


# Method called each frame (mainly used to compute elapsed times for some of our timers)
func _process(_a_delta : float) -> void:
	# Get the current tick
	var l_now : int = Time.get_ticks_msec()
	
	# If the elapsed time since the last tick is greater than
	if (l_now - _last_tick_time) > BLOCKED_EVENTS_DELAY:
		#print("Now = %s, then = %s, delay = %s" % [l_now, _last_tick_time, l_now - _last_tick_time])
		allow_events()


func _ready() -> void:
	# Connect the "size_changed" event signal to the desired method to handle manual window resizing
	get_tree().root.size_changed.connect(_on_window_size_changed_signal)


# Method used to know if 2 rects are contained
func rect_contains_rect(a_rect_a : Rect2i, a_rect_b : Rect2i) -> bool:
	# We check the inclusion
	return a_rect_b.position.x >= a_rect_a.position.x and a_rect_b.position.x <= a_rect_a.end.x \
	and a_rect_b.position.y >= a_rect_a.position.y and a_rect_b.position.y <= a_rect_a.end.y \
	and a_rect_b.end.x >= a_rect_a.position.x and a_rect_b.end.x <= a_rect_a.end.x \
	and a_rect_b.end.y >= a_rect_a.position.y and a_rect_b.end.y <= a_rect_a.end.y


# Method used to know if 2 rects intersect
func rects_intersect(a_rect_a : Rect2i, a_rect_b : Rect2i) -> bool:
	# We check the exclusion instead of the inclusion
	# Check here for a test page: https://silentmatt.com/rectangle-intersection/
	# A.X1 < B.X2
	# A.X2 > B.X1
	# A.Y1 < B.Y2
	# A.Y2 > B.Y1
	return a_rect_a.position.x < a_rect_b.end.x and a_rect_a.end.x > a_rect_b.position.x and a_rect_a.position.y < a_rect_b.end.y \
	and a_rect_a.end.y > a_rect_b.position.y
#endregion
