# Session 10: Projection Mapping II + Final Projects

Two things today. We're going to take the projection mapping setup from last session and actually start combining tools: TouchDesigner feeding into mappy, writing code inside mappy, and hooking up an Arduino to control it all. Then we'll switch gears and talk about final projects for the rest of class.

## Agenda

+ Syphon/Spout: piping video from TouchDesigner into mappy
+ The Playground: writing Processing code inside mappy
+ Arduino → Playground: potentiometer-controlled visuals
+ Final project discussion

---

## Syphon / Spout: TouchDesigner → Mappy

Last session we used TouchDesigner and mappy separately. What if you want to generate something wild in TouchDesigner but use mappy to do the quad-warping and surface alignment? That's what Syphon (macOS) and Spout (Windows) are for. They're protocols that let one application send its video output to another application, frame by frame, with basically no delay.

So the flow is: TouchDesigner makes something visually interesting → Syphon/Spout carries it over → mappy receives it like any other video source and maps it onto your surfaces.

### TouchDesigner setup (3 nodes)

1. Open TouchDesigner.
2. Press Tab, search for `Noise`, and drop a Noise TOP onto the network.
   - In the parameters panel, set Type to `Random (GPU)`.
   - Set Resolution to `1280 x 720`.
   - Under the Transform tab, turn on Time so it actually moves.
3. Press Tab again, search for `Syphon Spout Out`, and drop one of those on.
   - Drag a wire from the right side of the Noise TOP to the left side of the Syphon Spout Out TOP.
   - Done. TouchDesigner is now broadcasting.

You can swap the Noise TOP for anything: a `Movie File In`, a `GLSL` shader, a webcam via `Video Device In`, whatever. The Syphon Spout Out node just sends whatever image it gets.

### Mappy setup

1. Launch mappy.
2. Create a surface (or select an existing one).
3. Press **V** (or click Video/Image in the sidebar) and pick the Syphon/Spout source from the dropdown. It shows up automatically if TouchDesigner is running.
4. Warp the corners onto your object.

That's it. You're projection mapping a live TouchDesigner feed.

### Make it weirder

Back in TouchDesigner, chain more nodes before the Syphon Spout Out:

- Add a `Feedback` TOP and a `Composite` TOP to create trails
- Add an `HSV Adjust` TOP to shift the hue over time
- Add an `Edge` TOP to turn your noise into line art

Changes in TouchDesigner show up in mappy right away.

---

## The Playground

Mappy has a built-in Playground. It's basically a Processing sketch that lives inside the app and renders to a canvas that gets mapped onto your surfaces. You write `playgroundSetup()` and `playgroundDraw()` just like you'd write `setup()` and `draw()` in a normal Processing sketch, except you draw to a `PGraphics` object called `canvas` (640×480).

### Turn it on

1. Select a surface in mappy.
2. Press **P** (or click the Playground button in the sidebar).
3. That surface now shows whatever the Playground is drawing.

### The default sketch

Out of the box it draws random colorful squares that pile up on screen:

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

### Something better: pulsing rings

Replace the default `playgroundDraw()` with this to get concentric rings that pulse and shift color:

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

Looks especially good when projected onto an actual 3D object.

### Where to edit it

The Playground source is in the `source/` folder alongside the other `.pde` files. Edit it in any text editor and restart mappy. No recompilation needed.

---

## Arduino Potentiometer → Playground

Now the fun part: plug in a potentiometer and use it to control what the Playground draws. Turn the knob, the projection changes.

### Arduino sketch

Same one from Session 09. It's in `session09/arduino_pot_serial/`:

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

Wire a potentiometer to A0, 5V, and GND (same circuit as Session 04).

### Playground side

In the Playground class, set `useSerial = true;` near the top. That's really the only switch you need to flip. The serial code auto-connects and fills in the `serialValues[]` array with incoming numbers. `serialValues[0]` will hold the raw 0-1023 value from the pot.

### Example: pot-controlled rings

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

Knob all the way left: one slow ring. All the way right: twenty fast ones.

### Two pots

If you want to control more stuff, update the Arduino sketch to send comma-separated values:

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

Then in the Playground, `serialValues[0]` is the first pot, `serialValues[1]` is the second. The array goes up to 8 values.

---

## Putting it together

After today you've got a few different ways to feed visuals into mappy:

```
TouchDesigner ──Syphon/Spout──→ mappy ──→ Projector ──→ Physical Object
Arduino ──Serial──→ Playground ──→ mappy ──→ Projector ──→ Physical Object
```

You can mix and match. TouchDesigner on some surfaces, Playground on others, Arduino controlling whichever one you want. Or just one of the above. Up to you.

---

## Final Projects

Sessions 11 and 12 are workshop time. The final exhibition is May 5.

| Date | What's happening |
|---|---|
| Today (April 14) | Commit to a concept. Figure out what you still need to learn. |
| April 21 (Session 11) | Bring a working prototype. Something that runs, even if it's ugly. |
| April 28 (Session 12) | Polish, test, document. |
| May 5 | Exhibition. |

### The talk

We're going to go around the room. For each person:

1. What's your concept? One sentence.
2. What tools/techniques are you going to use?
3. What's the hardest part? What do you still need to figure out?
4. What do you need from me? Parts, code help, fabrication time, whatever.

### Scoping

You have three weeks. Scope accordingly. A finished small project is better than an unfinished ambitious one. Your project should use at least a couple things from this course (Arduino, Processing, serial, projection mapping, 3D printing, etc.) and it should have some kind of concept behind it beyond "it looks cool."

### If you're stuck

Some starting points people have run with in the past:

- 3D-print a geometric form, project onto it, use a distance sensor to change the visuals when people get close
- Pots and buttons controlling generative audio + visuals through Processing, projected onto a surface
- Pull live data (weather, whatever) and turn it into a projection-mapped visualization
- Project onto a wall and use ultrasonic sensors to react to where people are standing
- Servo-driven moving piece with projection mapping that follows the motion
