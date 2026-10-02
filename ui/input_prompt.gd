extends RefCounted
class_name InputPrompt

# Builds on-screen prompts from the live InputMap, so they follow keybinds
# changed in the settings menu.


# Formats e.g. "[E] Open door" with the key currently bound to action.
static func format(text: String, action: StringName = &"interact") -> String:
	return "[%s] %s" % [key_label(action), text]


static func key_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return event_label(events[0])


static func event_label(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key == null:
		return event.as_text()
	if key.keycode != KEY_NONE:
		return key.as_text_keycode()
	if key.physical_keycode != KEY_NONE:
		# Show the key as labelled on the player's active keyboard layout.
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(key.get_physical_keycode_with_modifiers())
		return OS.get_keycode_string(mapped)
	return key.as_text_key_label()
