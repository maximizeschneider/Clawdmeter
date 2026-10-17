# Retro-TV dock (ESP32-C6-Touch-AMOLED-2.16)

A small 60s-style television for the Clawdmeter. The screen sits on the
left behind a rounded TV window. On the right is a control panel with two
knobs and a speaker grille. It stands upright on four splayed legs, with
rabbit-ear antennas on top.

**The board is mounted a quarter turn from upright:** USB-C faces right and
the buttons face left.
- The right-angle plug hides behind the control panel, with its cable
  running along the floor to the back cover's bottom corner on the button
  side (bottom right seen from behind).
- The three buttons are pressed through the left side of the case.
- The board's motion sensor (IMU) turns the picture upright by itself.

Size: 75 × 69 × 42 mm body, so slightly wider than tall. With legs it stands
about 82 mm tall, or about 116 mm to the antenna tips. Run
`openscad -D 'part="dims"' -o x.stl retro_tv.scad` to print the numbers
after you change parameters.

| Front | Left side (buttons) |
|---|---|
| ![front](preview_front.png) | ![left](preview_left.png) |

`retro_tv.scad` is fully parametric. Open it in [OpenSCAD](https://openscad.org),
press F5 to preview, and use Window → Customizer to change the numbers.

## 1. Measure your board first

The `Board — MEASURE THESE` values are guesses. Measure these with calipers, holding the board upright with USB-C at the bottom:

| Parameter | What to measure |
|---|---|
| `board_w`, `board_h` | PCB outline. `board_h` runs from the USB-C edge to the top edge. |
| `glass_w`, `glass_h`, `glass_t` | Display glass outline, and how far it stands proud of the PCB. |
| `glass_dv` | Glass centre offset upward from the PCB centre. |
| `buttons` | Measured **as mounted** (USB-C right, buttons left): each button's height above the bottom of the mounted board, and its depth behind the PCB front. The firmware uses all three (BOOT = Space/voice, KEY = Shift+Tab, PWR = cycle screens / hold to pair). |
| `usb_dx` | USB-C offset from the middle of its edge, if it isn't centred. |
| `plug_len` | Your right-angle plug's head, from the metal tip's base to the far side of the plastic. It must fit in `panel_w`. |
| `btn_protrude` | How far the buttons stick out past the PCB edge. |

Then print `part="fit_test"` (the front few mm, about 20 min). It checks the
window, how the board clips in, and the button holes before the long print.

## 2. Parts

All STLs come out already in print orientation:
`openscad -D 'part="body"' -o body.stl retro_tv.scad`

| Part | Colour idea | Notes |
|---|---|---|
| `body` | walnut brown | Face-down, no supports. |
| `faceplate` | cream | Glue it into the front recess. This gives the two-tone look without a multi-colour printer. |
| `back_cover` | walnut | Friction fit, with vents in the upper half. |
| `knobs` | dark brown | Decorative, pinned with a 6 mm stub of 1.75 mm filament. |
| `legs` | dark brown | 4 legs, all the same length at `tilt = 0`. Press-fit or glue. |
| `antenna` | grey | Dome + 2 rods. 2 mm metal rod or a bamboo skewer looks better than printed rods. |
| `plungers` | any | One per side button, through the left wall. |

Matte PLA, 0.16–0.2 mm layers, 3–4 walls, 15–20 % gyroid. Walnut-brown,
cream and dark-brown PLA all exist, so no painting is needed.

## 3. Assemble

1. Glue the faceplate in, then pin and glue the knobs.
2. Drop the plungers into the side holes from the inside.
3. Push the board in from the back, glass first, until it snaps past the four
   clip posts.
4. Plug in the right-angle USB-C with the cable pointing toward the back.
   Run the cable down and along the floor to the bottom corner on the button
   side (bottom right seen from behind), lay it into the notch there, then
   press the cover on.
5. Press the back cover on, then press in the legs and the antenna dome.

`tilt` (default 0) shortens the rear legs to lean the screen back if you
want that later.
