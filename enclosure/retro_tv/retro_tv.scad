// Clawdmeter "retro TV" desk dock for the Waveshare ESP32-C6-Touch-AMOLED-2.16
// (the finished device in its white 45 x 45 x 22 mm shell).
//
// A small 60s/70s television: screen on the left behind a rounded TV window,
// a control panel on the right with two knobs and a speaker grille, four
// splayed legs (set `tilt` > 0 to shorten the rear pair and lean the screen
// back), and rabbit-ear antennas.
//
// The device sits turned a quarter turn: USB-C faces RIGHT (the right-angle
// plug hides behind the control panel) and the three buttons face LEFT
// (pressed through the left side of the TV with printed plungers). Its
// speaker grille faces UP, and slots in the TV's top let the sound out. The
// firmware's IMU auto-rotation shows the picture upright.
// Four corner brackets centre the device; two pressers on the back cover push
// it against the front lip. The cable loops round onto the device's back and
// leaves through the back cover's bottom corner on the button side (bottom
// right seen from behind).
//
// Parts (render one at a time, already in print orientation):
//   body        walnut   face-down, no supports
//   faceplate   cream    front-down; the two-tone look without a multi-colour printer
//   back_cover  walnut   outside-down, friction fit
//   knobs       dark     2x, decorative; pinned with a 1.75 mm filament stub
//   legs        dark     4 legs (rear pair shorter when tilt > 0)
//   antenna     grey     dome + 2 printable rods (or use 2 mm metal rod)
//   plungers    walnut   one per button, body-coloured so they blend in
//   fit_test    any      front slice: window, corner brackets, button holes
//
//   openscad -D 'part="body"' -o body.stl retro_tv.scad

part = "assembly"; // [assembly, plate, fit_test, body, faceplate, back_cover, knobs, legs, antenna, plungers, dims]

/* [Device — measured as mounted (USB-C right, buttons left, speaker up)] */
dev_w        = 45;     // shell width
dev_h        = 45;     // shell height
dev_d        = 22;     // shell depth, glass to back
glass        = 43;     // glass outline (1 mm white rim all round)
btn_z        = [12.5, 22.5, 32.5];  // button centres, from the bottom of the device
btn_y        = 9.5;    // button centre behind the front face (shell rim)
btn_protrude = 1.0;    // how far the buttons stick out of the shell
btn_size     = [6, 4]; // the device's pill-shaped buttons: length along the edge, width; the pins match it
btn_clr      = 0.4;    // pin-to-hole clearance (total)
usb_y        = 11;     // USB-C centre behind the front face (middle of the depth)
plug_len     = 14;     // right-angle plug head, from the shell to its far side
spk_y        = 11;     // speaker grille centre behind the front face
active       = 38.8;   // visible pixels (480x480 @ 2.16")

/* [Case] */
tilt       = 0;     // screen lean-back, set by the leg lengths (0 = upright like a real TV)
wall       = 2.4;
front_t    = 2.4;   // front wall incl. faceplate recess
face_rec   = 1.0;   // faceplate thickness / recess depth
fp_inset   = 4;     // walnut rim around the faceplate
cr         = 7;     // corner radius of the TV body (front view)
panel_w    = 22;    // right control panel (plug lives behind it)
cable_lane = 12;    // room behind the device: the cable's loop round onto the device's back sticks out ~7-9 mm, plus slack
top_room   = 3;
bottom_room = 3;
win_r      = 5;     // TV-screen corner radius
fit        = 0.6;   // total clearance around the device
clr        = 0.15;
pad        = 1.5;   // gap between back-cover pressers and the device: stick a felt/rubber pad here
cable_d    = 5.6;   // cable exit hole
leg_len    = 13;    // front legs
legs_inset = 9;

$fn = 48;
eps = 0.01;

// ---- derived ----
side_gap = btn_protrude + 1 + 0.4;         // left: button + plunger head
W  = wall + side_gap + dev_w + fit + panel_w + wall;
H  = wall + bottom_room + dev_h + fit + top_room + wall;
D  = front_t + dev_d + cable_lane + 1.6;
x0 = wall + side_gap + fit / 2;            // device left face
z0 = wall + bottom_room + fit / 2;         // device bottom face
dev_back = front_t + dev_d;
wc   = [x0 + dev_w / 2, z0 + dev_h / 2];   // window centre (x, z)
win  = glass - 1;                          // stays inside the glass: no white rim shows
win_right = wc[0] + win / 2;
knob_x = (win_right + W - fp_inset) / 2;
knob_z = [wc[1] + 12, wc[1] - 1];
grille_z = wc[1] - 11;
usb_z    = wc[1];
legs = [for (x = [legs_inset, W - legs_inset], y = [legs_inset, D - legs_inset]) [x, y]];
desk_c = -legs_inset * sin(tilt) - leg_len * cos(tilt); // desk plane: n·p = desk_c
ant_y  = D - 6.5;                          // antenna behind the speaker slots

assert(win > active, "window smaller than the picture");
assert(panel_w >= plug_len + 4, "panel_w too small for the plug");
assert(leg_len - (D - 2 * legs_inset) * tan(tilt) > 3, "rear legs too short; raise leg_len or lower tilt");

// ---- helpers ----
module profile(off) translate([W / 2, H / 2]) offset(r = cr - off) square([W - 2 * cr, H - 2 * cr], center = true);
module yext(y0, y1, off) translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0) profile(off);
module xz_rrect(c, size, rr, y0, y1) // rounded rect in the front plane, from y0 to y1
    translate([c[0], y1, c[1]]) rotate([90, 0, 0]) linear_extrude(y1 - y0)
        offset(r = rr) square([size[0] - 2 * rr, size[1] - 2 * rr], center = true);
module ycyl(c, d, y0, y1) translate([c[0], y0, c[1]]) rotate([-90, 0, 0]) cylinder(d = d, h = y1 - y0);

// ---- body ----
// L-shaped brackets at the device's four corners centre it in the window.
module corner_brackets() for (sx = [0, 1], sz = [0, 1]) {
    cx = sx ? x0 + dev_w + fit / 2 : x0 - fit / 2;
    cz = sz ? z0 + dev_h + fit / 2 : z0 - fit / 2;
    dx = sx ? 1 : -1; dz = sz ? 1 : -1;  // outward
    translate([0, front_t - eps, 0]) {
        translate([sx ? cx : cx - 1.2, 0, sz ? cz - 7 : cz - 1.2]) cube([1.2, 5, 8.2]);
        translate([sx ? cx - 7 : cx - 1.2, 0, sz ? cz : cz - 1.2]) cube([8.2, 5, 1.2]);
    }
}

// Pill (stadium) outline, long axis along y of the 2D plane.
module pill(size) hull() for (s = [-1, 1])
    translate([0, s * (size[0] - size[1]) / 2]) circle(d = size[1]);

// Holes in the left wall: same pill shape as the device's buttons.
module button_holes() for (z = btn_z)
    translate([-1, front_t + btn_y, z0 + z]) rotate([0, 90, 0]) rotate([0, 0, 90])
        linear_extrude(x0) pill(btn_size + [btn_clr, btn_clr]);

// Speaker slots in the top, over the device's speaker grille.
module speaker_slots() for (i = [-2 : 2])
    translate([wc[0] - 8, front_t + spk_y + i * 2.6 - 0.6, H - wall - 1]) cube([16, 1.2, wall + 2]);

// Cable exit through the back, in the bottom corner on the button side
// (bottom right when you look at the back). In the cover it is a notch open
// to the corner, so the cover goes on over a plugged-in cable; the body's
// back rim closes it.
cable_rc = cr - 1.2 - cable_d / 2 - 0.4;            // from the corner's arc centre
cable_x  = cr - cable_rc * cos(45);
cable_z  = cr - cable_rc * sin(45);
module cable_cut() ycyl([cable_x, cable_z], cable_d, D - 6, D + 1);

module body() {
    difference() {
        union() {
            difference() {
                hull() { yext(0, 1, 1); yext(1, D - 1, 0); yext(D - 1, D, 1); }
                yext(front_t, D + 1, wall);                     // cavity
                yext(D - 1.6, D + 1, 1.2);                      // back cover counterbore
            }
            corner_brackets();
            for (l = legs) translate([l[0], l[1], wall - eps]) cylinder(d = 8, h = 3.5);   // leg bosses
            translate([W / 2, ant_y, H - wall - 3]) cylinder(d = 8, h = 3 + eps);        // antenna boss
        }
        yext(-1, face_rec, fp_inset);                           // faceplate recess
        xz_rrect(wc, [win, win], win_r, -1, front_t + 1);
        for (z = knob_z) ycyl([knob_x, z], 1.9, -1, front_t + eps);  // filament pin
        button_holes();
        speaker_slots();
        cable_cut();
        for (l = legs) translate([l[0], l[1], -1]) cylinder(d = 4.2, h = 5.5 + 1);
        translate([W / 2, ant_y, H - 6]) cylinder(d = 4.2, h = 7);
    }
}

// ---- faceplate (sits in the recess, modelled in body coordinates) ----
module faceplate() difference() {
    yext(0, face_rec - 0.05, fp_inset + clr);
    xz_rrect(wc, [win, win], win_r, -1, face_rec + 1);
    for (z = knob_z) ycyl([knob_x, z], 2.3, -1, face_rec + 1);
    for (i = [0 : 3]) xz_rrect([knob_x, grille_z - i * 2.6], [12, 1.2], 0.55, -1, face_rec + 1);
}

// ---- back cover (body coordinates) ----
module back_cover() difference() {
    union() {
        yext(D - 1.6 + clr, D, 1.2 + clr);
        // two pressers that hold the device against the front lip (via a pad);
        // high up, so they stay clear of the cable sweeping down along the back
        for (dx = [-12, 12]) translate([wc[0] + dx - 3, dev_back + pad, z0 + dev_h - 14])
            cube([6, D - 1.6 + clr + eps - dev_back - pad, 10]);
        difference() {
            yext(D - 1.6 - 4, D - 1.6 + clr + eps, wall + clr);
            yext(D - 7, D, wall + clr + 1.6);
        }
    }
    for (i = [0 : 4]) xz_rrect([W / 2, H - 14 - i * 4.5], [W - 24, 2], 0.99, D - 3, D + 1);
    hull() {
        ycyl([cable_x, cable_z], cable_d, D - 8, D + 1);
        ycyl([cable_x - 6, cable_z - 6], cable_d, D - 8, D + 1);
    }
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

// Button pin, printed head-down: the pill shaft is the size of the device's
// button and fills its hole; the wider head inside keeps it from falling out.
module plunger(len) {
    linear_extrude(1) pill(btn_size + [2, 2]);
    linear_extrude(1 + len) pill(btn_size);
}
function plunger_len(b) = (x0 - btn_protrude - 1) + 0.8;

// ---- preview-only fake screen ----
module ui() {
    module slab(c, s, rr, t, y) xz_rrect(c, s, rr, y, y + t);
    color("#0b0b0b") slab([0, 0], [glass, glass], 3, 0.4, 0);
    for (i = [0, 1]) let(z = 9 - i * 16, f = [0.62, 0.35][i]) {
        color("#f2efe6") slab([-11, z + 6], [14, 1.6], 0.4, 0.1, -0.1);
        color("#333")    slab([0, z], [32, 4], 1.9, 0.1, -0.1);
        color("#d97757") slab([-16 + 16 * f, z], [32 * f, 4], 1.9, 0.1, -0.2);
    }
}

// Preview colours (filament colours to choose); override with -D, e.g.
// -D 'col_body="#222"'.
col_body  = "#7a4a2c";   // body, back cover, button pins
col_face  = "#e9e2d0";   // front panel
col_dark  = "#3a2a20";   // knobs, legs
col_ant   = "#9aa0a6";   // antenna

module tv_assembly() {
    color(col_body) body();
    color(col_face) faceplate();
    color(col_body) back_cover();
    translate([wc[0], front_t + 0.5, wc[1]]) ui();
    color("#f4f4f2") translate([x0, front_t + 1, z0]) cube([dev_w, dev_d - 1, dev_h]);  // the device
    for (z = knob_z) color(col_dark) translate([knob_x, 0, z]) rotate([90, 0, 0]) knob();
    for (l = legs) color(col_dark) leg_raw(l);
    color(col_ant) translate([W / 2, ant_y, H]) {
        antenna_dome();
        for (s = [-1, 1]) rotate([0, s * 28, 0]) translate([0, 0, 1]) cylinder(d = 2.3, h = 38, $fn = 6);
    }
}

// Each part in its print orientation, lying on the bed (z = 0).
module print_part(name) {
    if (name == "body") {
        rotate([90, 0, 0]) body();                 // y: -H .. 0
    } else if (name == "faceplate") {
        rotate([90, 0, 0]) faceplate();
    } else if (name == "back_cover") {
        translate([0, 0, D]) rotate([-90, 0, 0]) back_cover();   // y: 0 .. H
    } else if (name == "knobs") {
        for (i = [0, 1]) translate([i * 12, 0, 0]) knob();
    } else if (name == "legs") {
        for (i = [0 : 3]) let(l = legs[i])
            translate([i * 14 - l[0], -l[1] * cos(tilt), -desk_c]) rotate([-tilt, 0, 0]) leg_raw(l);
    } else if (name == "antenna") {
        translate([0, 0, 4.5]) antenna_dome();
        for (i = [0, 1]) translate([-19, 12 + i * 5, 2.3 * cos(30) / 2]) antenna_rod();
    } else if (name == "plungers") {
        for (i = [0 : len(btn_z) - 1]) translate([i * (btn_size[1] + 4), 0, 0]) plunger(plunger_len(0));
    } else if (name == "fit_test") {
        rotate([90, 0, 0]) intersection() {
            body();
            translate([-1, -1, -1]) cube([W + 2, front_t + btn_y + 4, H + 2]);
        }
    }
}

// Print plates: one plate per filament colour. A colour scheme decides which
// groups share a colour, so a plate takes a list of groups:
//   "main" = body + back cover + button pins (pins are body-coloured)
//   "face" = front panel, "dark" = knobs + legs, "ant" = antenna dome + rods
// "main" sits at the origin; the small groups stack in a column to its
// right. Everything fits a 180 x 180 mm bed.
roles = ["main"];

module group(name) {   // each group with its footprint's min corner at (0, 0)
    if (name == "main") translate([0, 61.4, 0]) {
        translate([0, -5, 0]) print_part("body");
        print_part("back_cover");
        translate([W + 8, 4, 0]) print_part("plungers");
    }
    if (name == "face") translate([-4.2, 52.2, 0]) print_part("faceplate");
    if (name == "dark") {
        translate([4.5, 4.5, 0]) print_part("knobs");
        translate([4.5, 16, 0]) print_part("legs");
    }
    if (name == "ant") translate([19, 7, 0]) print_part("antenna");
}
group_h = [["face", 48.1], ["dark", 19.7], ["ant", 25.1]];

module plate(groups) {
    has = function(g) len([for (x = groups) if (x == g) 1]) > 0;
    if (has("main")) group("main");
    col_x = has("main") ? 108 : 0;
    small = [for (g = group_h) if (has(g[0])) g];
    for (i = [0 : len(small) - 1])
        translate([col_x, i == 0 ? 0 : sum_h(small, i) + 6 * i, 0]) group(small[i][0]);
}
function sum_h(list, n) = n <= 0 ? 0 : list[n - 1][1] + sum_h(list, n - 1);

if (part == "assembly") {
    translate([0, 0, -desk_c]) rotate([-tilt, 0, 0]) tv_assembly();
} else if (part == "dims") {
    echo(str("body W x H x D = ", W, " x ", H, " x ", D, " mm; with legs + antennas: height ", H - desk_c + 38 * cos(28) + 1, " mm"));
} else if (part == "plate") {
    plate(roles);
} else {
    print_part(part);
}
