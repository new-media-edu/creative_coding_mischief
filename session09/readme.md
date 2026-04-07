# Session 09: Projection Mapping

Today we explore projection mapping — the technique of projecting visuals directly onto physical objects so the light conforms to their shape. We'll look at two tools: a custom app built in Processing, and the industry-standard software TouchDesigner. At the end, I'll briefly show how to feed live Arduino data into this pipeline via a potentiometer.

## Agenda

+ What is projection mapping?
+ Tool 1: Custom Processing app
+ Tool 2: TouchDesigner
+ Hands-on: map something in the room
+ Bonus: Arduino potentiometer → live parameter

---

## What Is Projection Mapping?

Projection mapping (also called *video mapping* or *spatial augmented reality*) uses a projector and software to align visuals precisely onto a 3D surface. Instead of projecting onto a flat white screen, you project onto an irregular object — a box, a sculpture, a building — and the image wraps around it convincingly.

The basic workflow is always the same:

```
Create visuals → Define surfaces in software → Warp/pin to match the object → Project
```

---

## Tool 1: Custom Processing App

I built a projection mapping tool in Processing that lives in the `projection_app/` folder of this repo. It lets you define quadrilateral surfaces, assign visuals to each one, and warp them interactively.

A pre-built binary is included — you don't need to compile anything.

### Running It

```
projection_app/linux-amd64/projection_app   # Linux
projection_app/windows-amd64/              # Windows (run the .exe)
```

### Controls

Refer to [projection_app/LIVE_AV_GUIDE.md](../projection_app/LIVE_AV_GUIDE.md) for the full control reference.

---

## Tool 2: TouchDesigner

[TouchDesigner](https://derivative.ca/) is a node-based visual programming environment widely used for projection mapping, interactive installations, and live performance. The free version has no time limit and is fully functional for today's work.

Download: [derivative.ca/download](https://derivative.ca/download)

The `touch_designer/` folder in this repo contains starter resources.

### Core Concepts

| Concept | What it is |
|---|---|
| **Operator (OP)** | A node that does one thing (generates, processes, or outputs data) |
| **TOP** | Texture Operator — handles 2D images and video |
| **CHOP** | Channel Operator — handles numeric data streams (great for Arduino) |
| **Network** | Your canvas of connected nodes |

### Basic Projection Mapping in TouchDesigner

1. Create a `Movie File In` TOP and load your video/image.
2. Add a `Stoner` TOP (TouchDesigner's built-in projection mapping node).
3. In the Stoner, define your surface corners and drag them to match the object.
4. Send the output to a second monitor set to the projector.

---

## Hands-On: Map Something in the Room

Pick an object — a box, a chair, a corner of the wall — and projection map onto it using either tool. Goals:

- Get at least one surface aligned convincingly.
- Experiment with moving the projector vs. adjusting the warp points.

---

## Bonus: Arduino Potentiometer → Live Parameter

A potentiometer sends a continuous 0–1023 value over serial. You can route that into either tool to control a live parameter (brightness, scale, speed, etc.).

The sketch is in `arduino_pot_serial/arduino_pot_serial.ino`.

### What it does

Reads `A0` and prints the value over serial at 9600 baud, once per loop.

### Hooking it up in TouchDesigner

1. Add a `Serial` CHOP.
2. Set the port to match your Arduino's COM/tty port and baud to `9600`.
3. Wire the CHOP output into any numeric input on your network.

### Hooking it up in the Processing app

The Processing app reads serial data on a configurable port. See `projection_app/IO.pde` for the serial setup.
