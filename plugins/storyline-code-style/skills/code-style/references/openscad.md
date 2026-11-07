# Code Style: OpenSCAD
- 4 spaces, no tabs. Modules, functions and local variables in `snake_case`, constants in `UPPER_SNAKE`. Customizer parameters in `Capital_Snake` (`Board_Width`), the Customizer shows them as `Board Width`.
  ```openscad
  // (mm) Wall thickness of the case
  Wall_Size = 2; // [1:0.5:5]

  /* [Hidden] */

  CORNER_RADIUS = 2;

  module box_rounded(size, radius = CORNER_RADIUS) { ... }
  ```
- File names follow `<kind>.<topic>[.<variant>].scad` (`case.sensor.scad`, `case.esp32.dupont.scad`, `holder.cable.scad`). Libraries without geometry of their own start with `lib.` (`lib.boxes.scad`). A folder of `.scad` files has no entry point, its shelf label is a `README.md`.
  ```
  openscad/
    README.md
    lib.boxes.scad
    case.sensor.scad
    case.sensor.wall-mount.scad
  ```
- **Chapters in the order OpenSCAD reads the file:** `SETTINGS` first, because the Customizer only offers the parameters at the top of the file. Then `HELPERS`, then the parts, and the geometry that is actually rendered only in the last chapter, the epilogue. No top-level geometry anywhere else.
  ```openscad
  //
  //   Chapters:
  //     SETTINGS        Customizer parameters, constants, dimensions and validations.
  //     HELPERS         Rounded boxes and the port cutout.
  //     CASE PARTS      Body, lid and the board preview.
  //     ASSEMBLE CASE   Places body and lid next to each other.
  //
  ```
- **SETTINGS is a collection chapter with one section per Customizer tab.** The tab marker `/* [Board] */` and the one-line comment right above a parameter belong to the Customizer UI: the comment is the label, `// [1:0.5:5]` the slider. They keep exactly that shape and are no group comments. The section banner stands above the tab marker.
  ```openscad
  // ---------------------------------------------------------------------------
  // Board
  //   Size of the board inside the case.
  // ---------------------------------------------------------------------------

  /* [Board] */

  // (mm) Board width
  Board_Width = 27.9;

  // Shape of the USB hole
  USB_Hole = "SQUARE"; // [NONE:No hole, SQUARE:Square hole, ROUND:Round hole]
  ```
- **Fixed values in a `/* [Hidden] */` section** named `Constants`, not behind a getter function. Every parameter below the marker is hidden from the Customizer.
  ```openscad
  // ---------------------------------------------------------------------------
  // Constants
  //   Fixed values, hidden from the Customizer.
  // ---------------------------------------------------------------------------

  /* [Hidden] */

  PIN_PITCH = 2.54;   // standard 0.1 inch header pitch
  WALL_SIZE = 3;      // over both sides, each wall is WALL_SIZE / 2 thick
  ```
  Not like this: `function get_defaults(name) = name == "PIN_PITCH" ? 2.54 : ...`
- **Derived sizes once, in a `Dimensions` section**, named after what they deliver (see `SKILL.md` → "Transform in named stages"). Modules read them instead of computing the same width in every part.
  ```openscad
  // Board with the clearance on each side, the walls add WALL_SIZE.
  CASE_WIDTH  = Board_Width + Clearance * 2 + WALL_SIZE;
  CASE_LENGTH = Board_Length + Clearance * 2 + WALL_SIZE;

  // Case corner in board coordinates.
  CASE_OFFSET = [-Clearance - WALL_SIZE / 2, -Clearance - WALL_SIZE / 2, 0];
  ```
- **One coordinate system, named once.** The description of SETTINGS says where the origin lies, every module doc says where its own origin is (`corner at the origin`, `centered on x and y`).
  ```openscad
  //   Coordinates: the front left corner of the board lies at x = 0, y = 0,
  //   the USB end points to -y.
  ```
- **Validations as a section at the end of SETTINGS.** `assert()` fails on settings that cannot work, the message states the expectation. A soft check only warns with `echo("WARNING: ...")` and the model still renders.
  ```openscad
  assert(
      Clearance >= 0,
      str("Clearance must be 0 or greater, got ", Clearance, ".")
  );

  // A pin row longer than the board hints at a wrong Board_Length.
  if (Pin_Count * PIN_PITCH > Board_Length) {
      echo(str("WARNING: ", Pin_Count, " pins need ", Pin_Count * PIN_PITCH, " mm, the board has ", Board_Length, " mm."));
  }
  ```
- **Every module and function gets a doc comment**: purpose, origin, parameters with `(Required)` / `(Optional)` and default, an example for a reusable helper.
  ```openscad
  /*
   * Creates a box with rounded vertical edges, corner at the origin.
   * The radius shrinks to half the smaller side, so the box never outgrows its size.
   *
   * Parameters:
   *   size     (Required) [x, y, z] outer size.
   *   radius   (Optional) Corner radius. Defaults to CORNER_RADIUS.
   *
   * Example:
   *   box_rounded([20, 10, 5], radius = 1);
   */
  ```
- **One transform per line, from the shape upwards.** OpenSCAD applies the line right above the shape first, so a comment says what the chain does when the order matters.
  ```openscad
  // Turns the tunnel axis from z to y, then moves it onto the front wall.
  translate([CASE_WIDTH / 2, CASE_OFFSET[1], USB_Z])
  rotate([90, 0, 0])
  cylinder(d = USB_Diameter, h = WALL_SIZE * 2, center = true);
  ```
- **A cut reaches past every face it cuts.** A cutter that ends exactly on a face leaves a paper-thin skin or flickers in the preview. The overlap is explicit (`-1`, `+ 2`), not hidden in a rounded number.
  ```openscad
  // Hole through the lid, one millimeter past both faces.
  translate([x, y, -1])
  cylinder(d = HOLE_DIAMETER, h = LID_THICKNESS + 2);
  ```
- **No shadowing.** A local `r = i * r` silently reads the outer `r`, the next reader cannot tell which one is meant. The local gets its own name.
  ```openscad
  for (i = [1 : 1 : 3]) {
      ring_radius = i * size * spacing;
      ...
  }
  ```
  Not like this: `for (i = [1 : 1 : 3]) { r = i * size * r; ... }`
- One resolution constant `FN` in the Tolerances tab, passed as `$fn = FN`. A part that needs another value names it (`fn = 32` for many small slots).
- **Preview-only geometry with `%`.** A board, a plug or a screw drawn as reference shows transparent in the preview (F5) and never ends up in the STL. `#` and `!` are for debugging and never committed.
  ```openscad
  // Board, preview only
  %board_preview();
  ```
- Libraries are loaded with `use <lib.boxes.scad>`, which brings modules and functions but no top-level geometry. `include` only for a file of shared constants.
  ```openscad
  use <lib.boxes.scad>
  ```
- **Verify** per `SKILL.md` → "Errors, logging, tests": render every model with `--hardwarnings`, so a warning fails the check. A library has no geometry, it is evaluated into an echo file instead. After a refactor that should not change the shape, compare volume and bounding box of the STL before and after.
  ```
  openscad --hardwarnings -o case.sensor.stl case.sensor.scad
  openscad --hardwarnings -o lib.boxes.echo lib.boxes.scad
  ```
