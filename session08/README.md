# Session 08: Designing for 3D Printing with TinkerCAD

Today we will talk about use cases for 3d printing alongside physical computing projects. In particular we will design custom extensions for potentiometers so that they are more easily adjustable and visually customizable. We will do this using the minimal but effective free online tool [TinkerCAD](https://www.tinkercad.com).

## Show and Tell

- A stepper motor filament spool - a real printed part doing real mechanical work
- A project box with a printed potentiometer knob.

Hold them. Look at the layer lines. Notice the D-shaped hole in the knob. That's the whole lesson in one object.

## What Is 3D Printing?

A 3D printer is essentially a very precise hot glue gun on a robot arm. It melts plastic filament (usually PLA) and deposits it layer by layer, building up a shape from the bottom. The process is called **FDM** - Fused Deposition Modeling.

Key things to internalize early:

| Fact | Why it matters |
|---|---|
| Parts are built in layers (~0.2mm each) | Horizontal holes print cleanly; vertical holes need supports |
| Overhangs past ~45° need supports | Design with this in mind or you'll print a mess |
| Print time is real | A small knob: ~20 min. A full enclosure: hours. |
| Tolerances are loose (~0.2-0.4mm) | Holes need to be slightly larger than the shaft they'll receive |

<p>
  <img src="supports2.png" alt="a demonstration of why 3d printed supports are necessary" width="400">
  <br>
  <em>Supports holding up an otherwise open hole.</em>
</p>

<p>
  <img src="supports.webp" alt="a demonstration of why 3d printed supports are necessary" width="400">
  <br>
  <em>Supports holding up a complex print.</em>
</p>

## Before we begin - Start print

Because 3d printing takes time, we will work backwards today: I will first start a print so that we can all see how it works before we begin modeling. (Sorry for the noise!)


## TinkerCAD Interface

TinkerCAD runs in the browser at [tinkercad.com](https://www.tinkercad.com). Create a free account, click Create → 3D Design.

### The Three Panels

- **Left**: your shape library (Basic Shapes, plus community imports)
- **Center**: the workplane - your canvas
- **Right**: nothing much, but the Inspector pops up top-right when you select something

### Controls - Learn These Before Anything Else

| Action | How |
|---|---|
| **Orbit** (rotate view) | Right-click + drag |
| **Pan** | Middle-click + drag (or hold Shift + right-click drag) |
| **Zoom** | Scroll wheel |
| **Frame selected** | **F** |
| **Drop to workplane** | **D** - no icon for this, you must use the key. Use it constantly. |
| **Duplicate in place** | **Ctrl+D** |
| **Group** | **Ctrl+G** |
| **Ungroup** | **Ctrl+Shift+G** |
| **Undo** | **Ctrl+Z** |
| **Nudge** | Arrow keys (1mm), Shift+Arrow (10mm) |
| **Home view** | **Home** key |
| **Scale** | Drag white corner handles (hold **Shift** to scale uniformly) |
| **Scale from center** | Hold **Alt** while scaling |

> **The D key is the most-forgotten thing in TinkerCAD.** When you drag a shape onto the workplane it often floats in mid-air. Press **D** and it snaps down to the surface. Do this every time you place a shape.

## Basic Shapes

Shapes live in the left panel. Drag any shape onto the workplane, then press **D** to drop it to the surface. Every shape can be resized, repositioned, and toggled between solid and hole.

| Shape | What it is |
|---|---|
| **Box** | A rectangular solid — the workhorse. Use it for bodies, tabs, cutouts, and flat features. All six faces are flat, so it prints cleanly in any orientation. |
| **Cylinder** | A round solid with flat top and bottom. Use it for shaft holes, rounded posts, and any feature with circular cross-section. Resize the two radius handles independently to make an oval. |
| **Scribble** | A freehand draw tool. Sketch a 2D outline and TinkerCAD extrudes it into a solid. Useful for organic shapes, logos, or anything that doesn't fit a primitive. Results can be unpredictable — keep outlines simple and avoid self-intersecting lines. |

### Positive vs. Negative

Every shape in TinkerCAD is either a **solid** or a **hole** — this is the core concept behind all modeling here.

| Type | What it does |
|---|---|
| **Positive shape (solid)** | The default. Adds material. Shown in color. When grouped, it becomes part of the finished object. |
| **Negative shape (hole)** | Subtracts material. Toggle any shape to a hole in the Inspector — it turns translucent red/grey. On its own it does nothing. Group it with a solid and TinkerCAD punches it through. |

> A hole shape must be **grouped** with a solid before it cuts anything. `Ctrl+G` is what executes the boolean operation — until then, the hole is just floating geometry.


## Project 1: Coffee Cup (~25 minutes)

A simple mug: a hollow cylinder body with a handle. You'll learn: placing and sizing shapes, making a cavity with a hole, and the trickier skill of positioning the handle precisely using the ruler and midpoint mode.
<p>
  <img src="coffee-cup.png" alt="a simple mug with a handle" width="400">
  <br>
  <em>A simple mug with a handle, as modeled in TinkerCAD.</em>
</p>



### What You're Building

An outer cylinder for the body, a shorter cylinder hole for the cavity, and a torus for the handle — cut in half so the flat face sits flush against the cup wall. The handle alignment is where most people get stuck, and it's the thing worth learning.

### Step-by-Step

**1. The outer body**
- Drag a **Cylinder** onto the workplane. Press **D**.
- Set: **Diameter 60mm, Height 70mm**.

**2. The inner cavity**
- Drag another **Cylinder** onto the workplane. Press **D**.
- Set: **Diameter 52mm, Height 65mm** (narrower and shorter than the body — this leaves a 4mm wall and a solid base).
- Toggle it to **Hole** in the Inspector.
- Use the **Align tool** (**L** with both selected) to center it on both X and Y axes.
- Group both (**Ctrl+G**). The cup is now hollow.

**3. The handle**
- Drag a **Torus** onto the workplane. Press **D**.
- Set: **Outer diameter ~30mm, Tube diameter ~8mm**. This is approximate — adjust to taste.
- The torus is a full ring. You need to cut it in half so the flat face can sit against the cup wall. Drag a **Box** onto the workplane, size it larger than half the torus (e.g. **W 40mm, L 40mm, H 40mm**), toggle it to **Hole**, and position it to slice off exactly half the ring.

> **Getting the cut centered**: This is where precision matters. Click the box hole, then press **E** (or click the ruler icon in the toolbar) to activate the **Ruler**. Click the ruler to place it at the midpoint of the torus. With the ruler placed, the position text boxes in the Inspector now show coordinates relative to that anchor point. Set the box position so its edge sits exactly at X=0 (the torus center). This is midpoint mode — you're measuring from the center of the object, not its corner.

- Select the torus and box hole, **Ctrl+G**. You now have a half-torus.

**4. Attach the handle**
- With the half-torus selected, look at the Inspector. The flat face needs to sit flush against the cup's outer wall.
- The cup outer radius is **30mm** (half of 60mm). So the flat face of the handle needs to be at X = 30mm from the cup center.
- Click the half-torus, then click into the **X position text box** in the Inspector and type the value directly. Don't nudge — type it. This is the fastest way to land on an exact position.
- Use **Align** (**L**) to center the handle vertically on the cup (align on the Z axis to match midpoints).

**5. Final group**
- Select everything, **Ctrl+G**.
- Orbit underneath — check the base is solid and the cavity doesn't poke through the bottom.
- **Export → .STL**.

### New Concepts Introduced Here

| Concept | What it does |
|---|---|
| **Ruler (E key)** | Places a measurement anchor on the workplane — position text boxes now show distance from that point |
| **Midpoint mode** | Snap the ruler to the center of a shape, not its corner, so your coordinates describe the object's center |
| **Position text boxes** | Click directly into the X/Y/Z fields in the Inspector and type a number — much faster than nudging for exact placement |
| **Torus** | A ring primitive — useful for handles, gaskets, and any circular loop shape |

> **Why type the position instead of nudging?** Arrow keys move 1mm per tap. Getting from an arbitrary position to exactly 30.00mm by nudging means ~30 keystrokes and a lot of squinting. Clicking the text box and typing `30` takes one second. Use the text boxes any time you have a known target dimension.


## Project 2: Custom Potentiometer Knob

This is the real one. You've been twisting a bare metal shaft for weeks. Now you'll design a knob that fits it perfectly, looks how you want it to look, and has your name or a marker line on top.

### Know Your Hardware First

The potentiometers used in this course (standard 10kΩ panel-mount) have a **D-shaped shaft**:
- **6mm** outer diameter
- One side is flat (the "D"), cutting about **0.5mm** off the radius

This is critical. A round 6mm hole will spin freely. You need to model the D-shape or the knob won't transmit rotation.

Also account for **print tolerance**: add **0.3mm** to any dimension that needs to fit over a shaft. So model the hole as **6.3mm** diameter, not 6mm.

### Knob Anatomy

```
    ┌──────────┐   ← Top (flat, or add a pointer ridge here)
    │          │
    │  (outer  │   ← Grip cylinder (~18mm diameter, ~15mm tall)
    │   body)  │
    └────┬─────┘
         │         ← Shaft socket (below the body, ~8mm deep)
         │         ← D-shaped hole through the whole thing
```

### Step-by-Step

**1. The outer body**
- Drag a **Cylinder** onto the workplane. Press **D**.
- Set: **Diameter 18mm, Height 15mm**.
- This is your grip. You can change the diameter freely — larger is easier to turn, smaller looks sleeker.

**2. The shaft hole (round part)**
- Drag a **Cylinder** onto the workplane. Press **D**.
- Set: **Diameter 6.3mm, Height 25mm** (taller than the knob body so it punches all the way through).
- Toggle to **Hole**.
- Align it to the center of the body (**L** key with both selected, center on both X and Y).

**3. The D-flat cutout**
- Drag a **Box** onto the workplane. Press **D**.
- Set: **W 3mm, L 10mm, H 25mm**.
- Toggle to **Hole**.
- Move it so one of its long faces is **2.7mm from the center** of the shaft hole. (This trims 0.3mm off the radius, matching the flat on the real shaft.)

> **How to position it precisely**: click the box, look at the X/Y position in the inspector. If your shaft hole is centered at X=0, move the flat-cut box to X = -(3.15 + 1.5) = -4.65mm. The math: shaft radius 3.15mm, plus half the box width 1.5mm, minus 0.5mm flat depth. Roughly: nudge it until it just barely bites into the side of the hole cylinder.

**4. Group**
- Select all, **Ctrl+G**. The D-hole is now cut through the body.

**5. Make it yours**
Here's where students diverge. Some ideas:

| Customization | How in TinkerCAD |
|---|---|
| Pointer line on top | Add a thin flat Box (1mm tall) across the top surface, keep it solid, group |
| Knurled grip | Add small cylinders around the outside edge as solid shapes, group |
| Your initials on top | Use the **Text** shape (in the shape library), extrude 1–2mm above the surface |
| Tapered body | Use a **Cone** or **Paraboloid** instead of a cylinder for the body |
| Color | Doesn't affect printing, but helps visualization in TinkerCAD |

**6. Check before exporting**
- Orbit all the way under the knob. Is the D-hole visible from the bottom? Good.
- Select the whole group and check the height in the inspector — should be 15mm.
- **Export → .STL**.

### Test Fit (After Printing)
- If it's too tight: re-open TinkerCAD, increase the hole cylinder diameter by 0.2mm, re-export, reprint.
- If it spins freely: the D-flat cutout didn't go deep enough — move it 0.2mm further in and reprint.
- This iteration is normal. It's not failure, it's calibration.

---

## Printing Tips

| Tip | Detail |
|---|---|
| **Layer height** | 0.2mm is fine for everything here. 0.1mm is smoother but 2× slower. |
| **Infill** | 15–20% for the clip. 40%+ for the knob (it takes torque). |
| **No supports needed** | Both projects are designed to avoid overhangs. |
| **Orientation matters** | Print the knob with the top face *down* on the bed — the D-hole will be cleaner. |
| **First layer adhesion** | If it's not sticking: clean the bed with IPA, slow down the first layer, or add a brim. |

---

## Key Concepts Summary

| Concept | What It Does |
|---|---|
| **Hole toggle** | Turns any shape into a boolean cutter |
| **Ctrl+G (Group)** | Executes all cuts and merges, bakes the geometry |
| **D key** | Drops shape to workplane — use obsessively |
| **Align tool (L)** | Centers shapes relative to each other |
| **Tolerance** | Add 0.2–0.4mm to any dimension that fits over hardware |
| **.STL export** | The universal format slicer software (Cura, PrusaSlicer) reads |

## More Project Ideas

| Project | What You'd Learn |
|---|---|
| Arduino Uno enclosure | Shell modeling, snap fits, port cutouts |
| Servo horn extension arm | Screw hole tolerances, lever geometry |
| Breadboard feet | Thin flat parts, press-fit pegs |
| LED diffuser cap | Thin walls, translucent filament |