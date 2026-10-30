# The Way Home - Chapter 1 (Godot 4.7)

A 2D isometric, grid-based narrative adventure. This repository currently contains
**Milestones 1-5**: the playable isometric movement prototype, the Steps economy and
HUD, the family/NPC interaction and dialogue system, the photography system, and the
save/load system.

---

## Running the prototype

Open the folder in Godot 4.7 and press **F5**, or from a shell:

```powershell
Godot_v4.7.1-stable_win64.exe --path D:\majortest\mingame
```

### Controls

| Input | Action |
| --- | --- |
| `W A S D` / arrow keys | Move (8 directions) |
| `W`+`D`, `D`+`S`, `S`+`A`, `A`+`W` | Move one cell diagonally |
| `G` | Show/hide the walkable grid (red = blocked cells) |
| `F3` | Toggle debug overlay |
| `E` / `Space` | Talk to the person Ren is facing |
| `↑` / `↓` | Choose a dialogue option |
| `F5` | *Debug:* receive 50 Steps (stands in for family support) |
| `F6` | *Debug:* drop to 0 Steps to see the frozen state |
| `F` | *Reserved:* take a photo (Milestone 4) |
| `Tab` | *Reserved:* photo log (Milestone 4) |

Movement is grid based. A single key travels two cells along a grid axis; two keys
together travel one cell diagonally. Both are real grid moves, so every cell on the
map stays reachable and costs match the actual grid distance - a one-cell move costs
1 Step, a keyboard-direction move costs 2.

---

## What Milestone 1 delivers

* Godot 4.7 project with `TileMapLayer` + an isometric `TileSet`
  (`TileSet.TILE_SHAPE_ISOMETRIC`, `TILE_LAYOUT_DIAMOND_DOWN`, 64x32 diamonds).
* A data-driven test neighbourhood (`data/maps/test_neighborhood.txt`) with houses,
  a street, crossing, pavement, trees, poles, a vendor stall, a crate and signage.
* Smooth grid-to-grid movement with collision (tile collision polygons + prop
  `StaticBody2D` colliders) and Y-sorting so Ren passes correctly in front of and
  behind props.
* **Grid-authoritative movement**: every step is validated against the grid (target
  *and* the cells crossed), and the body is positioned by the grid rather than pushed
  by physics, so it can never be stranded off-grid between two props.
* **Walkable grid overlay** (`G`): red diamonds mark exactly which cells an obstacle
  occupies (border walls, house footprints, trees, stalls, poles...), a faint outline
  marks free cells, and the player's cell is highlighted. A refused step flashes the
  blocking cell in red so the reason is always visible.
* Directional 8-way animation set for Ren, plus automatic fading of a prop while it
  hides the player.
* Follow camera clamped to the map bounds, debug overlay, atmospheric backdrop.

### Verified by automated tests

```
godot --headless --path . --script res://tests/test_milestone1.gd
```

82 checks: grid maths, map parsing, walkability, tile custom data, step interpolation,
blocking, y-sort structure, camera limits, input action map, real keyboard-driven
movement, prop occlusion fading, a 60-step stress walk that verifies the body never
leaves the grid, and the grid overlay (blocked-cell count, toggle, refusal flash).
All pass.

---

## What Milestone 2 delivers

### The Steps economy

Steps are a **currency for movement, not a count of literal footsteps**. Ren spends
them to travel and receives them from people, work and story events. Every cell of
travel costs `cost_per_cell` Steps, so a two-cell key press costs twice a diagonal
one - the price always equals the real grid distance.

All numbers live in one inspector-editable resource, `data/economy/steps_config.tres`
(`StepsConfig`): starting balance, cost per cell, the 24h Departure window, how long
that window lasts in real time, and the low-balance warning threshold. Balancing never
requires touching gameplay code.

`StepsWallet` (`$Steps` in the main scene, deliberately not an autoload) owns the
balance and exposes `spend()`, `grant()`, `set_steps()`, `cost_for_cells()`,
`can_afford()`, plus signals for `changed`, `spent`, `granted`, `refused`,
`frozen_changed` and `departed`. It also has `save_to_file()` / `load_from_file()`
(covered by tests) which the full save system will call in Milestone 5.

### Movement costs and refusals

* A step is charged only *after* the grid accepts it, so blocked moves are free.
* If Ren cannot afford the step, the step is refused **before** any movement plays, the
  HUD explains the price, and the balance is untouched. With 1 Step left, a diagonal
  move still works while a full keyboard-direction move does not - a real decision.
* Nothing is ever charged twice, and a refused move never strands the body mid-grid.

### Zero Steps: frozen, not dead

Reaching 0 Steps freezes Ren: his body stops answering input and a **Departure clock**
appears, communicating that a frozen person has 24 hours before they Depart. The
countdown runs on accelerated story time (24 in-game hours in 180 real seconds) so it
can actually be seen. Receiving Steps immediately unfreezes him and clears the clock.

Chapter 1 deliberately does **not** trigger a game over here - the countdown is
pressure and world texture, not lethality.

### HUD

A small, atmospheric panel (top-left) shows the Steps balance (cream, amber when low,
red when empty), a token icon, the per-cell price and floating `-2` / `+50` feedback.
Refusals surface as a toast instead of a silent no-op, and the frozen state swaps in a
centred banner with the live Departure clock.

### Verified by automated tests

```
godot --headless --path . --script res://tests/test_milestone2.gd
```

49 checks: config wiring and starting balance, spend/grant/refuse semantics and
signals, per-cell cost maths, a real charged keyboard move, freezing at zero, the HUD
banner and clock, refusing input while frozen, recovery by receiving Steps, refusing an
unaffordable move while still affordable enough for a diagonal, balance save/load,
countdown behaviour and HUD formatting/colour states. All pass.

Milestone 1's 82 checks still pass (that test tops up the balance so the economy cannot
interfere with movement checks).

Reference renders are in `tests/screenshot_*.png` (`08_hud`, `09_frozen` for the HUD).

---

## What Milestone 3 delivers

### Family and NPCs

Four family members live in the test neighbourhood, placed by a data file
(`data/npcs/family.txt`): **Daw Mya** (mother), **U Aung** (father),
**Daw Hla** (grandmother) and **Thiri** (little sister). Each is a character with
its own 8-direction sprite sheet and portrait, spawned by `NPCManager`, which blocks
the NPC's cell on the grid so nobody can walk through them. Adding a person is one
line of data plus one art sheet - no code changes.

### Interaction

Ren talks to whoever he is facing, within one cell. A prompt (`E  ·  Talk to ...`)
appears over the HUD, and `E` / `Space` starts the conversation. While it runs, Ren
stops moving, both characters turn to face each other, and the prompt hides.
`InteractionSystem` owns the lookup and the hand-off so the dialogue code never
touches the player directly.

### Branching dialogue

Conversations are data-driven JSON files (`data/dialogue/*.json`) loaded by
`DialogueRunner`, which owns *state only* (current node, line, allowed choices,
flags, effects) and never touches the screen. `DialogueBox` handles the typewriter,
portraits, name plate, choice highlighting and the `↑↓ / E` controls.

Features:
* Multi-line sequences with a typewriter that completes instantly on a second press.
* Branching choices, filtered by `once` flags (a gift can only be taken once) and by
  conditions (`frozen`, `not_frozen`, `low_steps`).
* Effects: `grant_steps` (family support) and `set_flag`.
* A `narrator` speaker for stage directions, shown without a portrait.
* Frozen Ren can still talk to his mother - she gives more Steps and tells him to move.

The four conversations carry the chapter's emotional weight: Daw Mya on the Departure
sign and the road, U Aung on what cells cost, Daw Hla on the sentence a frozen person
has a day to finish, and Thiri asking for a photo (a thread Milestone 4 picks up).

### Verified by automated tests

```
godot --headless --path . --script res://tests/test_milestone3.gd
```

180 checks: NPC data parsing and spawn, blocked cells, refusing to walk through an
NPC, interaction detection and its prompt, starting/advancing/ending a conversation,
Ren and the NPC turning to face each other, line speakers and text, offering and
choosing options, granting Steps and setting flags, hiding a choice after it has been
taken, the frozen variant of the mother's conversation, JSON integrity across all
four files (every `goto` resolves, conditions and effects are valid), and portrait
files. All pass.

Milestones 1 and 2 still pass: 82 + 49 checks.

Reference renders are in `tests/screenshot_*.png` (`08_hud`, `09_frozen`, `10_dialogue`).

---

## What Milestone 4 delivers

### Photo mode

Press `F` to open the viewfinder. The frame overlays the world; Ren can still walk
to reposition, but talking is disabled while framing. `Space`/`E` captures the
viewfinder region into the album and grants a small Step reward (+1 by default);
`F` or `Esc` closes. The viewfinder labels whoever is in frame (a family member, or
"the Steps sign"), or "—" when nothing notable is centred.

### The photo album

Press `Tab` to open the album: a grid of thumbnails plus a large preview with the
subject. Arrow keys move the selection, `Tab`/`Esc` close. Captures are stored as
`ImageTexture`s in `PhotoManager`, which exposes `capture()`, `count()`, `get_photo()`
and a `captured` signal, so the UI and the tests share one source of truth.

### Verified by automated tests

```
godot --headless --path . --script res://tests/test_milestone4.gd
```

30 checks: capturing returns a valid photo with the right size, subject and caption;
the count grows; `clear()` empties; each capture grants a Step; the log opens,
shows the count and closes; photo mode toggles, shows the viewfinder at the right
size, keeps movement enabled; subject detection names a nearby NPC and reports
nothing in an empty area. All pass.

Milestones 1-3 still pass: 82 + 49 + 180 checks.

Reference renders are in `tests/screenshot_*.png` (`08_hud`, `09_frozen`, `10_dialogue`).

---

## What Milestone 5 delivers

### Save / load

A single slot (`user://save_slot_1.json`) plus the photo images beside it
(`user://photos/`). `SaveManager` gathers and restores everything without any
gameplay script knowing about files:

* **Steps** balance, frozen flag and Departure progress (via `StepsWallet.restore()`).
* **Dialogue flags** (which gifts have been taken, etc.).
* **The photo album** (images reloaded from disk as `ImageTexture`s).
* **Ren's cell and facing** (falls back to the start cell if the saved cell is blocked).

`save_game()` / `load_game()` / `has_save()` / `delete_save()` are exposed for UI and
tests. `F7` saves, `F8` loads, and the HUD toasts the result.

### Verified by automated tests

```
godot --headless --path . --script res://tests/test_milestone5.gd
```

28 checks: empty slot, save/load round-trip of balance, flags, cell, facing and
photos, load failure on a missing slot, frozen state and Departure progress surviving
a round trip, photo texture surviving a round trip, and slot deletion. All pass.

Milestones 1-4 still pass: 82 + 49 + 180 + 32 checks.

---

## Project layout

```
scenes/
  main/main.tscn              entry scene (world root, Steps, HUD, NPCs, Dialogue, Photos, ...)
  characters/ren.tscn         PlayerRen + AnimatedSprite2D + GridMover + camera
  npcs/npc.tscn               family member (static, y-sorted, blocks its cell)
  props/*.tscn                house, tree, pole, stall, crate, sign
  ui/hud.tscn                 Steps panel, frozen banner, toast, popups
  ui/dialogue_box.tscn        typewriter box, portrait, choices, prompt
scripts/
  main/main.gd                scene wiring, camera limits, debug overlay, debug keys
  movement/isometric.gd       all grid <-> world maths (static helpers)
  movement/grid_mover.gd      interpolation, walkability validation, step signals
  player/player.gd            input -> direction -> animation, charges the wallet
  economy/steps_config.gd     tunable economy resource
  economy/steps_wallet.gd     balance, spending, frozen state, Departure clock, save
  npc/npc.gd                 family member: cell, facing, portrait path
  npc/npc_manager.gd         spawns NPCs from data/npcs/family.txt, interaction lookup
  dialogue/dialogue_runner.gd branching conversation state machine
  interaction/interaction_system.gd  prompt + hand-off to the dialogue runner
  save/save_manager.gd        central save/load (slot + photos)
  photography/photo.gd           a captured image + metadata
  photography/photo_manager.gd  collection, capture, rewards
  ui/hud.gd                   HUD binding, popups, toasts, clock formatting
  ui/dialogue_box.gd          typewriter, choices, portraits, prompt
  ui/photo_mode.gd            viewfinder, capture, subject detection
  ui/photo_log.gd             album grid + preview
  maps/map_builder.gd         builds the map from text, answers is_walkable()
  maps/tile_legend.gd         ASCII glyph -> atlas coords
  maps/prop_library.gd        ASCII glyph -> scene + collision footprint
  props/prop_occluder.gd      fade a prop while it covers the player
  ui/grid_overlay.gd          walkable grid overlay + blocked-step flash
assets/
  characters/ren/ ...         ren_sheet_placeholder.png + ren_frames.tres + portrait
  characters/<id>/ ...        one sheet + frames + portrait per family member
  environments/tiles/         iso_tiles_placeholder.png (4x2 atlas)
  environments/props/         prop placeholders
  environments/shadow_placeholder.png
  ui/steps_token_placeholder.png
data/
  tileset_iso.tres            generated TileSet (physics + "walkable" custom data)
  economy/steps_config.tres   live economy numbers
  npcs/family.txt             who lives where, and their dialogue file
  dialogue/*.json             branching conversations (mother, father, grandmother, sister)
  maps/test_neighborhood.txt  the map
tools/
  generate_placeholder_art.py placeholders (PIL) - now draws the family too
  init_project.gd             writes input map + physics layer names
  build_tileset.gd            regenerates data/tileset_iso.tres
  build_character_frames.gd   regenerates every character's SpriteFrames
tests/
  test_milestone1.gd          headless movement acceptance test (82)
  test_milestone2.gd          headless economy/HUD acceptance test (49)
  test_milestone3.gd          headless NPC/dialogue acceptance test (180)
  test_milestone4.gd          headless photography acceptance test (32)
  test_milestone5.gd          headless save/load acceptance test (28)
  capture_screenshot.gd       renders reference screenshots
```

## Replacing placeholder art

Art is intentionally disposable; the systems are not tied to it.

| Asset | Contract |
| --- | --- |
| `iso_tiles_placeholder.png` | 4x2 atlas of 64x32 diamonds. Re-run `tools/build_tileset.gd`. Solid tiles are defined in `SOLID_TILES`. |
| `ren_sheet_placeholder.png` | 48x64 frames, feet at (24, 62), 8 facing rows (n, ne, e, se, s, sw, w, nw), 5 columns (idle + 4 walk). Re-run `tools/build_ren_frames.gd`. |
| `props/*.png` | Bottom-centre of the image sits on the anchor cell. Collider lives in the matching `.tscn`. |

No gameplay script references a texture path except these two generator tools.

## Map editing

`data/maps/test_neighborhood.txt` holds three parts: `START x,y`, a `MAP` block of
ground glyphs and a `PROPS` block laid out on the same grid. Glyphs are declared in
`TileLegend` and `PropLibrary`, so new tiles/props are one dictionary entry each.

---

## Known limitations (deliberately left for later milestones)

* **No save/load of any state** - balances, flags and photos reset each launch;
  persistence arrives with Milestone 5.
* **Departure has no consequence** when the clock reaches zero (Chapter 1 must not
  force a game over); the banner reads "Departure" and play continues.
* **Single save slot only** - no slot selection or new-game flow yet.
* **No auto-save** - saving is manual (F7); closing the window does not save.
* **Photos persist as PNGs** but the album has no caption editing or deletion yet.
* Placeholder art only; no audio.
* Buildings fade but there is no smooth camera framing/room transition.
* The map is a single test neighbourhood, not the Chapter 1 route.
* Collision is grid-validated first; prop colliders now match their footprints exactly
  (house = 3x2 diamond, stall = 1 cell) and act as a safety net for future physics
  objects, not as the thing that blocks walking.
