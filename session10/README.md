# Session 10: Advanced Projection Mapping & Final Projects

Today is split in two. First, we dig deeper into projection mapping by chaining together the tools we've been learning — TouchDesigner, Processing (mappy), and Arduino — into more powerful combinations. Then we spend the second half of class talking seriously about final projects.

## Agenda

+ Demo 1: Syphon/Spout — piping video from TouchDesigner into mappy
+ Demo 2: The Playground — writing Processing code inside mappy
+ Demo 3: Arduino → Playground — potentiometer-controlled projection mapping
+ Final project discussion

---

## Demo 1: Syphon / Spout — TouchDesigner → Mappy

Up to now we've used TouchDesigner *or* mappy. But what if you want TouchDesigner's powerful generative tools **and** mappy's quad-warping workflow? The answer is **Syphon** (macOS) or **Spout** (Windows) — protocols that let applications share video frames in real time with zero latency.

The idea: TouchDesigner renders something → sends it out via Syphon/Spout → mappy picks it up as a live texture you can map onto any surface.

### TouchDesigner Side (3 nodes, 2 minutes)

1. Open TouchDesigner. You start with an empty network.
2. **Tab** → search **Noise** → drop a `Noise` TOP onto the network.
   - In its parameters, set **Type** to `Random (GPU)`.
   - Set **Resolution** to `1280 x 720`.
   - Turn on **Time** under the Transform tab so it animates.
3. **Tab** → search **Syphon Spout Out** → drop a `Syphon Spout Out` TOP.
   - Wire the output of your Noise TOP into the Syphon Spout Out's input (drag from the little connector on the right side of Noise to the left side of Syphon Spout Out).
   - That's it. TouchDesigner is now broadcasting this texture.

> **Tip:** You can replace the Noise TOP with anything — a `Movie File In`, a feedback loop, a `GLSL` shader, a webcam (`Video Device In`). The Syphon Spout Out node doesn't care what it receives.

### Mappy Side

1. Launch mappy.
2. Create a surface (or use an existing one).
3. With the surface selected, press **V** (or click **Video/Image** in the sidebar) and choose the Syphon/Spout source from the list. It should appear automatically as long as TouchDesigner is running.
4. Warp the corners onto your physical object. Done — you're now projection mapping a live TouchDesigner feed.

### Make It Weirder

Back in TouchDesigner, try chaining more nodes before the Syphon Spout Out:

- **Feedback** TOP → plug the Syphon output back into itself with a `Feedback` and `Composite` TOP for trails.
- **HSV Adjust** TOP → shift the hue over time for psychedelic color cycling.
- **Edge** TOP → turn your noise into a line drawing.

Every change you make in TouchDesigner updates instantly in mappy.

---

## Demo 2: The Playground

Mappy has a built-in **Playground** — a Processing sketch that runs inside the app and renders to a canvas that gets projection-mapped onto your surfaces. This means you can write code (just like a normal Processing sketch) and have it projected and warped in real time.

### Activating the Playground

1. In mappy, select a surface.
2. Press **P** (or click the **Playground** button in the sidebar).
3. The surface now displays whatever the Playground draws.

### How It Works

The Playground is a class with two functions you edit:

- `playgroundSetup()` — runs once (just like `setup()`).
- `playgroundDraw()` — runs every frame (just like `draw()`).

You draw to a `PGraphics` object called `canvas` (640×480 by default). Everything you draw to `canvas` gets texture-mapped onto any surface assigned to the Playground.

### Default Sketch: Random Squares

Out of the box, the Playground draws random colorful squares that accumulate on screen:

```java
void playgroundDraw() {
  canvas.beginDraw();

  canvas.noStroke();
  canvas.fill(random(255), random(255), random(255), 200);
  float sz = random(10, 60);
  canvas.rect(random(canvas.width), random(canvas.height), sz, sz);

  canvas.endDraw();
}
```

### Try Something Cooler: Pulsing Rings

Replace the default `playgroundDraw()` with this:

```java
// YOUR VARIABLES
float hue = 0;

void playgroundDraw() {
  canvas.beginDraw();
  canvas.colorMode(HSB, 360, 100, 100, 100);
  canvas.background(0, 0, 0, 10);  // Slow fade for trails

  int numRings = 5;
  for (int i = 0; i < numRings; i++) {
    float offset = i * (360.0 / numRings);
    float pulse = sin(radians(frameCount * 2 + offset)) * 0.5 + 0.5;
    float diameter = pulse * canvas.height * 0.8;

    canvas.noFill();
    canvas.stroke((hue + offset) % 360, 80, 100, 60);
    canvas.strokeWeight(3);
    canvas.ellipse(canvas.width / 2, canvas.height / 2, diameter, diameter);
  }

  hue = (hue + 0.5) % 360;
  canvas.endDraw();
}
```

This gives you concentric rings that pulse and cycle through colors — looks great on physical objects.

### Editing the Playground Code

The Playground source lives in the `source/` folder alongside the other `.pde` files. Open it in any text editor, make changes, and restart mappy to see the result. (No need to recompile — mappy reads the source at launch.)

---

## Demo 3: Arduino Potentiometer → Playground

Now we connect physical input to the Playground. A potentiometer will control a visual parameter in real time — turn the knob and the projection changes.

### Arduino Side

Upload this sketch (same one from Session 09 — it's in `session09/arduino_pot_serial/`):

```cpp
const int potPin = A0;

void setup() {
  Serial.begin(9600);
}

void loop() {
  int val = analogRead(potPin);
  Serial.println(val);
  delay(20);
}
```

Wire a potentiometer to **A0**, **5V**, and **GND** — same circuit as Session 04.

### Playground Side

In the Playground class, flip the serial toggle and write a sketch that uses the incoming value:

1. Set `useSerial = true;` near the top of the Playground class.
2. The serial code auto-connects and parses incoming values into the `serialValues[]` array.
3. Use `serialValues[0]` in your `playgroundDraw()` — it will hold the raw 0–1023 value from the potentiometer.

### Example: Potentiometer-Controlled Rings

```java
// YOUR VARIABLES
float hue = 0;

void playgroundDraw() {
  canvas.beginDraw();
  canvas.colorMode(HSB, 360, 100, 100, 100);
  canvas.background(0, 0, 0, 10);

  // Map pot value (0-1023) to number of rings (1-20)
  int numRings = (int) map(serialValues[0], 0, 1023, 1, 20);
  // Map pot value to ring speed
  float speed = map(serialValues[0], 0, 1023, 0.5, 8);

  for (int i = 0; i < numRings; i++) {
    float offset = i * (360.0 / numRings);
    float pulse = sin(radians(frameCount * speed + offset)) * 0.5 + 0.5;
    float diameter = pulse * canvas.height * 0.8;

    canvas.noFill();
    canvas.stroke((hue + offset) % 360, 80, 100, 60);
    canvas.strokeWeight(3);
    canvas.ellipse(canvas.width / 2, canvas.height / 2, diameter, diameter);
  }

  hue = (hue + 0.5) % 360;
  canvas.endDraw();
}
```

Turn the knob all the way left: one slow ring. Turn it all the way right: twenty fast rings. The projection on the physical surface updates immediately.

### Sending Multiple Values

If you want to control more parameters (say, two pots), update the Arduino sketch to send comma-separated values:

```cpp
int potA = A0;
int potB = A1;

void setup() {
  Serial.begin(9600);
}

void loop() {
  Serial.print(analogRead(potA));
  Serial.print(",");
  Serial.println(analogRead(potB));
  delay(20);
}
```

In the Playground, `serialValues[0]` is the first pot and `serialValues[1]` is the second. The array supports up to 8 comma-separated values.

---

## The Full Pipeline

Here's what we can do now after Sessions 09 and 10:

```
TouchDesigner ──Syphon/Spout──→ ┐
                                 ├─→ Mappy (warp + map onto surfaces) ──→ Projector ──→ Physical Object
Arduino ──Serial──→ Playground ──┘
```

You can use any combination:
- **TouchDesigner alone** for generative visuals mapped via Syphon/Spout.
- **Playground alone** for custom Processing code projected directly.
- **Arduino + Playground** for physical-input-driven visuals.
- **All three** — TouchDesigner on some surfaces, Arduino-controlled Playground on others.

---

## Final Projects

The remaining sessions (11 and 12) are dedicated workshop time for your final projects. The final exhibition is **May 5**.

### Timeline

| Date | Milestone |
|---|---|
| **Today (April 14)** | Commit to a concept. Identify what you need to learn. |
| **April 21 (Session 11)** | Working prototype. Bring something that runs. |
| **April 28 (Session 12)** | Polish, test, document. |
| **May 5** | Final exhibition. |

### What Makes a Good Final Project?

- **Uses skills from this course.** Arduino, Processing, serial communication, projection mapping, 3D printing — pick at least two.
- **Has a clear concept.** Not just "it does cool stuff" — what does it say? What does the audience experience?
- **Is scoped realistically.** You have three weeks. Better to finish a focused piece than half-build an ambitious one.

### Discussion Prompts

Go around the room. For each person:

1. **What's your concept?** One sentence.
2. **What tools/techniques will you use?** Be specific.
3. **What's the hardest part?** What do you still need to figure out?
4. **What do you need from me?** Parts, code help, fabrication time, etc.

### Project Ideas (If You're Stuck)

- **Reactive sculpture:** 3D-print a geometric form, project patterns onto it, use a distance sensor to change the visuals as people approach.
- **Sound machine:** Potentiometers and buttons controlling generative audio + visuals through Processing, projected onto a surface.
- **Data portrait:** Pull live data (weather, social media, sensor readings) and visualize it as a projection-mapped installation.
- **Interactive mural:** Project onto a wall. Use ultrasonic sensors to detect where people are standing and change what's projected in that zone.
- **Kinetic + projected:** Combine a servo-driven moving element with projection mapping that tracks or complements the motion.
