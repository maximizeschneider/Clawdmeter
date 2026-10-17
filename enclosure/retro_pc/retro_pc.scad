// Clawdmeter "retro PC" desk dock for the Waveshare ESP32-C6-Touch-AMOLED-2.16.
//
// A small tilted Macintosh-style terminal: display up top behind a recessed
// bezel, a decorative floppy slot below it, the right-angle USB-C plug hidden
// inside, and the cable leaving through a notch in the removable back cover.
//
// Everything is parametric. The BOARD numbers below are first guesses —
// measure your board with calipers and fix them before printing (see
// README.md). Print `part = "fit_test"` first: it is a thin slice of the
// front that checks window, glass pocket and button holes in ~20 minutes.
//
// Render one part at a time:
//   openscad -D 'part="body"'       -o body.stl       retro_pc.scad
//   openscad -D 'part="back_cover"' -o back_cover.stl retro_pc.scad
//   openscad -D 'part="plunger"'    -o plunger.stl    retro_pc.scad
//   openscad -D 'part="fit_test"'   -o fit_test.stl   retro_pc.scad

part = "assembly"; // [assembly, body, back_cover, plunger, fit_test]

/* [Board — MEASURE THESE] */
board_w    = 56;    // PCB width, left to right
board_h    = 46;    // PCB height, bottom (USB-C edge) to top
pcb_t      = 1.6;   // PCB thickness
glass_w    = 44;    // display glass/module outline, width
glass_h    = 44;    // display glass/module outline, height
glass_t    = 1.5;   // how far the glass stands proud of the PCB front
glass_dv   = 0;     // glass centre offset upward from PCB centre
active     = 39.5;  // visible window (480x480 at 2.16" ~ 38.8 mm square)
back_parts = 6;     // tallest part on the PCB back (battery plug etc.), from PCB back

// Side buttons: [side (0 = left, 1 = right seen from the front),
//                centre height above the PCB bottom edge,
//                centre depth behind the PCB front face].
// The firmware uses all three: BOOT = Space/voice, KEY = Shift+Tab,
// PWR = cycle screens / hold to pair. PLACEHOLDER positions — measure.
buttons = [[1, 34, 0.8], [1, 23, 0.8], [1, 12, 0.8]];
btn_protrude = 0.8; // how far a button sticks out past the PCB edge
btn_hole     = 3.2; // hole for the printed plunger

// Optional through-holes in the front, [x, y] from the window centre.
// The handoff mentions two 1.5 mm mic holes — only add them if your board
// really has front-facing mics (the firmware does not use a mic).
mic_holes = [];
mic_d     = 1.5;

/* [Case] */
tilt          = 15;   // screen leans back by this many degrees (15..20)
wall          = 2.4;  // shell wall
lip           = 1.2;  // plastic in front of the glass
r             = 3;    // outer edge radius
fit           = 0.4;  // total clearance on pockets (0.3..0.5)
bottom_margin = 26;   // face area below the PCB: floppy slot + plug room
top_margin    = 8;    // face area above the PCB
base_depth    = 62;   // footprint depth (front to back at the desk)
floppy        = [35, 2, 1]; // decorative slot: width, height, depth
bezel_pad     = 5;    // recessed CRT bezel around the window
bezel_depth   = 0.6;
cover_clr     = 0.15; // back cover plug clearance per side
cable_notch   = [7, 7];
feet_d        = 10.5; // recesses for stick-on rubber feet
feet_depth    = 1;

$fn = 48;
eps = 0.01;

// ---- derived ----
side_gap = btn_protrude + 1 + 0.3;              // plunger head + slack
W        = board_w + fit + 2 * (side_gap + wall); // body width
H        = bottom_margin + board_h + top_margin;  // face height along the slope
Hz       = H * cos(tilt);                       // vertical height
D        = base_depth;
assert(D - Hz * tan(tilt) > lip + glass_t + pcb_t + back_parts + wall + 3,
       "base_depth too small for this tilt/height");

pcb_x0    = (W - board_w) / 2;
pcb_front = -(lip + glass_t);       // face-local z of the PCB front
pcb_back  = pcb_front - pcb_t;
win_c     = [W / 2, bottom_margin + board_h / 2 + glass_dv];

// Face frame: x = across, y = up the face, z = out of the face (inside is z < 0).
// The front plane passes through the front-bottom edge at the origin.
module face() rotate([90 - tilt, 0, 0]) children();

module rrect(size, rr, h) // rounded rectangle slab, centred in xy
    linear_extrude(h) offset(rr) square([size[0] - 2 * rr, size[1] - 2 * rr], center = true);

module shell(inset) {
    rr = r - inset;
    hull() for (x = [r, W - r], z = [r, Hz - r]) {
        translate([x, z * tan(tilt) + r / cos(tilt), z]) sphere(rr);
        translate([x, D - r, z]) sphere(rr);
    }
}

// ---- back opening (counterbored so the cover sits flush) ----
open_m  = wall + 1.5;
open_sz = [W - 2 * open_m, Hz - 2 * open_m];
cb      = 2;   // counterbore width around the opening
cb_t    = 1.2; // counterbore depth = cover flange thickness

module back_opening() {
    translate([open_m, D - wall - 1, open_m]) cube([open_sz[0], wall + 2, open_sz[1]]);
    translate([open_m - cb, D - cb_t, open_m - cb])
        cube([open_sz[0] + 2 * cb, cb_t + 1, open_sz[1] + 2 * cb]);
}

// Snap ledges on the side walls just behind the PCB: the board pushes past
// the ramp from the back and is held against the front lip.
clip_len = 6;
module clips() for (s = [0, 1], v = [bottom_margin + 6, bottom_margin + board_h - 6]) {
    tip = side_gap + fit / 2 + 0.5;  // reaches 0.5 mm over the PCB edge
    face() translate([s ? W - wall : wall, v - clip_len / 2, 0])
        mirror([s, 0, 0]) rotate([-90, 0, 0])
            linear_extrude(clip_len)
                polygon([[-0.5, -(pcb_back - 0.1)], [tip, -(pcb_back - 0.1)],
                         [-0.5, -(pcb_back - 0.1) + 2.5]]);
}

module front_cuts() face() {
    // window with a 45° chamfer so the frame casts no shadow
    translate([win_c[0], win_c[1], 0])
        hull() {
            translate([0, 0, -lip - eps]) rrect([active, active], 1, eps);
            translate([0, 0, -bezel_depth]) rrect([active + 2 * (lip - bezel_depth), active + 2 * (lip - bezel_depth)], 1, eps);
        }
    // CRT bezel recess
    translate([win_c[0], win_c[1], -bezel_depth])
        rrect([active + 2 * bezel_pad, active + 2 * bezel_pad], 3, bezel_depth + 1);
    // glass pocket (the glass rests against the lip)
    translate([win_c[0], win_c[1], -lip - glass_t - 5])
        rrect([glass_w + fit, glass_h + fit], 0.5, glass_t + 5);
    // floppy slot
    translate([W / 2, bottom_margin / 2, -floppy[2]])
        rrect([floppy[0], floppy[1]], floppy[1] / 2 - eps, floppy[2] + 1);
    for (m = mic_holes)
        translate([win_c[0] + m[0], win_c[1] + m[1], -wall - 1]) cylinder(d = mic_d, h = wall + 2);
}

module button_holes() for (b = buttons)
    face() translate([b[0] ? W - wall / 2 : wall / 2, bottom_margin + b[1], pcb_front - b[2]])
        rotate([0, 90, 0]) cylinder(d = btn_hole, h = wall * 3, center = true);

module feet() for (x = [9, W - 9], y = [9, D - 9])
    translate([x, y, -1]) cylinder(d = feet_d, h = feet_depth + 1);

module body() {
    difference() {
        shell(0);
        shell(wall);
        back_opening();
        front_cuts();
        button_holes();
        feet();
    }
    clips();
}

module back_cover() { // modelled lying flange-down, outside face on the bed
    ring = 1.6; plug = wall - cb_t + 3;
    psz = [open_sz[0] - 2 * cover_clr, open_sz[1] - 2 * cover_clr];
    fsz = [open_sz[0] + 2 * cb - 2 * cover_clr, open_sz[1] + 2 * cb - 2 * cover_clr];
    difference() {
        union() {
            rrect(fsz, 1, cb_t);
            difference() {
                rrect(psz, 0.5, cb_t + plug);
                translate([0, 0, -1]) rrect([psz[0] - 2 * ring, psz[1] - 2 * ring], 0.5, cb_t + plug + 2);
            }
        }
        // vent slots in the upper half (keeps the antenna area open)
        for (i = [0 : 4])
            translate([0, psz[1] / 2 - 8 - i * 4.5, -1]) rrect([psz[0] - 16, 2], 0.99, cb_t + 2);
        // cable exit at the bottom centre
        translate([-cable_notch[0] / 2, -fsz[1] / 2 - 1, -1])
            cube([cable_notch[0], cable_notch[1] + 1 + (fsz[1] - psz[1]) / 2, cb_t + plug + 2]);
    }
}

module plunger() { // head sits inside between wall and button
    cylinder(d = btn_hole + 2, h = 1);
    cylinder(d = btn_hole - 0.4, h = 1 + wall + 0.8);
}

module board_ghost() face() {
    translate([pcb_x0, bottom_margin, pcb_back]) color("green") cube([board_w, board_h, pcb_t]);
    translate([win_c[0] - glass_w / 2, win_c[1] - glass_h / 2, pcb_front])
        color("black") cube([glass_w, glass_h, glass_t]);
}

// Body printed face-down: the front lands on the bed (clean face, no inside
// supports — upright would leave a ~60 mm unsupported ceiling).
module on_face() rotate([90 + tilt, 0, 0]) children();

if (part == "assembly") {
    color("#d9d2c0") body();
    color("#cfc8b5") translate([W / 2, D, open_m + open_sz[1] / 2]) rotate([90, 0, 0]) back_cover();
    board_ghost();
} else if (part == "body") {
    on_face() body();
} else if (part == "back_cover") {
    back_cover();
} else if (part == "plunger") {
    plunger();
} else if (part == "fit_test") {
    on_face() intersection() {
        body();
        face() translate([-1, -1, pcb_back - 3]) cube([W + 2, H + 2, -pcb_back + 3]);
    }
}
