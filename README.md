# MOCTET

A portrait falling-block game for Android, built with Godot 4.7 and an Omarchy-inspired Tokyo Night palette.

Clear lines on a 10 × 20 board, preview the next three pieces, and use the ghost outline to plan each landing. Levels increase every 10 lines, speeding up the falling pieces.

## Controls

| Action | Touch | Keyboard |
| --- | --- | --- |
| Move left / right | ◀ / ▶ | Left / Right |
| Soft drop | Press and keep ▼ down | Down |
| Rotate clockwise | ⟳ | Up |
| Rotate counterclockwise | ⟲ | Z |
| Hard drop | ⤓ | Space |
| Pause / resume | PAUSE | P |
| Restart | RESTART | R |
| Toggle music | ♪ | — |
| Quit | — | Q / Escape |

Touch actions activate on contact and support multiple fingers, so you can move or rotate while pressing soft drop. Sliding off soft drop, releasing the finger, pausing, or leaving the app clears the pressed input.

The layout scales to the available screen area, keeps the board near the top and controls near the bottom, and respects Android display cutouts. It has been checked on a Samsung SM-A176B at 1080 × 2340.

## Run

Open `project.godot` in Godot 4.7 and run the main scene, or launch from the project directory:

```sh
godot --path .
```

## Android build

Install the matching Godot export templates and configure the Android SDK and Java SDK paths in Godot's editor settings. The included `Android` export preset supports ARM64 and x86_64.

```sh
godot --headless --path . --export-debug Android /tmp/moctet-android.apk
adb install -r /tmp/moctet-android.apk
```

## Checks

Run the game logic checks and the touch, mouse, and screen-layout regression checks:

```sh
godot --headless --path . --script tests/test_game.gd
godot --headless --path . --script tests/test_touch_input.gd
```
