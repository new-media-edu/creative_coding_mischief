# Session 08: Designing for 3D Printing with TinkerCAD

Last session we talked about 3D printing as something that *exists*. Today we actually use it. By the end of class you'll have two files ready to print: a small desk utility and a custom knob that fits the exact potentiometer you've been using since Session 04.

## Show and Tell

*[Instructor brings in:]*
- A stepper motor filament spool - a real printed part doing real mechanical work
- A project box with a printed potentiometer knob - same thing you'll design today

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

## TinkerCAD Interface

TinkerCAD runs in the browser at [tinkercad.com](https://www.tinkercad.com). Create a free account, click **Create** → **3D Design**.

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

> **The D key is the most-forgotten thing in TinkerCAD.** When you drag a shape onto the workplane it often floats in mid-air. Press **D** and it snaps down to the surface. Do this every time you place a shape.

---

## Project 1: Cable Clip (~20 minutes)

A simple clip that wraps around the edge of a desk and holds a USB cable. You'll learn: placing shapes, resizing, making a hole, grouping.

### What You're Building

A rectangular body with a channel through the middle (for the cable) and a notch on the back (to hook the desk edge). Two shapes, one boolean subtract, one group.

### Step-by-Step

**1. Place the body**
- Drag a **Box** onto the workplane. Press **D**.
- Click it to select, then click the white square handles to resize.
- Set: **W 20mm, L 30mm, H 15mm** (type values in the inspector top-right, or click the dimension bubbles directly).

**2. Make the cable channel**
- Drag a **Cylinder** onto the workplane. Press **D**.
- Resize it: **Diameter 8mm, Height 25mm** (make it taller than the box — it needs to poke through both sides).
- In the **Inspector** (top right), toggle this shape to **Hole** (the shape turns translucent red/grey).
- Move it so it's centered left-right on the box, roughly centered front-to-back.
- Use the **Align** tool (select both, press **L**) to center them on both axes.

**3. Make the desk-edge notch**
- Drag another **Box** onto the workplane. Press **D**.
- Size: **W 24mm, L 8mm, H 6mm** (slightly wider than the body so it cuts all the way through the sides).
- Toggle to **Hole**.
- Move it to the back edge of the body, flush with the bottom.

**4. Group everything**
- Select all (Ctrl+A).
- Press **Ctrl+G** to group. TinkerCAD punches the holes through the solid.

**5. Export**
- Click **Export** → **.STL**. That file goes to the printer.

*Change the cable channel diameter to fit whatever cable you use. 6mm for a thin cable, 10mm for a chunky one.*

---

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