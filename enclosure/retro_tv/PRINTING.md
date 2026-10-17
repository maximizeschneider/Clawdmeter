# Printing guide (for whoever prints this)

Ready-to-print files are in [`stl/`](stl/). Every part is already rotated the
way it should lie on the bed, so import it and don't rotate it. All parts
are small (the body is 75 × 56 × 38 mm, about 45 g of PLA in total), so any
printer works.

## Settings (all parts)

| Setting | Value |
|---|---|
| Material | PLA, matte if available (it hides layer lines) |
| Layer height | 0.2 mm (0.16 mm for a finer look) |
| Walls / perimeters | 3 |
| Infill | 15–20 %, any pattern (gyroid is nice) |
| Supports | **off**. Nothing needs them |
| Brim | only for `legs` and `antenna` (small footprints) |
| Scale | 100 %, dimensions are in mm |

## Step 1: fit test (do this first)

| File | Colour | Time (rough) |
|---|---|---|
| `fit_test.stl` | any | ~45 min |

This is the front ~15 mm of the case. Push the device in from the back,
screen first, USB-C to the right, buttons on the left. Check:
- it slides in without force and doesn't rattle,
- no white rim shows around the screen,
- the three side holes line up with the buttons.

If anything is off, measure by how much, adjust `retro_tv.scad`, and
re-export (or ask Claude to). Don't print the rest until this fits.

## Step 2: the parts

| File | Colour idea | How many | Time (rough) |
|---|---|---|---|
| `body.stl` | walnut / brown | 1 | ~3 h |
| `back_cover.stl` | brown | 1 | ~1 h |
| `faceplate.stl` | cream / beige | 1 | ~20 min |
| `knobs.stl` | dark brown / black | 1 file = 2 knobs | ~15 min |
| `legs.stl` | dark brown / black | 1 file = 4 legs, with brim | ~30 min |
| `antenna.stl` | grey / silver | 1 file = dome + 2 rods, with brim | ~20 min |
| `plungers.stl` | any | 1 file = 3 pins | ~10 min |

Small parts of the same colour can share one print (knobs + legs, for
example). Everything can also be printed in a single colour; the separate
faceplate just makes the two-tone look easy.

## After printing

- Remove brims, and clean the edges of the screen window with a knife if
  needed.
- Tolerances: holes often print a little small. If a peg doesn't go in,
  sand it lightly rather than forcing it.

Assembly steps are in [README.md](README.md#assemble).
