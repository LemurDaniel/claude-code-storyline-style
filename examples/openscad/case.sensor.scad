// NOTE:
//   Case for a small sensor board: an open box with four corner posts the board
//   rests on, a round cable hole in the front wall and a press-fit lid with vent slots.
//
//   Requires: lib.boxes.scad in the same folder.
//
//   Open in OpenSCAD, set the board in the Customizer, check the transparent board
//   in the preview (F5), render (F6), export STL.
//
//   openscad -o case.sensor.stl -D Board_Width=30 case.sensor.scad

//
//   Chapters:
//     SETTINGS        Customizer parameters, constants, dimensions and validations.
//     HELPERS         Corner posts and vent slots.
//     CASE PARTS      Body, lid and the board preview.
//     ASSEMBLE CASE   Places body and lid next to each other.
//

use <lib.boxes.scad>

// ===========================================================================
// ==============================   SETTINGS   ===============================
// ===========================================================================
//
//   Board         Size of the board and its clearance to the walls.
//   Cable         Round hole in the front wall.
//   Tolerances    Print tolerance and resolution.
//   Constants     Fixed values, hidden from the Customizer.
//   Dimensions    Case and lid size derived from the settings above.
//   Validations   Fails early on settings that cannot work.
//
//   Coordinates: the front left corner of the board lies at x = 0, y = 0, the
//   cable leaves to -y. The lid is built at its own origin and placed in
//   ASSEMBLE CASE.
//

// ---------------------------------------------------------------------------
// Board
//   Size of the board and its clearance to the walls.
// ---------------------------------------------------------------------------

/* [Board] */

// (mm) Board width
Board_Width = 25; // [10:0.5:100]

// (mm) Board length
Board_Length = 35; // [10:0.5:100]

// (mm) Thickness of the PCB
Board_Thickness = 1.6;

// (mm) Height of the tallest part on top of the board
Board_Top_Height = 4; // [0:0.5:30]

// (mm) Clearance between board and walls
Clearance = 1; // [0:0.1:5]

// ---------------------------------------------------------------------------
// Cable
//   Round hole in the front wall.
// ---------------------------------------------------------------------------

/* [Cable] */

// (mm) Diameter of the cable
Cable_Diameter = 4; // [2:0.5:12]

// (mm) Center of the cable hole, from the bottom of the case
Cable_Height = 4.5; // [2:0.5:40]

// ---------------------------------------------------------------------------
// Tolerances
//   Print tolerance and resolution.
// ---------------------------------------------------------------------------

/* [Tolerances] */

// (mm) Print tolerance for holes and the lid
PRINT_TOLERANCE = 0.2;

// Resolution of round shapes ($fn)
FN = 64;

// ---------------------------------------------------------------------------
// Constants
//   Fixed values, hidden from the Customizer.
// ---------------------------------------------------------------------------

/* [Hidden] */

// Case
WALL_SIZE     = 2;   // each wall and the floor
POST_SIZE     = 4;   // square corner posts under the board
POST_HEIGHT   = 5;   // free space under the board for solder joints

// Lid
LID_THICKNESS = 2;
RIM_HEIGHT    = 3;   // rim of the lid that sits inside the walls
VENT_WIDTH    = 1.5;
VENT_SPACING  = 4;
VENT_MARGIN   = 6;   // free lid border around the vent slots

// Print bed
LID_GAP       = 10;  // gap between body and lid

// ---------------------------------------------------------------------------
// Dimensions
//   Case and lid size derived from the settings above.
// ---------------------------------------------------------------------------

// Heights: floor, posts, board, tallest part.
FLOOR_TOP = WALL_SIZE;
BOARD_Z   = FLOOR_TOP + POST_HEIGHT;

// Inside: the board with its clearance, as high as the tallest part.
INSIDE_SIZE = [
    Board_Width + Clearance * 2,
    Board_Length + Clearance * 2,
    POST_HEIGHT + Board_Thickness + Board_Top_Height
];

// The walls add WALL_SIZE on each side, the floor once below.
CASE_SIZE   = INSIDE_SIZE + [WALL_SIZE * 2, WALL_SIZE * 2, WALL_SIZE];
CASE_OFFSET = [-Clearance - WALL_SIZE, -Clearance - WALL_SIZE, 0];

// The rim of the lid is one print tolerance smaller than the inside on each side.
RIM_SIZE = [INSIDE_SIZE[0] - PRINT_TOLERANCE * 2, INSIDE_SIZE[1] - PRINT_TOLERANCE * 2, RIM_HEIGHT];

// Body and lid side by side.
LAYOUT_WIDTH = CASE_SIZE[0] * 2 + LID_GAP;

// ---------------------------------------------------------------------------
// Validations
//   Fails early on settings that cannot work.
// ---------------------------------------------------------------------------

// Two posts side by side must stay narrower than the board.
assert(
    POST_SIZE * 2 < min(Board_Width, Board_Length),
    str("Board_Width and Board_Length must be greater than ", POST_SIZE * 2, " mm, got ", [Board_Width, Board_Length], ".")
);

// The cable hole must lie between floor and top of the front wall.
assert(
    Cable_Height - Cable_Diameter / 2 >= FLOOR_TOP && Cable_Height + Cable_Diameter / 2 <= CASE_SIZE[2],
    str("Cable_Height must keep the hole between ", FLOOR_TOP + Cable_Diameter / 2, " and ", CASE_SIZE[2] - Cable_Diameter / 2, " mm, got ", Cable_Height, ".")
);

// Soft check: only warns in the console, the case still renders.
if (Cable_Height + Cable_Diameter / 2 > BOARD_Z) {
    echo(str("WARNING: the cable hole reaches above the board underside at ", BOARD_Z, " mm, check that no part sits there."));
}

// ===========================================================================
// ===============================   HELPERS   ===============================
// ===========================================================================
//
//   corner_posts   Four posts under the board corners.
//   vent_slots     Slots through the lid, centered on it.
//

/*
 * Creates four square posts under the corners of the board, in board coordinates.
 * They sink one millimeter into the floor, so the union with the body is solid.
 */
module corner_posts() {
    for (x = [0, Board_Width - POST_SIZE], y = [0, Board_Length - POST_SIZE]) {
        translate([x, y, FLOOR_TOP - 1])
        cube([POST_SIZE, POST_SIZE, POST_HEIGHT + 1]);
    }
}

/*
 * Creates the vent slots through the lid, in lid coordinates. The slots run along x,
 * keep VENT_MARGIN to every edge and are centered along y.
 *
 *   slot_length   Lid width without both margins.
 *   count         Slots that fit between both margins.
 *   first_y       Start of the first slot, so the row is centered.
 */
module vent_slots() {
    slot_length = CASE_SIZE[0] - VENT_MARGIN * 2;
    count       = floor((CASE_SIZE[1] - VENT_MARGIN * 2 - VENT_WIDTH) / VENT_SPACING) + 1;
    first_y     = (CASE_SIZE[1] - VENT_WIDTH - (count - 1) * VENT_SPACING) / 2;

    for (i = [0 : 1 : count - 1]) {
        // One millimeter past both faces of the lid
        translate([VENT_MARGIN, first_y + i * VENT_SPACING, -1])
        box_rounded([slot_length, VENT_WIDTH, LID_THICKNESS + 2], radius = VENT_WIDTH / 2, fn = 16);
    }
}

// ===========================================================================
// =============================   CASE PARTS   ==============================
// ===========================================================================
//
//   case_body       Open box with the cable hole and the corner posts.
//   case_lid        Plate with a rim that presses into the walls.
//   board_preview   Transparent board and its tallest part, preview only.
//

/*
 * Creates the body in board coordinates: the open box, the cable hole through the
 * middle of the front wall and the corner posts.
 */
module case_body() {
    difference() {
        translate(CASE_OFFSET)
        box_rounded_open(CASE_SIZE, WALL_SIZE);

        // Turns the hole axis from z to y, then centers it in the front wall.
        translate([Board_Width / 2, CASE_OFFSET[1] + WALL_SIZE / 2, Cable_Height])
        rotate([90, 0, 0])
        cylinder(d = Cable_Diameter + PRINT_TOLERANCE, h = WALL_SIZE + 2, center = true, $fn = FN);
    }

    corner_posts();
}

/*
 * Creates the lid at its own origin, printed upside down: a plate as large as the
 * case and a rim that presses into the walls, with the vent slots through both.
 */
module case_lid() {
    rim_wall = WALL_SIZE;

    difference() {
        union() {
            box_rounded([CASE_SIZE[0], CASE_SIZE[1], LID_THICKNESS]);

            // Rim, sinks one millimeter into the plate so the union is solid
            translate([WALL_SIZE + PRINT_TOLERANCE, WALL_SIZE + PRINT_TOLERANCE, LID_THICKNESS - 1])
            difference() {
                box_rounded(RIM_SIZE + [0, 0, 1]);

                translate([rim_wall, rim_wall, -1])
                box_rounded([RIM_SIZE[0] - rim_wall * 2, RIM_SIZE[1] - rim_wall * 2, RIM_SIZE[2] + 3]);
            }
        }

        vent_slots();
    }
}

/*
 * Creates the board and a block for its tallest part, in board coordinates.
 * Used with the % modifier in ASSEMBLE CASE, so it shows in the preview (F5)
 * and never ends up in the STL.
 */
module board_preview() {
    // Board
    translate([0, 0, BOARD_Z])
    cube([Board_Width, Board_Length, Board_Thickness]);

    // Tallest part, over the middle of the board
    translate([Board_Width * 0.25, Board_Length * 0.25, BOARD_Z + Board_Thickness])
    cube([Board_Width * 0.5, Board_Length * 0.5, Board_Top_Height]);
}

// ===========================================================================
// ============================   ASSEMBLE CASE   ============================
// ===========================================================================
//
//   1. Layout   Places body and lid side by side, centered on the print bed.
//

// ---------------------------------------------------------------------------
// Layout
//   Places body and lid side by side, centered on the print bed.
// ---------------------------------------------------------------------------

translate([-CASE_OFFSET[0] - LAYOUT_WIDTH / 2, -CASE_OFFSET[1] - CASE_SIZE[1] / 2, 0]) {
    case_body();

    // Board, preview only
    %board_preview();

    // Lid, LID_GAP next to the body
    translate([CASE_OFFSET[0] + CASE_SIZE[0] + LID_GAP, CASE_OFFSET[1], 0])
    case_lid();
}
