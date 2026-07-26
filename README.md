# Cat Hunter — de-risk spike

Throwaway Godot 4.5 project proving the two riskiest unknowns for the planned 3D
cat hunting game (see `~/working-notes/cat-hunter-game.md`):

1. **CC0 rigged/animated GLB import works** on this Mac — a downloaded Khronos
   Fox (`assets/Fox.glb`, a rigged, animated quadruped standing in for the cat)
   imports and its animations play.
2. **A third-person walking controller + follow-cam works** — WASD/arrow
   movement, the model faces its travel direction, Walk/idle animations, a
   trailing camera, in a small forest.

Both are verified: the headless test passes and a non-headless run renders the
fox walking through the forest.

## Run it

```bash
# Play (WASD or arrow keys to move the cat)
godot --path .

# Headless de-risk test (exits 0 pass / 1 fail, like space_scroller tests)
godot --headless --path . tests/test_spike.tscn

# Import assets after a fresh checkout (if load errors)
godot --headless --path . --import

# Capture a screenshot (auto-walks, saves PNG, quits)
CAT_CAPTURE=/absolute/out.png godot --path .
```

## Layout

- `main.gd` — builds the world (ground, sky, sun, placeholder pines, follow-cam)
  and spawns the cat. Built in code to avoid fragile hand-authored `.tscn` data.
- `cat_controller.gd` — the cat: movement, facing, animations, gravity. Has two
  test hooks: `use_force_input` (headless test drives it) and the `CAT_CAPTURE`
  env var (screenshot mode).
- `assets/Fox.glb` — CC0 rigged/animated quadruped, cat stand-in.
- `tests/test_spike.tscn` — headless import + walking assertions.

## Not done here (deferred, not blockers)

- SpringArm3D collision-aware camera (current cam is fixed-orientation follow).
- Real cat model / her drawing as texture (hero-art pass, later).
- Stalk/pounce, prey AI, tasks/lives HUD — the actual prototype slice.
