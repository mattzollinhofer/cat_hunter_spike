# Cat Hunter — Repo Handoff

Working name: **cat_hunter** (daughter will name the game; rename the repo/dir
then). This is a **new, standalone repo** — NOT a fork of space_scroller and NOT
a branch of it. It's 3D and shares no code with the 2D side-scrollers, so there
was no history worth carrying (contrast: `dragon_disaster`, which forked
space_scroller *with* history because it reuses the 2D engine).

Master design doc (source of truth): `~/working-notes/cat-hunter-game.md`.
Original sketches: `~/working-notes/cat-hunter-sketches/`.

## Description

A third-person 3D cat hunting game (Warrior Cats-flavored). Play a cat in a pine
forest: stalk and pounce prey (squirrels, rats), complete per-level tasks, level
up skills, fight bosses (e.g. "Darktail"). Hub is a camp with dens and a
fresh-kill/prey pile. Keep the "Paws" pause pun. Daughter's original idea.

Core loop: hunt prey -> complete level tasks -> level up -> boss. The heart is
stalk-and-pounce: creep low, stay quiet, close distance, time the pounce before
prey bolts.

## Strategy

Prove the loop is fun before investing in 3D art or the hero cat. Sequence:
1. (DONE) De-risk: 3D on the M4, GLB import + animation, follow-cam + walking.
2. Feel check (Matt plays) — is the movement/camera base right?
3. Prototype slice: stalk/pounce + one prey with flee AI + tasks/lives HUD.
4. Feel-tuning session (Matt playing) — pounce timing, prey thresholds.
5. Hero-art pass: her drawing -> cat model/texture (TRELLIS.2 local, later).

Claude can build systems unattended (movement, AI, HUD, levels — all testable
headless). Claude CANNOT feel-test 3D or judge whether the pounce is satisfying;
that's a Matt-in-the-loop step. Claude cannot model/rig/animate — art comes from
CC0 packs, AI image-to-3D, or Blender.

## Hunt slice — DONE (2026-07-26), headless-verified

Core loop from the sketches, built on the de-risk spike. Systems only — not yet
feel-tuned (Matt was away). Commits `6e368f7` (mechanic) + `645f12a` (HUD).

- `cat_controller.gd` — added stalk (slow/quiet) + pounce (lunge).
- `prey.gd` — squirrel: grazes, detects the cat, flees. Tuned so you must stalk
  close then pounce; catch is distance-based during a pounce.
- `hunt.gd` — spawns prey, counts catches toward "catch 5 prey", tracks lives.
- `hud.gd` — task progress + lives, top-left.
- `tests/test_hunt.tscn` — locks the 3 rules (walk→flee, stalk→undetected,
  pounce→catch); passes alongside the spike test.
- Decision: cat & prey on separate physics collision layers (pounce passes
  through for a distance-based catch; also fixed a same-layer physics explosion).
  All flee/stalk/pounce values are tuning constants for the feel session.

## What's in the repo now (de-risk slice — DONE)

- `main.gd` — builds the world (ground, sky, sun, placeholder pines) and a
  trailing follow-camera; spawns the cat. Built in code to avoid fragile
  hand-authored .tscn resource data.
- `cat_controller.gd` — cat: WASD/arrows, faces travel dir, Walk/Survey anims,
  gravity. Test hooks: `use_force_input` (headless test), `CAT_CAPTURE` env
  (screenshot mode).
- `assets/Fox.glb` — CC0 rigged/animated quadruped, cat stand-in (Khronos glTF
  sample). Proves the exact import path a real cat GLB will use.
- `tests/test_spike.tscn` — headless test, exits 0/1 (space_scroller convention):
  asserts GLB import + animation names + that the cat walks.
- `README.md` — how to run/test/screenshot.

Verified: `godot --headless --import` imports cleanly; headless test passes;
non-headless run renders the cat walking the forest on the M4 (Metal, Forward+).

## Decisions made

- New standalone repo, clean `git init` (no fork, no branch). Rationale: 3D
  shares nothing with the frozen 2D games; a branch would never merge and would
  couple unrelated projects.
- Prototype art = CC0 / primitives, NOT her drawing yet. Her art becomes the
  hero cat's texture in a later pass.
- Built the scene in code, not .tscn, to keep it robust and diffable.
- Cost of image-to-3D is not a constraint; rig/animation quality is the real one.

## Shipped so far (all pushed + deployed to Pages)

- [x] De-risk spike: 3D + GLB import + follow-cam walking cat.
- [x] Stalk/pounce hunt loop + fleeing squirrel.
- [x] Tasks + lives HUD, then reworked to match the sketch (level name top-center,
      diamonds top-left, tasks right, "Paws" pause bottom-left).
- [x] Auto-deploy to GitHub Pages on every push.
- [x] Data-driven levels (levels/*.json + level_loader.gd, validated fallback).
- [x] Mobile touch controls: floating movement joystick + Stalk/Pounce buttons
      (also mouse-driven, so it works in a desktop browser).

Live: https://mattzollinhofer.github.io/cat_hunter_spike/  (5 headless tests pass.)

## Next actions — prioritized (from the 2026-07-26 architecture review)

Full review: `~/working-notes/cat-hunter-architecture-review-2026-07-26.md`.
Full backlog (basics/graphics/abilities): `~/working-notes/cat-hunter-game.md`.

ACT SOON (before/around the feel-tuning session):
- [ ] Win/lose + make `lives` actually mean something. NOTE: what costs a life /
      how you win is a DESIGN decision for Matt + daughter — do NOT invent it solo.
- [ ] Prey FLEE->GRAZE transition (stalk currently works once per spawn).
- [ ] World bounds (you can walk off the 80x80 ground into void).
- [ ] Tuning consts -> `@export` (cat_controller.gd, prey.gd) for the feel session.
- [ ] Sound/audio — none exists yet (footsteps, pounce, catch, ambient).
- [ ] Matt: play it, confirm follow-cam + movement + pounce + floating-joystick feel.

LATER: camp hub (dens + prey pile) · rat + Darktail boss · skill leveling · hero
cat (her drawing -> TRELLIS/Meshy) · real CC0 trees · swim/climb abilities ·
name the game + rename the repo (it has outgrown "spike").

## Deferred (not blockers)

- SpringArm3D collision-aware camera (current cam is fixed-orientation follow).
- Fox facing-vs-travel offset (cosmetic; real cat sets its own convention).
- Two tiny code smells the review noted (fix when next touching those files):
  PauseButton duplicates TouchButton; CAT_CAPTURE harness lives in cat_controller.gd.
