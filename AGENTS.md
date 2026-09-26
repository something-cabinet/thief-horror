# Agent instructions

## Godot import cache

Godot may keep stale imported resources after source files are edited externally.
After changing `.dialogue` files or imported assets, force a reimport before
reporting the change as ready:

```bash
godot --headless --editor --quit --path .
```

For dialogue changes, verify the generated resource contains the new text:

```bash
rg "NEW TEXT" .godot/imported -g '*.tres'
```

A game process that was already running still holds the old resource in memory;
restart it after reimporting.
