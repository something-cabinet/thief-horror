# Thief Horror Game

Requires Godot 4.7.

## Debugging player movement

Press **F3** while playing to toggle the debug panel in the top-left corner.

When reporting a place where the player is stuck or movement feels wrong, send:

- The complete `XYZ` value shown in the panel.
- The `On ground` and `Step traversal` values.
- The movement direction you were holding.
- A screenshot, if possible.

Example: `XYZ: -28.500, 0.811, -115.700; On ground: true; Step traversal: false; holding W.`

## Marking item placement coordinates

Point the crosshair at a floor, table, shelf, or other solid surface and press
**F4**. The game displays the exact hit coordinate, prints a `[DEV_SURFACE]`
line in the Terminal, and copies a placement-ready `Vector3(x, y, z)` value to
the clipboard.

Example: `Vector3(-31.482, 1.836, -122.094)`

Send that value together with the item name, for example: “Put the antique
radio at `Vector3(-31.482, 1.836, -122.094)`.”

### Capture a debug log

Launch the game from Terminal and save its output:

```bash
cd ~/thief-horror
godot --path . 2>&1 | tee step-debug.log
```

Press **F3**, reproduce the problem, and keep holding the blocked movement key for 1–2 seconds. Quit the game, then send `~/thief-horror/step-debug.log`. Lines beginning with `PLAYER_STUCK` include the requested movement, camera pitch, blocking collider/contact, and the reason auto-step was rejected.
