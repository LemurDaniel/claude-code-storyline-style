// NOTE:
//   Library of boxes with rounded vertical edges, without geometry of its own.
//
//   use <lib.boxes.scad>
//   box_rounded([20, 10, 5]);

//
//   Chapters:
//     ROUNDED BOXES   Solid and open boxes with rounded vertical edges.
//

DEFAULT_CORNER_RADIUS = 2;
DEFAULT_FN            = 64;

// ===========================================================================
// ============================   ROUNDED BOXES   ============================
// ===========================================================================
//
//   box_rounded        Solid box, corner at the origin.
//   box_rounded_open   Box with walls and a floor, open at the top.
//

/*
 * Creates a box with rounded vertical edges, corner at the origin.
 * The radius shrinks to half the smaller side, so the box never outgrows its size.
 *
 * Parameters:
 *   size     (Required) [x, y, z] outer size.
 *   radius   (Optional) Corner radius. Defaults to DEFAULT_CORNER_RADIUS.
 *   fn       (Optional) Resolution of the corners. Defaults to DEFAULT_FN.
 *
 * Example:
 *   box_rounded([20, 10, 5], radius = 1);
 */
module box_rounded(size, radius = DEFAULT_CORNER_RADIUS, fn = DEFAULT_FN) {
    corner_radius = min(radius, size[0] / 2, size[1] / 2);

    hull() {
        for (x = [corner_radius, size[0] - corner_radius], y = [corner_radius, size[1] - corner_radius]) {
            translate([x, y, 0])
            cylinder(r = corner_radius, h = size[2], $fn = fn);
        }
    }
}

/*
 * Creates a box_rounded with walls and a floor, open at the top, corner at the origin.
 * The inner corners follow the outer ones, so the wall keeps its thickness around them.
 *
 * Parameters:
 *   size     (Required) [x, y, z] outer size.
 *   wall     (Required) Thickness of each wall and of the floor.
 *   radius   (Optional) Outer corner radius. Defaults to DEFAULT_CORNER_RADIUS.
 *   fn       (Optional) Resolution of the corners. Defaults to DEFAULT_FN.
 *
 * Example:
 *   box_rounded_open([40, 30, 20], wall = 2);
 */
module box_rounded_open(size, wall, radius = DEFAULT_CORNER_RADIUS, fn = DEFAULT_FN) {
    inner_size   = [size[0] - wall * 2, size[1] - wall * 2, size[2]];
    inner_radius = max(radius - wall, 0.1);   // a radius of 0 would leave no cylinder to hull

    difference() {
        box_rounded(size, radius, fn);

        // Inner cut, reaches past the top face so the box is open
        translate([wall, wall, wall])
        box_rounded(inner_size, inner_radius, fn);
    }
}
