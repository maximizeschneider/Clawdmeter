// Clawdmeter "retro TV" desk dock for the Waveshare ESP32-C6-Touch-AMOLED-2.16.
//
// A small 60s/70s television: screen on the left behind a rounded TV window,
// a control panel on the right with two knobs and a speaker grille, splayed
// legs (the rear ones are shorter, so the screen leans back), and rabbit-ear
// antennas. The right-angle USB-C plug points right inside the case, and the
// cable leaves through a notch low on the right side near the back.
//
// Board numbers are first guesses — measure your board and fix them before
// printing (README.md). Print `part = "fit_test"` first.
//
// Parts (render one at a time, already in print orientation):
//   body        walnut   face-down, no supports
//   faceplate   cream    front-down; the two-tone look without a multi-colour printer
//   back_cover  walnut   outside-down, friction fit
//   knobs       dark     2x, decorative; pinned with a 1.75 mm filament stub
//   legs        dark     4 legs (front pair longer)
//   antenna     grey     dome + 2 printable rods (or use 2 mm metal rod)
//   plungers    any      one per side button
//   fit_test    any      thin front slice to check window/board/button fit
//
//   openscad -D 'part="body"' -o body.stl retro_tv.scad

part = "assembly"; // [assembly, body, faceplate, back_cover, knobs, legs, antenna, plungers, fit_test]

/* [Board — MEASURE THESE] */
board_w    = 56;    // PCB width
board_h    = 46;    // PCB height, USB-C edge to top edge
pcb_t      = 1.6;
glass_w    = 44;    // display glass/module outline
glass_h    = 44;
glass_t    = 1.5;   // glass standing proud of the PCB front
glass_dv   = 0;     // glass centre offset up from PCB centre
active     = 39.5;  // visible pixels (480x480 @ 2.16" ~ 38.8 mm)
back_parts = 6;     // tallest part on the PCB back

// Side buttons: [side (0 left / 1 right, seen from the front),
//                height of centre above PCB bottom edge,
//                depth of centre behind PCB front face].
// BOOT = Space/voice, KEY = Shift+Tab, PWR = cycle screens / hold to pair.
// PLACEHOLDER positions — measure your board.
buttons      = [[1, 34, 0.8], [1, 23, 0.8], [1, 12, 0.8]];
btn_protrude = 0.8;
btn_hole     = 3.2;

mic_holes = [];     // [x, z] from window centre, only if your board has front mics
mic_d     = 1.5;

/* [Case] */
tilt       = 12;    // screen lean-back, set by the leg lengths
wall       = 2.4;
front_t    = 2.4;   // front wall incl. faceplate recess
face_rec   = 1.0;   // faceplate thickness / recess depth
fp_inset   = 4;     // walnut rim around the faceplate
cr         = 7;     // corner radius of the TV body (front view)
depth      = 42;
side_gap   = 2.0;   // left: PCB edge to wall
panel_w    = 22;    // right control panel, PCB edge to wall
plug_room  = 14;    // under the PCB for the right-angle plug
top_room   = 4;
win_extra  = 3;     // window bigger than active area, shows black glass corners
win_r      = 5;     // TV-screen corner radius
fit        = 0.4;
clr        = 0.15;
cable_d    = 5.6;   // cable exit notch
leg_len    = 13;    // front legs
legs_inset = 9;

$fn = 48;
eps = 0.01;

// ---- derived ----
W  = wall + side_gap + board_w + fit + panel_w + wall;
H  = wall + plug_room + board_h + top_room + wall;
D  = depth;
x0 = wall + side_gap + fit / 2;           // PCB left edge
z0 = wall + plug_room;                    // PCB bottom edge
pcb_front = front_t + glass_t;            // y of PCB front (glass rests on the front wall)
pcb_back  = pcb_front + pcb_t;
wc   = [x0 + board_w / 2, z0 + board_h / 2 + glass_dv];   // window centre (x, z)
win  = active + win_extra;
win_right = wc[0] + win / 2;
knob_x = (win_right + W - fp_inset) / 2;
knob_z = [wc[1] + 12, wc[1] - 1];
grille_z = wc[1] - 11;
cable_z  = cr + cable_d / 2 + 1;
legs = [for (x = [legs_inset, W - legs_inset], y = [legs_inset, D - legs_inset]) [x, y]];
desk_c = -legs_inset * sin(tilt) - leg_len * cos(tilt); // desk plane: n·p = desk_c

assert(win + 0.4 < min(glass_w, glass_h), "window larger than the glass — it would fall through");
assert(D > pcb_back + back_parts + 6, "depth too small");
assert(leg_len - (D - 2 * legs_inset) * tan(tilt) > 3, "rear legs too short; raise leg_len or lower tilt");

// ---- helpers ----
module profile(off) translate([W / 2, H / 2]) offset(r = cr - off) square([W - 2 * cr, H - 2 * cr], center = true);
module yext(y0, y1, off) translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0) profile(off);
module xz_rrect(c, size, rr, y0, y1) // rounded rect in the front plane, from y0 to y1
    translate([c[0], y1, c[1]]) rotate([90, 0, 0]) linear_extrude(y1 - y0)
        offset(r = rr) square([size[0] - 2 * rr, size[1] - 2 * rr], center = true);
module ycyl(c, d, y0, y1) translate([c[0], y0, c[1]]) rotate([-90, 0, 0]) cylinder(d = d, h = y1 - y0);

// ---- body ----
module board_posts() for (s = [0, 1], z = [z0 + 5, z0 + board_h - 5]) {
    xe = s ? x0 + board_w + fit / 2 : x0 - fit / 2;
    dir = s ? 1 : -1;  // outward
    translate([0, 0, z - 3]) linear_extrude(6) {
        translate([s ? xe : xe - 1.6, front_t - eps]) square([1.6, pcb_back + 3 - front_t]);
        polygon([[xe, pcb_back + 0.1], [xe - dir * 0.6, pcb_back + 0.1], [xe, pcb_back + 2.6]]);
    }
}

function btn_x(b)  = b[0] ? x0 + board_w + btn_protrude : x0 - btn_protrude; // button tip
function btn_yz(b) = [pcb_front + b[2], z0 + b[1]];

module button_guides() for (b = buttons) if (b[0] == 1) {
    yz = btn_yz(b);
    translate([btn_x(b) + 1.6, front_t - eps, yz[1] - 3]) cube([W - wall - btn_x(b) - 1.6 + eps, yz[0] + 3 - front_t, 6]);
}

module button_holes() for (b = buttons) {
    yz = btn_yz(b);
    translate([b[0] ? btn_x(b) + 1.2 : -1, yz[0], yz[1]]) rotate([0, 90, 0])
        cylinder(d = btn_hole, h = b[0] ? W : x0);
}

module cable_cut()
    hull() {
        translate([W - wall - 1, D - 9, cable_z]) rotate([0, 90, 0]) cylinder(d = cable_d, h = wall + 2);
        translate([W - wall - 1, D - eps, cable_z - cable_d / 2]) cube([wall + 2, 1, cable_d]);
    }

module body() {
    difference() {
        union() {
            difference() {
                hull() { yext(0, 1, 1); yext(1, D - 1, 0); yext(D - 1, D, 1); }
                yext(front_t, D + 1, wall);                     // cavity
                yext(D - 1.6, D + 1, 1.2);                      // back cover counterbore
            }
            board_posts();
            button_guides();
            for (l = legs) translate([l[0], l[1], wall - eps]) cylinder(d = 8, h = 3.5);   // leg bosses
            translate([W / 2, D / 2, H - wall - 3]) cylinder(d = 8, h = 3 + eps);        // antenna boss
        }
        yext(-1, face_rec, fp_inset);                           // faceplate recess
        xz_rrect(wc, [win + 0.4, win + 0.4], win_r, -1, front_t + 1);
        for (z = knob_z) ycyl([knob_x, z], 1.9, -1, front_t + 3);  // filament pin
        for (m = mic_holes) ycyl([wc[0] + m[0], wc[1] + m[1]], mic_d, -1, front_t + 1);
        button_holes();
        cable_cut();
        for (l = legs) translate([l[0], l[1], -1]) cylinder(d = 4.2, h = 5.5 + 1);
        translate([W / 2, D / 2, H - 6]) cylinder(d = 4.2, h = 7);
    }
}

// ---- faceplate (sits in the recess, modelled in body coordinates) ----
module faceplate() difference() {
    yext(0, face_rec - 0.05, fp_inset + clr);
    xz_rrect(wc, [win, win], win_r, -1, face_rec + 1);
    for (z = knob_z) ycyl([knob_x, z], 2.3, -1, face_rec + 1);
    for (i = [0 : 3]) xz_rrect([knob_x, grille_z - i * 2.6], [12, 1.2], 0.55, -1, face_rec + 1);
    for (m = mic_holes) ycyl([wc[0] + m[0], wc[1] + m[1]], mic_d, -1, face_rec + 1);
}

// ---- back cover (body coordinates) ----
module back_cover() difference() {
    union() {
        yext(D - 1.6 + clr, D, 1.2 + clr);
        difference() {
            yext(D - 1.6 - 4, D - 1.6 + clr + eps, wall + clr);
            yext(D - 7, D, wall + clr + 1.6);
        }
    }
    for (i = [0 : 4]) xz_rrect([W / 2, H - 14 - i * 4.5], [W - 24, 2], 0.99, D - 3, D + 1);
    hull() cable_cut();
    translate([W - wall - 4, D - 8, cable_z - cable_d / 2 - 1]) cube([5, 9, cable_d + 2]);
}

// ---- small parts ----
module knob() { // printed back-down; a 1.75 mm filament stub is the pin
    difference() {
        union() { cylinder(d = 9, h = 3); translate([0, 0, 3]) cylinder(d1 = 9, d2 = 8, h = 0.6); }
        for (a = [0 : 30 : 359]) rotate([0, 0, a]) translate([4.7, 0, -1]) cylinder(d = 1, h = 5, $fn = 12);
        translate([0, 0, -1]) cylinder(d = 1.9, h = 3.5, $fn = 16);
    }
    translate([-0.6, 0, 3.5]) cube([1.2, 3.6, 0.6]);     // pointer ridge
}

module leg_raw(l) {
    sx = l[0] < W / 2 ? -1 : 1; sy = l[1] < D / 2 ? -1 : 1;
    translate([l[0], l[1], -eps]) cylinder(d = 4.0, h = 5);              // peg
    intersection() {
        hull() {
            translate([l[0], l[1], 0]) cylinder(d = 6, h = eps);
            translate([l[0] + sx * 5, l[1] + sy * 3, -30]) sphere(d = 3);
        }
        rotate([tilt, 0, 0]) translate([-500, -500, desk_c]) cube(1000);
    }
}

module antenna_dome() {
    difference() {
        scale([1, 1, 0.55]) sphere(d = 14);
        translate([0, 0, -10]) cube(20, center = true);
        for (s = [-1, 1]) rotate([0, s * 28, 0]) translate([0, 0, 1]) cylinder(d = 2.2, h = 10);
    }
    translate([0, 0, -4.5]) cylinder(d = 4.0, h = 4.5 + eps);
}
module antenna_rod() rotate([0, 90, 0]) rotate([0, 0, 30]) cylinder(d = 2.3, h = 38, $fn = 6);

module plunger(len) { cylinder(d = btn_hole + 2, h = 1); cylinder(d = btn_hole - 0.4, h = 1 + len); }
function plunger_len(b) = b[0] ? W + 0.8 - (btn_x(b) + 1) : (btn_x(b) - 1) + 0.8;

// ---- preview-only fake screen ----
module ui() {
    module slab(c, s, rr, t, y) xz_rrect(c, s, rr, y, y + t);
    color("#0b0b0b") slab([0, 0], [glass_w, glass_h], 2, 0.4, 0);
    for (i = [0, 1]) let(z = 9 - i * 16, f = [0.62, 0.35][i]) {
        color("#f2efe6") slab([-11, z + 6], [14, 1.6], 0.4, 0.1, -0.1);
        color("#333")    slab([0, z], [32, 4], 1.9, 0.1, -0.1);
        color("#d97757") slab([-16 + 16 * f, z], [32 * f, 4], 1.9, 0.1, -0.2);
    }
}

module tv_assembly() {
    color("#7a4a2c") body();
    color("#e9e2d0") faceplate();
    color("#6e4226") back_cover();
    translate([wc[0], front_t, wc[1]]) ui();
    for (z = knob_z) color("#3a2a20") translate([knob_x, 0, z]) rotate([90, 0, 0]) knob();
    for (l = legs) color("#3a2a20") leg_raw(l);
    color("#9aa0a6") translate([W / 2, D / 2, H]) {
        antenna_dome();
        for (s = [-1, 1]) rotate([0, s * 28, 0]) translate([0, 0, 1]) cylinder(d = 2.3, h = 38, $fn = 6);
    }
}

if (part == "assembly") {
    translate([0, 0, -desk_c]) rotate([-tilt, 0, 0]) tv_assembly();
} else if (part == "body") {
    rotate([90, 0, 0]) body();
} else if (part == "faceplate") {
    rotate([90, 0, 0]) faceplate();
} else if (part == "back_cover") {
    translate([0, 0, D]) rotate([-90, 0, 0]) back_cover();
} else if (part == "knobs") {
    for (i = [0, 1]) translate([i * 12, 0, 0]) knob();
} else if (part == "legs") {
    for (i = [0 : 3]) let(l = legs[i])
        translate([i * 14 - l[0], -l[1] * cos(tilt), -desk_c]) rotate([-tilt, 0, 0]) leg_raw(l);
} else if (part == "antenna") {
    translate([0, 0, 4.5]) antenna_dome();
    for (i = [0, 1]) translate([-19, 12 + i * 5, 2.3 * cos(30) / 2]) antenna_rod();
} else if (part == "plungers") {
    for (i = [0 : len(buttons) - 1]) translate([i * 8, 0, 0]) plunger(plunger_len(buttons[i]));
} else if (part == "fit_test") {
    rotate([90, 0, 0]) intersection() {
        body();
        translate([-1, -1, -1]) cube([W + 2, pcb_back + 4, H + 2]);
    }
}
