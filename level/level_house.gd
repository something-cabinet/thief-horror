extends Node3D
class_name LevelHouse

@export var intro_dialogue: DialogueResource

func _ready() -> void:
    GameManager.current_level = self
    if GameManager.is_preparing_first_level:
        # Preloaded as the title background: wait until the player presses Start.
        await GameManager.first_level_started
    play_intro_dialogue()

func play_intro_dialogue():
    DialogueManager.show_dialogue_balloon(intro_dialogue)
