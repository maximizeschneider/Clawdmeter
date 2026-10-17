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
| `0_fit_test.stl` | any | ~45 min |

This is the front ~15 mm of the case. Push the device in from the back,
screen first, USB-C to the right, buttons on the left. Check:
- it slides in without force and doesn't rattle,
- no white rim shows around the screen,
- the three side holes line up with the buttons.

If anything is off, measure by how much, adjust `retro_tv.scad`, and
re-export (or ask Claude to). Don't print the rest until this fits.

## Step 2: one plate per colour

The parts are already grouped: each file is one full plate in one colour.
Load the file, put that filament in, print, then go to the next.

| File | Filament | What's on it | Time (rough) |
|---|---|---|---|
| `1_brown.stl` | walnut / brown | TV body, back cover, 3 button pins | ~4 h |
| `2_cream.stl` | cream / beige | front panel | ~20 min |
| `3_dark.stl` | dark brown / black | 2 knobs, 4 legs (**add a brim**) | ~45 min |
| `4_grey.stl` | grey / silver | antenna dome + 2 rods (**add a brim**) | ~20 min |

The button pins are body-coloured on purpose, so they blend into the TV's
side. The largest plate (brown) is 102 × 116 mm, so it fits any printer.

- **Only one colour?** Print all four files in it. It works the same, just
  without the two-tone look.
- **Multi-colour printer (e.g. Bambu AMS)?** Load all four files together
  as one project, give each object its filament, and print in one go.

Single parts (to reprint just one) are in `stl/parts/`.

## After printing

- Remove brims, and clean the edges of the screen window with a knife if
  needed.
- Tolerances: holes often print a little small. If a peg doesn't go in,
  sand it lightly rather than forcing it.

Assembly steps are in [README.md](README.md#assemble).
