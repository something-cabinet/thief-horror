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
	return event.as_text().trim_suffix(" (Physical)")
